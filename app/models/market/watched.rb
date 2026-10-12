module Market
  # A record whose website is read and watched (Competitor, and a client's Profile): its readings
  # (Snapshot), the latest, and whether it's due another. Each needs `domain`.
  module Watched
    extend ActiveSupport::Concern

    CHECK_EVERY = 7.days

    included do
      has_many :snapshots, -> { latest_first }, as: :subject, dependent: :delete_all, inverse_of: :subject
      scope :watchable, -> { where.not(domain: [ nil, "" ]) }
    end

    def latest_snapshot = snapshots.first
    def checked_at = latest_snapshot&.taken_at
    def check_due? = domain.present? && (checked_at.nil? || checked_at < CHECK_EVERY.ago)

    def check_now = Snapshot.take(self)
    def check_later = CheckJob.perform_later(self)
  end
end
