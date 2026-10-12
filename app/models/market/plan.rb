module Market
  # The big picture for one client, drafted by the install's AI (the AI plugin's Ai.structured)
  # from everything known: their profile, their site's latest reading, each competitor's with
  # how it competes, and what's already planned. It answers with the state of their market, the
  # angle to win it, an industry and competitors to check, and Opportunities, which a person
  # plans as work, does or dismisses. Run in PlanJob; nothing changes until a person acts.
  class Plan < ApplicationRecord
    STATES = %w[queued running ready failed].freeze
    STUCK_AFTER = 10.minutes
    MAX_OPPORTUNITIES = 16

    belongs_to :client, class_name: "::Client"
    belongs_to :user, class_name: "::User"
    has_many :opportunities, dependent: :nullify

    serialize :industry_suggestion, coder: JSON, type: Hash
    serialize :competitor_suggestions, coder: JSON, type: Array
    serialize :keyword_suggestions, coder: JSON, type: Array

    validates :state, inclusion: { in: STATES }

    scope :latest_first, -> { order(id: :desc) }

    # Whether the install's AI can draft one for this client (the AI plugin: on, set up, within
    # budget, and the client not kept out of AI).
    def self.ai_available_for?(client)
      defined?(::Ai) && ::Ai.respond_to?(:structured) && ::Ai.available_for?(client)
    end

    def working? = state.in?(%w[queued running]) && updated_at > STUCK_AFTER.ago
    def ready? = state == "ready"
    def failed? = state == "failed" || (state.in?(%w[queued running]) && !working?)

    def run_later = PlanJob.perform_later(self)

    # The competitors it suggested that aren't the client's yet.
    def new_competitor_suggestions
      known = Rivalry.where(client_id: client_id).includes(:competitor).map(&:competitor)
      Array(competitor_suggestions).reject do |suggestion|
        known.any? { it.domain.present? && it.domain == Probe.normalize(suggestion["website"]) || it.name.casecmp?(suggestion["name"].to_s) }
      end
    end

    def new_keyword_suggestions
      tracked = Keyword.where(client_id: client_id).pluck(:keyword)
      Array(keyword_suggestions) - tracked
    end

    def industry_suggestion_new?
      name = industry_suggestion&.dig("name").to_s
      name.present? && !Profile.find_by(client_id: client_id)&.industry&.name.to_s.casecmp?(name)
    end

    # Called by PlanJob. Never raises: what went wrong is kept in `error`.
    def run!
      update!(state: "running", started_at: Time.current)
      answer = ::Ai.structured(user: user, name: "market_plan", schema: schema, instructions: instructions, prompt: Brief.new(client).to_s)
      transaction do
        update!(summary: answer["summary"].to_s.strip, positioning: answer["positioning"].to_s.strip.presence,
          industry_suggestion: industry_from(answer["industry"]), competitor_suggestions: competitors_from(answer["competitors_to_check"]),
          keyword_suggestions: keywords_from(answer["keywords_to_track"]))
        add_opportunities(Array(answer["opportunities"]))
      end
      update!(state: "ready", finished_at: Time.current)
    rescue => error
      Rails.logger.error("[market] plan #{id}: #{error.class}: #{error.message}")
      update_columns(state: "failed", error: "#{error.class.name.demodulize}: #{error.message}".truncate(500), finished_at: Time.current, updated_at: Time.current)
    end

    private
      def industry_from(answer)
        return {} unless answer.is_a?(Hash) && answer["name"].present?

        answer.slice("name", "naics_code", "why").transform_values { it.to_s.strip }.compact_blank
      end

      def competitors_from(answers)
        Array(answers).filter_map do |answer|
          next unless answer.is_a?(Hash) && answer["name"].present?

          website = answer["website"].to_s.strip
          website = "https://#{website}" if website.present? && !website.match?(%r{\Ahttps?://})
          { "name" => answer["name"].to_s.strip, "website" => website.presence, "why" => answer["why"].to_s.strip.presence }.compact
        end.first(8)
      end

      def keywords_from(answers)
        tracked = Keyword.where(client_id: client_id).pluck(:keyword)
        Array(answers).map { it.to_s.strip.squeeze(" ").downcase }.compact_blank.uniq.reject { tracked.include?(it) }.first(15)
      end

      def add_opportunities(answers)
        existing = Opportunity.where(client_id: client_id).pluck(:title).map(&:downcase)
        answers.first(MAX_OPPORTUNITIES).each do |answer|
          title = answer["title"].to_s.strip
          next if title.empty? || existing.include?(title.downcase)

          opportunities.create!(client_id: client_id, title: title, detail: answer["detail"].to_s.strip.presence, evidence: answer["evidence"].to_s.strip.presence,
            channel: answer["channel"].presence_in(Opportunity::CHANNELS.keys) || "seo", impact: answer["impact"].presence_in(Opportunity::IMPACTS) || "medium",
            effort: answer["effort"].presence_in(Opportunity::EFFORTS) || "medium", horizon: answer["horizon"].presence_in(Opportunity::HORIZONS.keys) || "next")
          existing << title.downcase
        end
      end

      def schema
        { type: "object", additionalProperties: false, required: %w[summary positioning industry competitors_to_check keywords_to_track opportunities], properties: {
          summary: { type: "string", description: "The big picture of this client's market in 3 to 6 sentences: where they stand, who's winning and why, and what matters most now." },
          positioning: { type: "string", description: "The angle to win on, in one or two sentences: what they can own that competitors don't." },
          industry: { type: "object", additionalProperties: false, required: %w[name naics_code why], properties: {
            name: { type: "string", description: "A plain industry name, as specific as useful (\"Residential plumbing\", not \"Services\")." },
            naics_code: { type: "string", description: "The 2–6 digit NAICS code, or \"\" when unsure." },
            why: { type: "string" }
          } },
          competitors_to_check: { type: "array", description: "Businesses likely competing for the same customers that aren't listed yet. Only real ones you're confident exist; a person checks each.", items: {
            type: "object", additionalProperties: false, required: %w[name website why], properties: {
              name: { type: "string" }, website: { type: "string", description: "Their site's domain, or \"\" when unsure." }, why: { type: "string" }
            } } },
          keywords_to_track: { type: "array", description: "Up to 15 searches this client's customers make that are worth winning and watching, as they'd type them, with the place where it matters (\"emergency dentist grand rapids\"). Not ones already tracked.", items: { type: "string" } },
          opportunities: { type: "array", items: { type: "object", additionalProperties: false,
            required: %w[channel title detail evidence impact effort horizon], properties: {
              channel: { type: "string", enum: Opportunity::CHANNELS.keys },
              title: { type: "string", description: "What to do, as a short instruction (\"Publish a page for each town served\")." },
              detail: { type: "string", description: "How, in two or three sentences someone could start from." },
              evidence: { type: "string", description: "What in the facts shows it's worth doing (\"Two direct competitors have 15+ location pages; the client has none\")." },
              impact: { type: "string", enum: Opportunity::IMPACTS },
              effort: { type: "string", enum: Opportunity::EFFORTS },
              horizon: { type: "string", enum: Opportunity::HORIZONS.keys }
            } } }
        } }
      end

      def instructions
        <<~TEXT
          You are a senior marketing strategist at an agency planning a client's SEO and marketing for the year. You are given what the agency knows about the client (their market profile), readings of their website and their competitors' websites taken from outside (pages and posts in their sitemaps, how recently they changed, the tools on their home pages: ad tags, analytics, call tracking, chat, reviews, booking; structured data, social profiles), how each competitor competes with them, search data from DataForSEO when it's been pulled (visibility, estimated traffic, keywords, where everyone ranks for the searches tracked), findings already worked out from all of it, and the work already planned, done or dismissed.

          Give the big picture, then the opportunities that would win this market, best first.
          - Ground every opportunity in the facts and say which ones in evidence. Compare: where competitors are ahead (more location or service pages, regular posts, ads running, reviews shown, booking online), copy what works and beat it; where they're weak, take the ground.
          - Cover the channels that matter for this business, not all of them: search, local and maps, content, paid, social, email, reviews, the website's conversion, brand, partnerships.
          - Mix quick wins (now) with the bigger moves (next, later). At most #{MAX_OPPORTUNITIES}; don't repeat anything already planned, done or dismissed.
          - Act on the findings first: they are exact. Use the search figures as given (traffic is DataForSEO's estimate; say so); never invent rankings, traffic, review counts or ad spend that aren't there. Where something needs checking, say so in detail.
          - Write plainly, for a business owner: specific, no jargon you don't need.
          Today is #{Date.current.to_fs(:long)}.
        TEXT
      end
  end
end
