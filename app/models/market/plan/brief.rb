module Market
  # Everything a plan is drafted from, written out for the AI: the client's profile, their site's
  # latest reading, each competitor with how it competes and its latest reading, other
  # competitors watched in the same industry, and the opportunities already there.
  class Plan::Brief
    def initialize(client)
      @client = client
      @profile = Profile.find_by(client: client)
      @rivalries = Rivalry.where(client: client).includes(competitor: :industry).by_threat.to_a
      @readings = Snapshot.latest_for(@rivalries.map(&:competitor))
    end

    def to_s
      [ client_part, own_site_part, competitors_part, search_part, rankings_part, findings_part, industry_part, work_part ].compact.join("\n\n")
    end

    private
      attr_reader :client, :profile, :rivalries, :readings

      def client_part
        lines = [ "Client: #{client.name}" ]
        if profile
          lines << "Industry: #{profile.industry&.name || "not set"}"
          Profile::FIELDS.each { |field| lines << "#{field.to_s.humanize}: #{profile.public_send(field)}" if profile.public_send(field).present? }
        else
          lines << "No market profile yet."
        end
        lines.join("\n")
      end

      def own_site_part
        reading = profile&.latest_snapshot
        return "The client's website hasn't been read yet." unless reading

        "The client's website (read #{reading.taken_at.to_date.to_fs(:long)}):\n#{JSON.pretty_generate(reading.facts)}"
      end

      def competitors_part
        return "No competitors listed yet." if rivalries.empty?

        "Competitors:\n" + rivalries.map do |rivalry|
          competitor = rivalry.competitor
          reading = readings[competitor.id]
          [ "## #{competitor.name} (#{rivalry.kind_label.downcase}, #{rivalry.threat} threat)#{" — #{competitor.host}" if competitor.host}",
            ("Notes: #{rivalry.notes}" if rivalry.notes.present?),
            ("Strengths: #{competitor.strengths}" if competitor.strengths.present?),
            ("Weaknesses: #{competitor.weaknesses}" if competitor.weaknesses.present?),
            reading ? "Website (read #{reading.taken_at.to_date.to_fs(:long)}): #{JSON.generate(reading.facts.except("domain"))}" : "Website not read yet.",
            (reading && reading.differences.any? ? "Recent changes: #{reading.differences.join("; ")}" : nil) ].compact.join("\n")
        end.join("\n\n")
      end

      # DataForSEO's figures for every site (latest pull), and the client's best keywords.
      def search_part
        subjects = [ profile, *rivalries.map(&:competitor) ].compact.select { it.domain.present? }
        return if subjects.empty?

        overviews = SearchSnapshot.latest_by_subject(subjects, kinds: [ "overview" ]).filter_map { |subject, kinds| [ subject, kinds["overview"].first ] if kinds["overview"] }.to_h
        return if overviews.empty?

        lines = overviews.map do |subject, snapshot|
          name = subject.is_a?(Profile) ? "#{client.name} (the client)" : subject.name
          "- #{name}, #{snapshot.domain} (#{snapshot.taken_at.to_date.to_fs(:long)}): #{JSON.generate(snapshot.data)}"
        end
        keywords = profile && SearchSnapshot.latest_for([ profile ], "keywords")[profile.id]&.first
        top = Array(keywords&.data&.dig("keywords")).first(15).map { "#{it["keyword"]} (##{it["position"]}, #{it["volume"]}/mo)" }
        "Search visibility (DataForSEO, #{Setting.current.country}; traffic is estimated monthly visits):\n#{lines.join("\n")}" +
          (top.any? ? "\nThe client's biggest keywords: #{top.join("; ")}" : "")
      end

      def rankings_part
        keywords = Keyword.where(client: client).ordered.to_a
        latest = Ranking.latest_for(keywords)
        rows = keywords.filter_map do |keyword|
          ranking = latest[keyword.id]&.first or next
          others = rivalries.filter_map { |rivalry| ranking.position_of(rivalry.competitor.domain)&.then { "#{rivalry.competitor.name} ##{it}" } }
          "- “#{keyword.keyword}”: client #{ranking.client_position ? "##{ranking.client_position}" : "not in the top #{Search::Api::RANKING_DEPTH}"}" \
            "#{"; #{others.join(", ")}" if others.any?}#{"; also on the page: #{ranking.features.join(", ")}" if ranking.features.any?}"
        end
        "Tracked searches, from #{rows.any? ? latest.values.first.first.location : "their area"}:\n#{rows.join("\n")}" if rows.any?
      end

      # What the data already says (Finding::Analysis), for the plan to act on.
      def findings_part
        findings = Finding.where(client: client).open.by_severity.limit(25).to_a
        return if findings.empty?

        "Findings from the data (act on these; the evidence is exact):\n" +
          findings.map { "- [#{it.severity}] #{it.title}#{" — #{it.detail}" if it.detail.present?} #{JSON.generate(it.evidence)}".truncate(900) }.join("\n")
      end

      def industry_part
        return unless profile&.industry

        others = profile.industry.competitors.where.not(id: rivalries.map(&:competitor_id)).ordered.limit(20).pluck(:name)
        "Other competitors watched in #{profile.industry.name}: #{others.join(", ")}" if others.any?
      end

      def work_part
        opportunities = Opportunity.where(client: client).order(:id).last(40)
        return "No opportunities yet." if opportunities.empty?

        "Already listed (don't repeat):\n" + opportunities.map { "- [#{it.state}] #{it.channel_label}: #{it.title}" }.join("\n")
      end
  end
end
