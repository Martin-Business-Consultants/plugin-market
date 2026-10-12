require_relative "../test_helper"

module Market
  class SearchPullTest < ActiveSupport::TestCase
    setup do
      connect_search
      @client = clients(:acme)
      @profile = Profile.for(@client).tap { it.revise(website: "https://acme.example", search_location: "Springfield, Illinois, United States") }
      @rival = Competitor.create!(name: "Rival", website: "https://rival.example")
      Rivalry.create!(client: @client, competitor: @rival)
      Keyword.track(@client, "emergency plumber\nwater heater repair")
      @pull = SearchPull.create!(client: @client, user: users(:ted))
    end

    def api(**options)
      TestHelpers::FakeApi.new(keywords: { "rival.example" => [ { "keyword" => "drain cleaning", "volume" => 900, "position" => 3 } ] },
        competitors: [ { "domain" => "bigbox.example", "shared_keywords" => 40 } ],
        rankings: { "emergency plumber" => [ { "position" => 1, "domain" => "rival.example", "url" => "https://rival.example/" },
                                              { "position" => 5, "domain" => "www.acme.example", "url" => "https://www.acme.example/emergency" } ] }, **options)
    end

    test "every part for every site, the rankings from where customers search, then the findings" do
      fake = api
      @pull.run!(api: fake)

      assert_equal "ready", @pull.reload.state
      assert_equal %w[overview:acme.example keywords:acme.example overview:rival.example keywords:rival.example competitors:acme.example
                      ranking:emergency\ plumber ranking:water\ heater\ repair], fake.calls
      assert_equal 5, SearchSnapshot.count
      ranking = Keyword.find_by!(keyword: "emergency plumber").rankings.first
      assert_equal [ 5, "https://www.acme.example/emergency", "Springfield,Illinois,United States" ], [ ranking.client_position, ranking.client_url, ranking.location ]
      assert_equal 1, ranking.position_of("rival.example")
      assert_nil Keyword.find_by!(keyword: "water heater repair").rankings.first.client_position
      assert Finding.exists?(client: @client, key: "keyword_gap:rival.example")
      assert Finding.exists?(client: @client, key: "unwatched_search_competitors")
    end

    test "parts pulled in the last day are kept rather than bought again, unless forced" do
      @pull.run!(api: api)
      again = SearchPull.create!(client: @client)
      fake = api
      again.run!(api: fake)
      assert_equal [ "ranking:emergency plumber", "ranking:water heater repair" ], fake.calls
      assert_includes again.reload.notes.first, "pulled in the last day, kept"

      forced = SearchPull.create!(client: @client, force: true)
      fake = api
      forced.run!(api: fake)
      assert_equal 7, fake.calls.size
    end

    test "a part that fails is noted and the rest carry on" do
      @pull.run!(api: api(failures: { "keywords:rival.example" => Search::Client::InvalidError.new("DataForSEO 40501: invalid field") }))

      assert_equal "partial", @pull.reload.state
      assert_equal [ "Couldn't get keywords for rival.example: DataForSEO 40501: invalid field" ], @pull.notes
      assert_equal 4, SearchSnapshot.count
    end

    test "the budget running out stops the pull where it is, keeping what it got" do
      @pull.run!(api: api(failures: { "overview:rival.example" => Search::Client::BudgetError.new("This month's search budget has $0.01 left") }))

      assert_equal [ "stopped", "This month's search budget has $0.01 left" ], @pull.reload.values_at(:state, :error)
      assert_equal 2, SearchSnapshot.count
      assert_equal 0, Ranking.count
    end

    test "a wrong login stops it and says so in Settings" do
      @pull.run!(api: api(failures: { "overview:acme.example" => Search::Client::AuthError.new("DataForSEO 40100: not authorized") }))

      assert_equal "stopped", @pull.reload.state
      assert_equal "DataForSEO 40100: not authorized", Setting.current.reload.last_error
    end

    test "no website, no pull" do
      @profile.update!(website: nil)
      @pull.run!(api: api)
      assert_equal "failed", @pull.reload.state
      assert_match "no website", @pull.error
    end

    test "what it could cost at most, said before it runs" do
      assert_equal (2 * (0.05 + 0.25) + 0.10 + 2 * 0.02).round(2), SearchPull.ceiling_for(@client)
    end
  end
end
