module Market
  # Something worth doing to win a client's market, on one channel, sized by impact and effort,
  # and when: from a plan the AI drafted, or added by a person. Open until it's planned as work
  # on an engagement (a core todo), done, or dismissed.
  class Opportunity < ApplicationRecord
    CHANNELS = {
      "seo" => "Search (SEO)", "local" => "Local and maps", "content" => "Content", "paid_search" => "Paid search",
      "paid_social" => "Paid social", "social" => "Social", "email" => "Email", "reviews" => "Reviews and reputation",
      "website" => "Website and conversion", "brand" => "Brand and positioning", "partnerships" => "Partnerships and referrals"
    }.freeze
    IMPACTS = %w[high medium low].freeze
    EFFORTS = %w[low medium high].freeze
    HORIZONS = { "now" => "This month", "next" => "This quarter", "later" => "Later" }.freeze
    STATES = %w[open planned done dismissed].freeze
    ACTIVE = %w[open planned].freeze

    belongs_to :client, class_name: "::Client"
    belongs_to :plan, optional: true
    belongs_to :todo, class_name: "::Todo", optional: true

    normalizes :title, with: ->(title) { title.strip.squeeze(" ") }

    validates :title, presence: true
    validates :channel, inclusion: { in: CHANNELS.keys }
    validates :impact, inclusion: { in: IMPACTS }
    validates :effort, inclusion: { in: EFFORTS }
    validates :horizon, inclusion: { in: HORIZONS.keys }
    validates :state, inclusion: { in: STATES }

    scope :active, -> { where(state: ACTIVE) }
    scope :open, -> { where(state: "open") }

    # Best first: most impact for least effort, then soonest.
    def self.by_priority(records) = records.sort_by { [ -it.priority, HORIZONS.keys.index(it.horizon), it.id ] }

    def priority = (3 - IMPACTS.index(impact)) * 2 + (3 - EFFORTS.index(effort))
    def label = title
    def channel_label = CHANNELS.fetch(channel)
    def horizon_label = HORIZONS.fetch(horizon)
    def active? = state.in?(ACTIVE)
    def quick_win? = impact != "low" && effort == "low"

    # Makes it work: a todo on one of the client's open engagements, which links back here.
    def plan_as_work(engagement:, by:, link:, **attributes)
      todo = engagement.todos.new(title: attributes[:title].presence || title, owner_id: attributes[:owner_id], due_on: attributes[:due_on],
        description: [ attributes[:description].presence || detail_html, "<p>From the market plan: #{link}</p>" ].compact.join, created_by: by)
      transaction do
        todo.save!
        update!(todo: todo, state: "planned", decided_by_name: by.display_name, decided_at: Time.current)
      end
      todo.record_event!("todo.created")
      todo
    end

    def complete(by:) = decide("done", by)
    def dismiss(by:) = decide("dismissed", by)
    def reopen = update(state: todo ? "planned" : "open", decided_by_name: nil, decided_at: nil)

    private
      def decide(state, by) = update(state: state, decided_by_name: by.display_name, decided_at: Time.current)

      def detail_html
        [ detail, (evidence && "Why: #{evidence}") ].compact.map { "<p>#{ERB::Util.html_escape(it)}</p>" }.join.presence
      end
  end
end
