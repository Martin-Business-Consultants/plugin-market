module Market
  # A client's market: their industry, website, where and whom they serve, what they sell, how
  # they want to be seen, and what they're after. What a plan is drafted from, with their
  # competitors and the readings of everyone's websites. One per client, made when first saved.
  class Profile < ApplicationRecord
    include Watched

    FIELDS = %i[website service_area offerings audience positioning goals notes].freeze

    belongs_to :client, class_name: "::Client"
    belongs_to :industry, optional: true

    normalizes :website, with: ->(url) { url.strip.chomp("/").presence }
    normalizes :search_location, with: ->(location) { location.split(",").map(&:strip).compact_blank.join(",").presence }

    validates :client_id, uniqueness: true
    validates :website, format: { with: %r{\Ahttps?://\S+\z}, message: "must start with http:// or https://" }, allow_nil: true

    before_save { self.domain = Probe.normalize(website) }

    def self.for(client) = find_or_initialize_by(client: client)

    def name = client.name
    def industry_name = industry&.name

    # Saves the person's changes, with the industry by name when one is given (made if new).
    def revise(attributes)
      attributes = attributes.to_h.symbolize_keys
      if attributes.key?(:industry_name)
        name = attributes.delete(:industry_name)
        attributes[:industry] = name.present? ? Industry.named(name) : nil
      end
      update(attributes)
    end

    # How complete it is: the fields a good plan needs.
    def gaps
      { "industry" => industry, "website" => website, "service area" => service_area, "what they sell" => offerings,
        "who they serve" => audience, "goals" => goals }.select { |_, value| value.blank? }.keys
    end
  end
end
