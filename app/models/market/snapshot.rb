module Market
  # One reading of a website (a competitor's or a client's own) by Probe, and what changed since
  # the reading before: a new ad tag, a page count that jumped, posts published, a new heading.
  # Kept, so a competitor's page shows how it has moved over time.
  class Snapshot < ApplicationRecord
    belongs_to :subject, polymorphic: true

    serialize :facts, coder: JSON, type: Hash
    serialize :differences, coder: JSON, type: Array

    scope :latest_first, -> { order(taken_at: :desc, id: :desc) }
    scope :with_changes, -> { where.not(differences: [ nil, "[]" ]) }

    # The latest reading of each of these subjects (one kind), by subject id: one query for a list.
    def self.latest_for(subjects)
      subjects = Array(subjects)
      return {} if subjects.empty?

      type = subjects.first.class.polymorphic_name
      ids = where(subject_type: type, subject_id: subjects.map(&:id)).group(:subject_id).maximum(:id).values
      where(id: ids).index_by(&:subject_id)
    end

    # Reads the subject's website now and keeps what it found. Never raises for the website's
    # sake: what couldn't be read is in the facts, and `error` when nothing could.
    def self.take(subject, probe: Probe.new(subject.domain))
      previous = subject.snapshots.latest_first.first
      facts = probe.facts
      parts = facts.except("domain").values
      create!(subject: subject, domain: probe.domain, facts: facts, taken_at: Time.current,
        differences: previous&.read? ? Changes.between(previous.facts, facts) : [],
        error: (parts.map { it["error"] }.compact.join("; ") if parts.all? { it.is_a?(Hash) && it["error"] }))
    end

    def read? = error.blank?
    def home = facts["home_page"].is_a?(Hash) && !facts["home_page"]["error"] ? facts["home_page"] : {}
    def sitemap = facts["sitemap"].is_a?(Hash) && !facts["sitemap"]["error"] ? facts["sitemap"] : {}
    def tools = Array(home["tools"])
    def socials = (home["socials"] || {}).keys
    def runs?(tool) = tools.include?(tool.to_s)

    # A big site's sitemap index is read only so far (Probe::MAX_CHILD_SITEMAPS): its counts are a floor.
    def partial_sitemap? = sitemap["sitemaps"].to_i > sitemap["sitemaps_read"].to_i

    # The figures a comparison table shows, by key.
    def figure(key)
      case key.to_s
      when "pages", "posts", "locations", "services", "posts_last_90_days" then sitemap[key.to_s]
      when "last_changed" then sitemap["last_changed"]
      when "platform" then home["platform"]
      when "words" then home["words"]
      when "socials" then socials.size
      when "schema" then Array(home["schema_types"]).size
      end
    end

    # What changed between two readings, in plain words.
    module Changes
      extend self

      def between(before, after)
        was = Reading.new(before)
        now = Reading.new(after)
        [
          *text_change("Home page title", was.home["title"], now.home["title"]),
          *text_change("Main heading", Array(was.home["headings"]).first, Array(now.home["headings"]).first),
          *text_change("Platform", was.home["platform"], now.home["platform"]),
          *(now.tools - was.tools).map { "Now runs #{tool_label(it)}" },
          *(was.tools - now.tools).map { "No longer runs #{tool_label(it)}" },
          *(now.socials - was.socials).map { "Added a #{Probe::SOCIAL_LABELS.fetch(it, it.humanize)} profile" },
          *(Array(now.home["schema_types"]) - Array(was.home["schema_types"])).first(3).map { "Added #{it} structured data" },
          *count_change("pages", was.sitemap["pages"], now.sitemap["pages"], threshold: 5),
          *count_change("posts", was.sitemap["posts"], now.sitemap["posts"], threshold: 1),
          *count_change("location pages", was.sitemap["locations"], now.sitemap["locations"], threshold: 1),
          *count_change("service pages", was.sitemap["services"], now.sitemap["services"], threshold: 1)
        ]
      end

      private
        Reading = Struct.new(:facts) do
          def home = part("home_page")
          def sitemap = part("sitemap")
          def tools = Array(home["tools"])
          def socials = (home["socials"] || {}).keys
          def part(key) = facts.is_a?(Hash) && facts[key].is_a?(Hash) && !facts[key]["error"] ? facts[key] : {}
        end

        def text_change(label, was, now)
          return [] if was.blank? || now.blank? || was == now

          [ "#{label}: “#{was.to_s.truncate(80)}” → “#{now.to_s.truncate(80)}”" ]
        end

        def count_change(noun, was, now, threshold:)
          return [] unless was.is_a?(Integer) && now.is_a?(Integer)

          delta = now - was
          return [] if delta.abs < threshold || (noun == "pages" && delta.abs < was * 0.1)

          [ "#{delta.positive? ? "+" : "−"}#{delta.abs} #{noun} (now #{now})" ]
        end

        def tool_label(key) = Probe::TOOLS.dig(key, 0) || key.humanize
    end
  end
end
