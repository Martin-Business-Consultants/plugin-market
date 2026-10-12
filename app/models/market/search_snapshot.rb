module Market
  # What DataForSEO said about one website (a client's own, a competitor's) at one time, by
  # kind: overview (visibility), keywords (what it ranks for), competitors (who shares its
  # keywords: the client's only) and backlinks. Kept, so movement shows between pulls.
  class SearchSnapshot < ApplicationRecord
    KINDS = %w[overview keywords competitors backlinks].freeze
    FRESH_FOR = 20.hours

    belongs_to :subject, polymorphic: true
    belongs_to :pull, class_name: "SearchPull", optional: true

    serialize :data, coder: JSON, type: Hash

    validates :kind, inclusion: { in: KINDS }

    scope :latest_first, -> { order(taken_at: :desc, id: :desc) }

    # The latest two of each kind for every subject, of any type, in three queries:
    # { subject => { kind => [latest, previous] } }.
    def self.latest_by_subject(subjects, kinds: KINDS)
      subjects = Array(subjects).compact
      return {} if subjects.empty?

      scope = subjects.group_by { it.class.polymorphic_name }.map { |type, list| where(subject_type: type, subject_id: list.map(&:id)) }.reduce(:or).where(kind: kinds)
      latest = scope.group(:subject_type, :subject_id, :kind).maximum(:id)
      previous = scope.where.not(id: latest.values).group(:subject_type, :subject_id, :kind).maximum(:id)
      rows = where(id: latest.values + previous.values).index_by(&:id)
      found = latest.each_with_object(Hash.new { |hash, key| hash[key] = {} }) do |((type, id, kind), row_id), out|
        out[[ type, id ]][kind] = [ rows[row_id], rows[previous[[ type, id, kind ]]] ]
      end
      subjects.to_h { [ it, found.fetch([ it.class.polymorphic_name, it.id ], {}) ] }
    end

    # The latest two of one kind for subjects of one type, by subject id: [latest, previous].
    def self.latest_for(subjects, kind)
      latest_by_subject(subjects, kinds: [ kind ]).to_h { |subject, kinds| [ subject.id, kinds[kind] ] }.compact
    end

    def self.fresh?(subject, kind)
      where(subject: subject, kind: kind, taken_at: FRESH_FOR.ago..).exists?
    end
  end
end
