module Market
  # Where everyone ranked for one tracked keyword at one check: the organic results (position,
  # domain, url), the client's own position, and what else was on the page.
  class Ranking < ApplicationRecord
    belongs_to :keyword
    belongs_to :pull, class_name: "SearchPull", optional: true

    serialize :results, coder: JSON, type: Array
    serialize :features, coder: JSON, type: Array

    # The latest two checks of each keyword: { keyword_id => [latest, previous] }.
    def self.latest_for(keywords)
      ids = Array(keywords).map(&:id)
      return {} if ids.empty?

      latest = where(keyword_id: ids).group(:keyword_id).maximum(:id)
      previous = where(keyword_id: ids).where.not(id: latest.values).group(:keyword_id).maximum(:id)
      rows = where(id: latest.values + previous.values).index_by(&:id)
      latest.to_h { |keyword_id, id| [ keyword_id, [ rows[id], rows[previous[keyword_id]] ].compact ] }
    end

    # Where a domain (or one of its subdomains) ranked; nil when not in the results.
    def position_of(domain)
      domain = Probe.normalize(domain)
      return nil if domain.blank?

      results.find { (row = row_domain(it)) == domain || row.end_with?(".#{domain}") }&.dig("position")
    end

    private
      def row_domain(row) = Probe.normalize(row["domain"]).to_s
  end
end
