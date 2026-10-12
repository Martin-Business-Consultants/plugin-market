module Market
  # A business competing for the same customers, with its website read and watched (Watched).
  # One record however many clients it competes with (Rivalry), so a competitor shared across
  # an industry is watched once.
  class Competitor < ApplicationRecord
    include Watched

    belongs_to :industry, optional: true
    has_many :rivalries, dependent: :delete_all
    has_many :clients, -> { order(:name) }, through: :rivalries, class_name: "::Client"

    normalizes :name, with: ->(name) { name.strip.squeeze(" ") }
    normalizes :website, with: ->(url) { url.strip.chomp("/").presence }

    validates :name, presence: true
    validates :website, format: { with: %r{\Ahttps?://\S+\z}, message: "must start with http:// or https://" }, allow_nil: true
    validate :one_per_domain

    before_save { self.domain = Probe.normalize(website) }

    scope :ordered, -> { order(:name) }

    # The competitor with this website's domain, or by this name when there's no website.
    def self.matching(name:, website: nil)
      domain = Probe.normalize(website)
      (domain && find_by(domain: domain)) || where("LOWER(name) = ?", name.to_s.strip.downcase).first
    end

    def host = domain || website

    private
      def one_per_domain
        domain = Probe.normalize(website)
        return if domain.blank?

        other = self.class.where(domain: domain).where.not(id: id).first
        errors.add(:website, "is already #{other.name}'s") if other
      end
  end
end
