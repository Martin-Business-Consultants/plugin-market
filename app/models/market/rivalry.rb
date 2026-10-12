module Market
  # A competitor of one client: how (direct, indirect, or the one they aspire to be) and how much
  # of a threat it is to them.
  class Rivalry < ApplicationRecord
    KINDS = { "direct" => "Direct", "indirect" => "Indirect", "aspirational" => "Aspirational" }.freeze
    THREATS = %w[high medium low].freeze

    belongs_to :client, class_name: "::Client"
    belongs_to :competitor

    validates :kind, inclusion: { in: KINDS.keys }
    validates :threat, inclusion: { in: THREATS }
    validates :competitor_id, uniqueness: { scope: :client_id, message: "is already one of theirs" }

    scope :by_threat, -> { in_order_of(:threat, THREATS) }

    def kind_label = KINDS.fetch(kind)
  end
end
