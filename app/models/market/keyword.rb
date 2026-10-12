module Market
  # A search a client wants to win ("emergency dentist grand rapids"), checked from where their
  # customers search on every pull: where they rank, and where each competitor does.
  class Keyword < ApplicationRecord
    SOURCES = %w[manual gap plan ranked].freeze
    MAX_PER_CLIENT = 100

    belongs_to :client, class_name: "::Client"
    has_many :rankings, -> { order(checked_at: :desc, id: :desc) }, dependent: :delete_all

    normalizes :keyword, with: ->(keyword) { keyword.strip.squeeze(" ").downcase }

    validates :keyword, presence: true, length: { maximum: 200 }, uniqueness: { scope: :client_id, message: "is already tracked" }
    validates :source, inclusion: { in: SOURCES }
    validate :within_limit, on: :create, unless: :room_checked

    attr_accessor :room_checked

    scope :ordered, -> { order(:keyword) }

    # Several at once, one a line or comma-separated: answers [added, skipped].
    def self.track(client, text, source: "manual")
      words = text.to_s.split(/[\n,]+/).map { it.strip.squeeze(" ").downcase }.compact_blank.uniq
      tracked = where(client: client).pluck(:keyword)
      fresh = (words - tracked).first([ MAX_PER_CLIENT - tracked.size, 0 ].max)
      added = fresh.filter_map { |word| client.market_keywords.create(keyword: word, source: source, room_checked: true).then { it if it.persisted? } }
      [ added, words.size - added.size ]
    end

    private
      def within_limit
        errors.add(:base, "#{MAX_PER_CLIENT} keywords is the most a client can track") if Keyword.where(client_id: client_id).count >= MAX_PER_CLIENT
      end
  end
end
