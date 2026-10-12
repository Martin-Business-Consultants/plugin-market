module Market
  # One client's search data, pulled from DataForSEO in SearchPullJob: for the client's site and
  # each competitor's, its overview and the keywords it ranks for; who else competes with the
  # client in search; backlinks when Settings › Market has them on; and where everyone ranks for
  # the client's tracked keywords, searched from where their customers are.
  #
  # Each part stands alone: one that fails is noted and the rest carry on. A part pulled in the
  # last FRESH_FOR isn't paid for twice unless the pull is forced. A wrong login, an empty
  # account or the month's budget stops the pull where it is ("stopped"), keeping what it got.
  # The findings are worked out again at the end (Finding.refresh).
  class SearchPull < ApplicationRecord
    STATES = %w[queued running ready partial stopped failed].freeze
    STUCK_AFTER = 30.minutes

    belongs_to :client, class_name: "::Client"
    belongs_to :user, class_name: "::User", optional: true
    has_many :requests, class_name: "SearchRequest", foreign_key: :pull_id, dependent: :nullify, inverse_of: :pull

    serialize :notes, coder: JSON, type: Array

    validates :state, inclusion: { in: STATES }

    scope :latest_first, -> { order(id: :desc) }

    def working? = state.in?(%w[queued running]) && updated_at > STUCK_AFTER.ago
    def done? = state.in?(%w[ready partial stopped failed]) || !working?
    def run_later = SearchPullJob.perform_later(self)

    # The most it could cost, for saying so before it runs: every part for every site.
    def self.ceiling_for(client, setting: Setting.current)
      sites = 1 + Rivalry.where(client: client).joins(:competitor).where.not(market_competitors: { domain: [ nil, "" ] }).count
      per_site = Search::Api::CEILINGS.values_at(:overview, :keywords).sum + (setting.backlinks ? Search::Api::CEILINGS[:backlinks] : 0)
      (sites * per_site + Search::Api::CEILINGS[:competitors] + Keyword.where(client: client).count * Search::Api::CEILINGS[:ranking]).round(2)
    end

    # Called by SearchPullJob. Never raises: what went wrong is in `notes` and `error`.
    def run!(api: nil)
      update!(state: "running", started_at: Time.current, notes: [])
      setting = Setting.current
      @api = api || Search::Api.new(client: Search::Client.new(setting: setting, pull: self), setting: setting)
      profile = Profile.find_by(client: client)
      raise Search::Client::InvalidError.new("#{client.name} has no website on their market profile") unless profile&.domain

      gather(profile, setting)
      finish(notes.any? { it.start_with?("Couldn't") } ? "partial" : "ready")
    rescue Search::Client::Error => error
      setting&.note_error!(error.message) if error.is_a?(Search::Client::AuthError) || error.is_a?(Search::Client::FundsError)
      finish(Search::Client.stopping?(error) ? "stopped" : "failed", error: error.message)
    rescue => error
      Rails.logger.error("[market] search pull #{id}: #{error.class}: #{error.message}")
      finish("failed", error: "#{error.class.name.demodulize}: #{error.message}")
    end

    private
      def gather(profile, setting)
        competitors = Rivalry.where(client: client).includes(:competitor).map(&:competitor).select { it.domain.present? }
        [ profile, *competitors ].each do |subject|
          part(subject, "overview") { @api.overview(subject.domain) }
          part(subject, "keywords") { @api.keywords(subject.domain) }
          part(subject, "backlinks") { @api.backlinks(subject.domain) } if setting.backlinks
        end
        part(profile, "competitors") { @api.competitors(profile.domain) }
        rankings(profile, setting)
      end

      # One part for one site, kept as a snapshot; skipped when fresh, noted when it fails.
      def part(subject, kind)
        if !force && SearchSnapshot.fresh?(subject, kind)
          note "#{kind.capitalize} for #{subject.domain}: pulled in the last day, kept"
          return
        end

        data = yield
        SearchSnapshot.create!(subject: subject, pull: self, domain: subject.domain, kind: kind, location: Setting.current.country, data: data, taken_at: Time.current)
      rescue Search::Client::Error => error
        raise if Search::Client.stopping?(error)

        note "Couldn't get #{kind} for #{subject.domain}: #{error.message}"
      end

      def rankings(profile, setting)
        location = profile.search_location.presence || setting.country
        Keyword.where(client: client).ordered.each do |keyword|
          answer = @api.ranking(keyword.keyword, location: location)
          ranking = keyword.rankings.new(pull: self, location: location, results: answer["results"], features: answer["features"], checked_at: Time.current)
          ranking.client_position = ranking.position_of(profile.domain)
          ranking.client_url = ranking.results.find { it["position"] == ranking.client_position }&.dig("url")
          ranking.save!
        rescue Search::Client::Error => error
          raise if Search::Client.stopping?(error)

          note "Couldn't check “#{keyword.keyword}” from #{location}: #{error.message}"
        end
      end

      def note(text) = (self.notes = Array(notes) + [ text.truncate(300) ])

      def finish(state, error: nil)
        update_columns(state: state, error: error&.truncate(500), notes: Array(notes), cost: requests.sum(:cost),
          finished_at: Time.current, updated_at: Time.current)
        Finding.refresh(client)
      rescue => failure
        Rails.logger.error("[market] finishing search pull #{id}: #{failure.class}: #{failure.message}")
      end
  end
end
