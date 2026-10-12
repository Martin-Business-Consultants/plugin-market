require_relative "../test_helper"

module Market
  # Every page, as a person and as JSON for agents, with something on it.
  class PagesTest < ActionDispatch::IntegrationTest
    setup do
      Setting.current.toggle_plugin!(:market, enabled: true)
      @client = clients(:acme)
      @profile = Profile.for(@client).tap { it.revise(industry_name: "Plumbing", website: "https://acme.example", goals: "More calls") }
      @rival = Competitor.create!(name: "Rival Plumbing", website: "https://rival.example", industry: @profile.industry)
      @rivalry = Rivalry.create!(client: @client, competitor: @rival, threat: "high")
      read(@rival)
      read(@rival, pages: 80, tools: %w[google_analytics google_ads])
      read(@profile, pages: 12, tools: [])
      @opportunity = @client.market_opportunities.create!(title: "Publish a page for each town", channel: "local", impact: "high", effort: "low", horizon: "now")
      sign_in_as users(:sarah)
    end

    test "404 while the plugin is off" do
      Setting.current.toggle_plugin!(:market, enabled: false)
      get market_overview_path
      assert_response :not_found
    end

    test "the overview: industries, best opportunities, what competitors changed, clients to map" do
      get market_overview_path
      assert_response :success
      assert_select ".settings-nav a[aria-current='page']", "Overview"
      assert_includes response.body, "Publish a page for each town"
      assert_includes response.body, "Now runs Google Ads"
      assert_includes response.body, clients(:globex).name

      get market_overview_path(format: :json)
      body = response.parsed_body
      assert_match "1 industry", body["summary"]
      assert_equal "Publish a page for each town", body["best_opportunities"].first["title"]
      assert_equal [ clients(:globex).name ], body["clients_without_industry"].map { it["display_name"] }
    end

    test "a client's market: profile, the comparison, opportunities" do
      get market_client_path(@client)
      assert_response :success
      assert_select "table.market-compare tbody tr", 2
      assert_select ".market-compare__own", 1
      assert_select ".market-dot--on[title='Google Ads']", 1
      assert_includes response.body, "High threat"
      assert_select "#opportunity_#{@opportunity.id}"
      assert_select "form[action='#{market_opportunity_todo_path(@opportunity)}']"

      get market_client_path(@client, format: :json)
      body = response.parsed_body
      assert_equal "Plumbing", body["profile"]["industry"]["display_name"]
      assert_equal "Rival Plumbing", body["competitors"].first["display_name"]
      assert_equal 80, body["competitors"].first["latest_reading"]["facts"]["sitemap"]["pages"]
      assert_includes body["competitors"].first["latest_reading"]["changes"], "Now runs Google Ads"
      assert_equal 12, body["own_website"]["facts"]["sitemap"]["pages"]
    end

    test "a client with nothing known yet still has a page" do
      get market_client_path(clients(:globex))
      assert_response :success
      assert_includes response.body, "No competitors yet"
    end

    test "the lists, as pages and JSON" do
      get market_clients_path
      assert_response :success
      assert_includes response.body, "acme.example"
      get market_clients_path(show: "gaps", format: :json)
      assert_equal [ clients(:globex).name ], response.parsed_body["clients"].map { it["display_name"] }

      get market_industries_path
      assert_response :success
      get market_industry_path(@profile.industry)
      assert_response :success
      assert_includes response.body, "Rival Plumbing"
      get market_industry_path(@profile.industry, format: :json)
      assert_equal 1, response.parsed_body["open_by_channel"].first["count"]

      get market_competitors_path(q: "rival")
      assert_response :success
      assert_includes response.body, "Rival Plumbing"
      assert_select "td a[href='#{market_client_path(@client)}']", @client.name
      get market_competitors_path(format: :json, client_id: @client.id)
      assert_equal [ "Google Ads", "Google Analytics" ], response.parsed_body["competitors"].first["tools"]

      get market_competitor_path(@rival)
      assert_response :success
      assert_includes response.body, "+40 pages (now 80)"
      assert_includes response.body, "Google Ads and Google Analytics"
      get market_competitor_path(@rival, format: :json)
      assert_equal 1, response.parsed_body["changes"].size

      get market_opportunities_path
      assert_response :success
      get market_opportunities_path(format: :json, channel: "local")
      assert_equal "Publish a page for each town", response.parsed_body["opportunities"].first["title"]

      get market_client_plans_path(@client, format: :json)
      assert_match "No plan", response.parsed_body["summary"]
    end

    test "the client's Market tab" do
      get client_path(@client, tab: "plugin-market")
      assert_response :success
      assert_includes response.body, "Rival Plumbing"
      assert_includes response.body, "Publish a page for each town"
    end
  end
end
