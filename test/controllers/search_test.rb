require_relative "../test_helper"

module Market
  # Settings › Market, pulling search data, tracking searches and the findings, as people and agents use them.
  class SearchTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    setup do
      ::Setting.current.toggle_plugin!(:market, enabled: true)
      @client = clients(:acme)
      @profile = Profile.for(@client).tap { it.revise(website: "https://acme.example") }
      @rival = Competitor.create!(name: "Rival Plumbing", website: "https://rival.example")
      Rivalry.create!(client: @client, competitor: @rival)
      sign_in_as users(:ted)
    end

    test "settings: the password is never sent back, a blank one keeps it, and the budget is in dollars" do
      connect_search
      get market_settings_path
      assert_response :success
      assert_not_includes response.body, "secret"
      assert_includes response.body, "api@example.com"

      patch market_settings_path, params: { setting: { dataforseo_password: "", monthly_budget_dollars: "40.50", refresh: "weekly", country: "United Kingdom" } }
      assert_redirected_to market_settings_path
      setting = Setting.current
      assert_equal [ "secret", 4050, "weekly", "United Kingdom" ], [ setting.dataforseo_password, setting.monthly_budget_cents, setting.refresh, setting.country ]
      assert_not_equal "secret", Setting.connection.select_value("SELECT dataforseo_password FROM market_settings")

      patch market_settings_path, params: { setting: { keyword_limit: 5 } }
      assert_response :unprocessable_entity

      get market_settings_path(format: :json)
      body = response.parsed_body
      assert_equal [ true, 40.5 ], [ body["dataforseo"]["connected"], body["budget"]["monthly"] ]
      assert_not_includes response.body, "secret"
    end

    test "only those who manage settings see them" do
      sign_in_as users(:sarah)
      get market_settings_path
      assert_response :redirect
      patch market_settings_path, params: { setting: { country: "France" } }
      assert_equal "United States", Setting.current.country
    end

    test "checking the connection reports the balance, or why not" do
      connect_search
      with_balance(-> { 12.34.to_d }) { post market_settings_check_path }
      assert_match "$12.34", flash[:notice]

      with_balance(-> { raise Search::Client::AuthError.new("DataForSEO 40100: not authorized") }) { post market_settings_check_path }
      assert_match "40100", flash[:alert]
      assert_match "40100", Setting.current.last_error
    end

    test "a pull needs DataForSEO, a website and budget, then runs in the background" do
      post market_client_search_pulls_path(@client)
      assert_match "Connect DataForSEO", flash[:alert]

      connect_search(budget_cents: 0)
      post market_client_search_pulls_path(@client)
      assert_match "budget is spent", flash[:alert]

      Setting.current.update!(monthly_budget_cents: 1000)
      assert_enqueued_with(job: SearchPullJob) { post market_client_search_pulls_path(@client), params: { pull: { force: "1" } } }
      assert_match "At most $", flash[:notice]
      assert SearchPull.last.force

      post market_client_search_pulls_path(@client)
      assert_match "already running", flash[:alert]

      get market_client_search_pulls_path(@client, format: :json)
      assert_equal "queued", response.parsed_body["pulls"].first["state"]
      get market_client_search_pulls_path(@client)
      assert_response :success
    end

    test "the client's search data: on the page and in full for agents" do
      connect_search
      SearchPull.create!(client: @client, user: users(:ted)).run!(api: TestHelpers::FakeApi.new(
        traffic: { "acme.example" => 300, "rival.example" => 900 },
        keywords: { "acme.example" => [ { "keyword" => "plumber", "volume" => 1000, "position" => 12 } ],
                    "rival.example" => [ { "keyword" => "plumber", "volume" => 1000, "position" => 2 }, { "keyword" => "drains", "volume" => 400, "position" => 5 } ] },
        competitors: [ { "domain" => "bigbox.example", "shared_keywords" => 40, "organic_traffic" => 5000 } ]))
      post market_client_keywords_path(@client), params: { keyword: { keywords: "plumber, emergency plumber\nplumber" } }
      assert_match "Tracking “plumber” and “emergency plumber”", flash[:notice]

      get market_client_path(@client)
      assert_response :success
      assert_select "#search table.market-compare tbody tr", 2 + 2
      assert_includes response.body, "bigbox.example"
      assert_includes response.body, "Not checked yet"
      assert_select "#findings .market-keyword-chips li", text: /drains/

      get market_client_search_path(@client, format: :json, keywords: 1)
      body = response.parsed_body
      assert_equal [ "acme.example", "rival.example" ], body["sites"].map { it["domain"] }
      assert_equal 900, body["sites"].last["overview"]["organic_traffic"]
      assert_equal 1, body["sites"].last["keywords"].size
      assert_equal [ "emergency plumber", "plumber" ], body["tracked"].map { it["keyword"] }
      assert_equal "bigbox.example", body["also_competing_in_search"].first["domain"]

      keyword = Keyword.find_by!(keyword: "plumber")
      delete market_client_keyword_path(@client, keyword)
      assert_not Keyword.exists?(keyword.id)
    end

    test "findings for a harness: worst first, with evidence, and since a time only what changed" do
      Finding.refresh(@client, now: 2.days.ago)
      get market_findings_path(format: :json, client_id: @client.id)
      body = response.parsed_body
      as_of = body["as_of"]
      keys = body["findings"].map { it["key"] }
      assert_includes keys, "stale_site"
      assert body["findings"].all? { it["state"] == "open" && it["sources"].is_a?(Array) }

      get market_findings_path(format: :json, since: as_of)
      assert_empty response.parsed_body["findings"]

      finding = Finding.find_by!(key: "stale_site")
      patch market_finding_path(finding), params: { finding: { state: "dismissed" } }
      get market_findings_path(format: :json, since: as_of)
      assert_equal [ [ "stale_site", "dismissed" ] ], response.parsed_body["findings"].map { it.values_at("key", "state") }

      get market_findings_path(format: :json, since: "yesterday-ish")
      assert_response :unprocessable_entity

      post market_findings_path, params: { client_id: @client.id }
      assert_redirected_to market_findings_path(client_id: @client.id)
      get market_findings_path
      assert_response :success
      get market_findings_path(state: "all", severity: "low")
      assert_response :success
    end

    test "the overview and the client's JSON carry the findings" do
      Finding.refresh(@client)
      get market_client_path(@client, format: :json)
      assert_includes response.parsed_body["findings"].map { it["key"] }, "stale_site"
      get market_overview_path(format: :json)
      assert response.parsed_body.key?("top_findings")
    end

    test "the nightly run pulls clients due one, within the budget, and works out findings" do
      connect_search(refresh: "weekly")
      SearchPull.create!(client: @client, state: "ready", created_at: 8.days.ago)

      assert_enqueued_jobs 1, only: SearchPullJob do
        NightlyJob.perform_now
      end
      assert_enqueued_with(job: FindingsJob, args: [ @client ])

      SearchPull.last.update!(state: "ready")
      assert_no_enqueued_jobs(only: SearchPullJob) { NightlyJob.perform_now }
    end

    private
      def with_balance(answer)
        original = Search::Client.instance_method(:balance)
        Search::Client.define_method(:balance) { answer.call }
        yield
      ensure
        Search::Client.define_method(:balance, original)
      end
  end
end
