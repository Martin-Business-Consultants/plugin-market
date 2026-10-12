module Market
  # One call to DataForSEO, whatever came of it: the ledger the monthly budget is checked
  # against, and the history Settings › Market shows.
  class SearchRequest < ApplicationRecord
    belongs_to :pull, class_name: "SearchPull", optional: true

    scope :latest_first, -> { order(created_at: :desc, id: :desc) }

    def ok? = status_code == 20000 && error.blank?
  end
end
