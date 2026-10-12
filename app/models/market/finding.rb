module Market
  # One thing the data says about a client's market, worked out by Finding::Analysis from the
  # website readings, the search data and the tracked rankings. Its key is stable
  # ("keyword_gap:rival.example"), so a finding lives on while it holds: `changed_at` moves
  # when it appears, comes back or changes, and it's resolved when it no longer holds. A person
  # (or their agent) may dismiss one; it stays dismissed while it holds. Refreshed after every
  # reading and pull, and nightly.
  class Finding < ApplicationRecord
    SEVERITIES = %w[high medium low info].freeze
    STATES = %w[open resolved dismissed].freeze

    belongs_to :client, class_name: "::Client"

    serialize :evidence, coder: JSON, type: Hash
    serialize :sources, coder: JSON, type: Array

    validates :severity, inclusion: { in: SEVERITIES }

    scope :open, -> { where(resolved_at: nil, dismissed_at: nil) }
    scope :by_severity, -> { in_order_of(:severity, SEVERITIES).order(changed_at: :desc) }
    scope :in_state, ->(state) {
      case state
      when "open" then open
      when "resolved" then where.not(resolved_at: nil)
      when "dismissed" then where(resolved_at: nil).where.not(dismissed_at: nil)
      else all
      end
    }

    def state = resolved_at ? "resolved" : (dismissed_at ? "dismissed" : "open")
    def label = title
    def channel_label = Opportunity::CHANNELS[channel]

    def dismiss(by:) = update(dismissed_at: Time.current, dismissed_by_name: by.display_name, changed_at: Time.current)
    def reopen = update(dismissed_at: nil, dismissed_by_name: nil, changed_at: Time.current)

    # Works a client's findings out again: new ones added, held ones updated (changed_at moves
    # only when what they say changes), gone ones resolved. Answers the open ones.
    def self.refresh(client, now: Time.current)
      found = Analysis.new(client).findings
      existing = where(client: client).index_by(&:key)
      transaction do
        found.each do |attributes|
          attributes = attributes.deep_stringify_keys
          row = existing.delete(attributes["key"]) || new(client: client, key: attributes["key"], first_seen_at: now)
          moved = row.new_record? || row.resolved_at || row.title != attributes["title"] || row.severity != attributes["severity"] || row.evidence != attributes["evidence"]
          row.assign_attributes(attributes.except("key").merge("last_seen_at" => now, "resolved_at" => nil))
          row.changed_at = now if moved
          row.save!
        end
        existing.each_value { |row| row.update!(resolved_at: now, changed_at: now) unless row.resolved_at }
      end
      where(client: client).open
    end

    def self.refresh_later(client) = FindingsJob.perform_later(client)
  end
end
