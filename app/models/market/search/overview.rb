module Market
  module Search
    # One client's search data as the page and the agents read it: the latest DataForSEO
    # snapshots of every site (and the one before, to compare), the sites sharing the client's
    # keywords, and the tracked keywords with everyone's positions. A few queries in all.
    class Overview
      Site = Data.define(:name, :domain, :subject, :own, :overview, :previous, :keywords, :backlinks) do
        def pulled? = overview.present?
        def figure(key) = overview&.data&.dig(key)
        def before(key) = previous&.data&.dig(key)
      end

      attr_reader :client, :profile, :rivalries, :keywords, :rankings, :competitors_found, :last_pull

      def initialize(client)
        @client = client
        @profile = Profile.find_by(client: client)
        @rivalries = Rivalry.where(client: client).includes(:competitor).by_threat.to_a
        @keywords = Keyword.where(client: client).ordered.to_a
        @rankings = Ranking.latest_for(@keywords)
        @competitors_found = @profile && SearchSnapshot.latest_for([ @profile ], "competitors")[@profile.id]&.first
        @last_pull = SearchPull.where(client: client).latest_first.first
      end

      def sites
        @sites ||= begin
          own = profile&.domain ? [ site(profile, "#{client.name}", true) ] : []
          competitors = rivalries.map(&:competitor).select { it.domain.present? }
          own + competitors.map { site(it, it.name, false) }
        end
      end

      def pulled? = sites.any?(&:pulled?)
      def competitor_sites = sites.reject(&:own)

      # Each tracked keyword with the client's position, now and before, and each competitor's now.
      def tracked
        keywords.map do |keyword|
          now, before = rankings[keyword.id]
          { keyword: keyword, ranking: now, position: now&.client_position, before: before&.client_position,
            competitors: competitor_sites.to_h { [ it.domain, now&.position_of(it.domain) ] } }
        end
      end

      # The sites sharing the client's keywords that no rivalry covers yet.
      def unwatched
        watched = competitor_sites.map(&:domain)
        Array(competitors_found&.data&.dig("competitors")).reject { |row| watched.any? { row["domain"] == it || row["domain"].to_s.end_with?(".#{it}") } }
      end

      private
        def snapshots
          @snapshots ||= SearchSnapshot.latest_by_subject([ profile, *rivalries.map(&:competitor) ].compact.select { it.domain.present? },
            kinds: %w[overview keywords backlinks])
        end

        def site(subject, name, own)
          kinds = snapshots.fetch(subject, {})
          overview, previous = kinds["overview"]
          Site.new(name: name, domain: subject.domain, subject: subject, own: own, overview: overview, previous: previous,
            keywords: kinds["keywords"]&.first, backlinks: kinds["backlinks"]&.first)
        end
    end
  end
end
