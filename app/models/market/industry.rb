module Market
  # An industry: the clients in it and the competitors they share, so what works for one client
  # can be planned for the others, and a market is seen as a whole. NAICS code optional.
  class Industry < ApplicationRecord
    has_many :profiles, dependent: :nullify
    has_many :competitors, dependent: :nullify

    normalizes :name, with: ->(name) { name.strip.squeeze(" ") }
    normalizes :naics_code, with: ->(code) { code.strip.presence }

    validates :name, presence: true, uniqueness: { case_sensitive: false }
    validates :naics_code, format: { with: /\A\d{2,6}\z/, message: "is 2 to 6 digits" }, allow_nil: true

    scope :ordered, -> { order(:name) }

    # The industry called this, made if there isn't one (an AI suggestion accepted, a typed name).
    def self.named(name)
      name = name.to_s.strip.squeeze(" ")
      return nil if name.empty?

      where("LOWER(name) = ?", name.downcase).first || create!(name: name)
    end

    def clients = Client.where(id: profiles.select(:client_id)).order(:name)
  end
end
