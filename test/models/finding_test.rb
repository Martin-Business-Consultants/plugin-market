require_relative "../test_helper"

module Market
  class FindingTest < ActiveSupport::TestCase
    setup do
      connect_search
      @client = clients(:acme)
      @profile = Profile.for(@client).tap { it.revise(industry_name: "Plumbing", website: "https://acme.example", service_area: "Springfield", offerings: "Drains", audience: "Homes", goals: "Calls") }
      @rival = Competitor.create!(name: "Rival", website: "https://rival.example")
      Rivalry.create!(client: @client, competitor: @rival)
    end

    def search(subject, kind, data, at: Time.current)
      SearchSnapshot.create!(subject: subject, domain: subject.domain, kind: kind, data: data, taken_at: at)
    end

    def keywords(*rows) = { "keywords" => rows.map { |keyword, position, volume| { "keyword" => keyword, "position" => position, "volume" => volume } } }

    def ranking(keyword, client_position, results, at:)
      keyword.rankings.create!(location: "United States", client_position: client_position, results: results, features: [ "local_pack" ], checked_at: at)
    end

    test "what the readings, search data and rankings say, with the figures and where they came from" do
      read(@profile, posts: 0, tools: [], locations: 0, recent: 0)
      read(@rival, posts: 10, tools: %w[google_ads booking], locations: 12)
      search(@profile, "keywords", keywords([ "plumber", 8, 2000 ]))
      theirs = search(@rival, "keywords", keywords([ "plumber", 2, 2000 ], [ "drain cleaning", 3, 900 ], [ "sump pump", 6, 300 ], [ "far away", 15, 5000 ]))
      search(@profile, "overview", { "organic_traffic" => 1000 }, at: 40.days.ago)
      search(@profile, "overview", { "organic_traffic" => 600 })
      search(@profile, "competitors", { "competitors" => [ { "domain" => "bigbox.example", "shared_keywords" => 40 }, { "domain" => "www.rival.example", "shared_keywords" => 30 } ] })
      tracked = Keyword.track(@client, "plumber").first.first
      ranking(tracked, 3, [ { "position" => 1, "domain" => "rival.example" } ], at: 7.days.ago)
      ranking(tracked, 9, [ { "position" => 2, "domain" => "rival.example" }, { "position" => 9, "domain" => "acme.example" } ], at: 1.hour.ago)

      found = Finding.refresh(@client).index_by(&:key)

      gap = found.fetch("keyword_gap:rival.example")
      assert_equal [ "high", "seo" ], [ gap.severity, gap.channel ]
      assert_equal [ "drain cleaning", "sump pump" ], gap.evidence["keywords"].map { it["keyword"] }
      assert_equal 1200, gap.evidence["monthly_searches"]
      assert_includes gap.sources.map { it["id"] }, theirs.id
      assert_equal({ "organic_traffic_before" => 1000, "organic_traffic_now" => 600, "change_percent" => -40, "keywords_before" => 0, "keywords_now" => 0 }, found.fetch("losing_ground").evidence)
      assert_equal [ { "keyword" => "plumber", "was" => 3, "now" => 9, "ranking" => tracked.rankings.first.id } ], found.fetch("ranking_drops").evidence["drops"]
      assert_equal "high", found.fetch("ranking_drops").severity
      assert_equal({ "Rival" => 1 }, found.fetch("outranked").evidence["by_competitor"])
      assert found.key?("map_pack")
      assert_equal [ { "competitor" => "Rival", "paid_keywords" => 0, "google_ads_tag" => true } ], found.fetch("competitor_ads").evidence["competitors"]
      assert_equal 0, found.fetch("location_pages").evidence["yours"]
      assert found.key?("content_freshness")
      assert_equal [ "Online booking" ], found.fetch("conversion_tools").evidence["missing"].map { it["tool"] }
      assert_equal [ "bigbox.example" ], found.fetch("unwatched_search_competitors").evidence["sites"].map { it["domain"] }
      assert_not found.key?("profile_gaps")
      assert_not found.key?("stale_search")
    end

    test "a finding lives while it holds: changed_at moves only when it changes, and it resolves when it stops" do
      first = Finding.refresh(@client, now: 3.days.ago).index_by(&:key)
      assert_equal %w[stale_search stale_site], first.keys.sort

      same = Finding.refresh(@client, now: 2.days.ago).find_by!(key: "stale_search")
      assert_equal [ first["stale_search"].first_seen_at.to_i, first["stale_search"].changed_at.to_i ], [ same.first_seen_at.to_i, same.changed_at.to_i ]
      assert_equal 2.days.ago.to_i, same.last_seen_at.to_i

      search(@profile, "overview", { "organic_traffic" => 10 })
      Finding.refresh(@client, now: 1.day.ago)
      gone = Finding.find_by!(key: "stale_search")
      assert_equal [ "resolved", 1.day.ago.to_i ], [ gone.state, gone.changed_at.to_i ]
    end

    test "dismissed stays dismissed while it holds; one that comes back is open again" do
      Finding.refresh(@client)
      finding = Finding.find_by!(key: "stale_site")
      finding.dismiss(by: users(:ted))
      Finding.refresh(@client)
      assert_equal "dismissed", finding.reload.state
      assert_not_includes Finding.refresh(@client).map(&:key), "stale_site"

      @rival.destroy!
      Finding.refresh(@client)
      assert Finding.find_by!(key: "no_competitors").state == "open"
    end
  end
end
