require_relative "../test_helper"

module Market
  class SnapshotTest < ActiveSupport::TestCase
    setup { @rival = Competitor.create!(name: "Rival", website: "https://www.rival.example/") }

    test "the first reading has no changes; later ones say what moved" do
      first = read(@rival)
      assert_empty first.differences
      assert_equal "rival.example", first.domain

      second = read(@rival, pages: 70, posts: 14, tools: %w[google_analytics google_ads], title: "Rival Plumbing | Same-day", locations: 2)
      assert_includes second.differences, "Home page title: “Rival Plumbing” → “Rival Plumbing | Same-day”"
      assert_includes second.differences, "Now runs Google Ads"
      assert_includes second.differences, "+30 pages (now 70)"
      assert_includes second.differences, "+4 posts (now 14)"
      assert_not second.differences.any? { it.include?("location") }
      assert_equal second, @rival.reload.latest_snapshot
    end

    test "small moves aren't changes, and what stopped is" do
      read(@rival, pages: 100)
      later = read(@rival, pages: 104, tools: [])

      assert_equal [ "No longer runs Google Analytics" ], later.differences
    end

    test "a site that couldn't be read at all keeps why, and isn't compared against" do
      failed = Snapshot.take(@rival, probe: TestHelpers::FakeProbe.new("rival.example",
        { "domain" => "rival.example", "home_page" => { "error" => "Timeout" }, "sitemap" => { "error" => "none found" } }))
      assert_not failed.read?
      assert_match "Timeout", failed.error

      assert_empty read(@rival).differences
    end

    test "the latest reading of each, in one query" do
      other = Competitor.create!(name: "Other", website: "https://other.example")
      read(@rival)
      newest = read(@rival)
      theirs = read(other)

      assert_equal({ @rival.id => newest, other.id => theirs }, Snapshot.latest_for([ @rival, other ]))
      assert_equal({}, Snapshot.latest_for([]))
    end
  end
end
