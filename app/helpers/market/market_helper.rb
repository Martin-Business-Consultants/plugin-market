module Market
  module MarketHelper
    # The comparison's columns: what a website shows about how a business markets itself.
    MARKET_COLUMNS = {
      "Ads" => %w[google_ads meta_pixel microsoft_ads tiktok_pixel linkedin_insight],
      "Measures" => %w[google_analytics tag_manager call_tracking],
      "Converts" => %w[chat booking reviews_widget email_capture]
    }.freeze

    def market_client_options = Client.active.ordered.pluck(:name, :id)
    def market_industry_options = Market::Industry.ordered.pluck(:name, :id)

    # A threat, an impact or an effort, tinted by how much it matters.
    def market_level_tag(level, label = level.to_s.humanize, kind: :impact)
      tone = { "high" => "high", "medium" => "medium", "low" => "low" }.fetch(level.to_s, "low")
      tone = { "high" => "low", "low" => "high" }.fetch(tone, tone) if kind == :effort
      tone = "danger" if kind == :threat && tone == "high"
      tag.span label, class: "market-level market-level--#{tone} txt-nowrap"
    end

    def market_threat_tag(rivalry) = market_level_tag(rivalry.threat, "#{rivalry.threat.capitalize} threat", kind: :threat)
    def market_impact_tag(opportunity) = market_level_tag(opportunity.impact, "#{opportunity.impact.capitalize} impact")
    def market_effort_tag(opportunity) = market_level_tag(opportunity.effort, "#{opportunity.effort.capitalize} effort", kind: :effort)

    def market_severity_tag(finding)
      tone = { "high" => "danger", "medium" => "medium", "low" => "low", "info" => "low" }.fetch(finding.severity)
      tag.span finding.severity == "info" ? "Worth knowing" : "#{finding.severity.capitalize}", class: "market-level market-level--#{tone} txt-nowrap"
    end

    # A figure and how it moved since the pull before: "1,240 ↑12%".
    def market_change(now, before)
      return tag.span("–", class: "txt-subtle") if now.nil?

      text = number_with_delimiter(now)
      return text if before.nil? || before.to_i.zero? || now == before

      change = ((now.to_f - before) * 100 / before).round
      safe_join([ text, " ", tag.span("#{change.positive? ? "↑" : "↓"}#{change.abs}%", class: change.positive? ? "market-up" : "market-down") ])
    end

    # A tracked position and how it moved: "4 ↑2"; lower is better.
    def market_position(now, before)
      return tag.span("–", class: "txt-subtle", title: "Not in the top #{Market::Search::Api::RANKING_DEPTH}") if now.nil?
      return now.to_s if before.nil? || before == now

      safe_join([ now.to_s, " ", tag.span("#{now < before ? "↑" : "↓"}#{(before - now).abs}", class: now < before ? "market-up" : "market-down") ])
    end

    def market_state_tag(opportunity)
      status_tag({ "open" => "Open", "planned" => "Planned", "done" => "Done", "dismissed" => "Dismissed" }.fetch(opportunity.state))
    end

    # The tools a reading found, by label.
    def market_tool_labels(reading, keys = Market::Probe::TOOLS.keys)
      return [] unless reading

      keys.select { reading.runs?(it) }.map { Market::Probe::TOOLS.dig(it, 0) }
    end

    # One line on what a reading found: pages, posts, how fresh, what it runs.
    def market_reading_line(reading)
      return "Not read yet" unless reading
      return "Couldn't be read: #{reading.error}" unless reading.read?

      sitemap = reading.sitemap
      parts = []
      parts << "#{sitemap["pages"]}#{"+" if reading.partial_sitemap?} pages" if sitemap["pages"]
      parts << "#{pluralize(sitemap["posts"], "post")} (#{sitemap["posts_last_90_days"]} in 90 days)" if sitemap["posts"].to_i.positive?
      parts << pluralize(sitemap["locations"], "location page") if sitemap["locations"].to_i.positive?
      parts << "runs #{market_tool_labels(reading, MARKET_COLUMNS["Ads"]).to_sentence}" if market_tool_labels(reading, MARKET_COLUMNS["Ads"]).any?
      parts << "no sitemap" if reading.facts.dig("sitemap", "error")
      parts.join(" · ").presence || "Read; nothing to count"
    end

    # A comparison cell's figure, or a dash.
    def market_figure(reading, key)
      value = reading&.figure(key)
      return tag.span("–", class: "txt-subtle") if value.nil?
      return l(Date.parse(value), format: :short) if key.to_s == "last_changed"
      return "#{number_with_delimiter(value)}+" if reading.partial_sitemap? && key.to_s.in?(%w[pages posts locations services posts_last_90_days])

      value.is_a?(Integer) ? number_with_delimiter(value) : value
    end

    # Which of a column's tools a reading found: a lit dot each, named on hover.
    def market_tool_dots(reading, keys)
      return tag.span("–", class: "txt-subtle") unless reading&.read?

      found = keys.select { reading.runs?(it) }
      return tag.span("None", class: "txt-subtle txt-x-small") if found.empty?

      safe_join(found.map do |key|
        label = Market::Probe::TOOLS.dig(key, 0)
        tag.span(class: "market-dot market-dot--on", title: label) + tag.span(label, class: "for-screen-reader")
      end, " ")
    end

    def market_checked_text(reading)
      reading ? "Read #{time_ago_in_words(reading.taken_at)} ago" : "Not read yet"
    end
  end
end
