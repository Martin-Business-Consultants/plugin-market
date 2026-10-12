require_relative "../../test_helper"

module Market
  module Search
    class ClientTest < ActiveSupport::TestCase
      setup do
        @setting = connect_search
        @waits = []
      end

      def client(*answers)
        @transport = TestHelpers::FakeTransport.new(*answers)
        Client.new(setting: @setting, transport: @transport, wait: ->(seconds) { @waits << seconds })
      end

      test "a task's result, with what it cost in the ledger" do
        result = client([ 200, dataforseo([ { "items" => [] } ], cost: 0.0123) ]).post("dataforseo_labs/google/domain_rank_overview/live", { target: "acme.example" }, target: "acme.example", ceiling: 0.05)

        assert_equal [ { "items" => [] } ], result
        method, url, body = @transport.calls.first
        assert_equal [ :post, "https://api.dataforseo.com/v3/dataforseo_labs/google/domain_rank_overview/live", [ { target: "acme.example" } ] ], [ method, url, body ]
        request = SearchRequest.last
        assert_equal [ 20000, 0.0123.to_d, 1, "acme.example" ], [ request.status_code, request.cost, request.attempts, request.target ]
        assert request.ok?
        assert_in_delta 0.0123, @setting.spent_this_month.to_f
      end

      test "what may pass is tried again, waiting longer each time" do
        result = client([ 503, "busy" ], [ 200, dataforseo(nil, code: 50401, message: "internal error - timeout") ], [ 200, dataforseo([ 1 ]) ])
                   .post("serp/google/organic/live/regular", {}, target: "dentist", ceiling: 0.02)

        assert_equal [ 1 ], result
        assert_equal [ 2, 4 ], @waits
        assert_equal 3, SearchRequest.last.attempts
      end

      test "the network failing every time gives up after three tries, recorded" do
        failing = client(*Array.new(3) { Client::Transient.new("Couldn't reach DataForSEO: SocketError") })
        error = assert_raises(Client::Transient) { failing.post("x/live", {}, target: "t", ceiling: 0.01) }
        assert_match "SocketError", error.message
        assert_equal [ 3, "Couldn't reach DataForSEO: SocketError" ], SearchRequest.last.values_at(:attempts, :error)
      end

      test "a wrong login, no funds or a bad field fail at once, each as itself" do
        assert_raises(Client::AuthError) { client([ 200, dataforseo(nil, code: 40100, message: "not authorized", top_code: 40100) ]).post("x/live", {}, target: "t", ceiling: 0.01) }
        assert_raises(Client::AuthError) { client([ 401, "" ]).post("x/live", {}, target: "t", ceiling: 0.01) }
        assert_raises(Client::FundsError) { client([ 200, dataforseo(nil, code: 40210, message: "insufficient funds") ]).post("x/live", {}, target: "t", ceiling: 0.01) }
        assert_raises(Client::InvalidError) { client([ 200, dataforseo(nil, code: 40501, message: "invalid field") ]).post("x/live", {}, target: "t", ceiling: 0.01) }
        assert_raises(Client::UnavailableError) { client([ 200, dataforseo(nil, code: 40204, message: "access denied") ]).post("x/live", {}, target: "t", ceiling: 0.01) }
        assert_empty @waits
        assert_equal 5, SearchRequest.count
        assert Client.stopping?(Client::FundsError.new("x"))
        assert_not Client.stopping?(Client::InvalidError.new("x"))
      end

      test "something that isn't JSON may pass" do
        assert_equal [ 1 ], client([ 200, "<html>" ], [ 200, dataforseo([ 1 ]) ]).post("x/live", {}, target: "t", ceiling: 0.01)
      end

      test "nothing is asked that could go over the month's budget" do
        @setting.update!(monthly_budget_cents: 10)
        SearchRequest.create!(endpoint: "earlier", cost: 0.09, created_at: Time.current)

        error = assert_raises(Client::BudgetError) { client.post("dataforseo_labs/google/ranked_keywords/live", {}, target: "acme.example", ceiling: 0.25) }
        assert_match "$0.01 left", error.message
        assert_empty @transport.calls
      end

      test "no login, no calls" do
        @setting.update!(dataforseo_password: nil)
        assert_raises(Client::AuthError) { client.post("x/live", {}, target: "t", ceiling: 0.01) }
      end

      test "the balance costs nothing and is kept" do
        balance = @setting.check!(client: client([ 200, dataforseo([ { "money" => { "balance" => 42.5 } } ], cost: 0) ]))
        assert_equal 42.5.to_d, balance
        assert_equal [ 42.5.to_d, nil ], [ @setting.reload.balance, @setting.last_error ]
        assert_equal :get, @transport.calls.first.first
      end

      test "the API's answers are kept compact" do
        api = Api.new(client: client([ 200, dataforseo([ { "items" => [ { "metrics" => {
          "organic" => { "count" => 120, "etv" => 840.6, "pos_1" => 3, "pos_2_3" => 5, "pos_4_10" => 20, "pos_11_20" => 30, "is_new" => 4, "is_lost" => 2 },
          "paid" => { "count" => 6, "etv" => 40.2, "estimated_paid_traffic_cost" => 210.4 } } } ] } ]) ],
          [ 200, dataforseo([ { "total_count" => 900, "items" => [ { "keyword_data" => { "keyword" => "dentist", "keyword_info" => { "search_volume" => 5400, "cpc" => 9.123 },
            "keyword_properties" => { "keyword_difficulty" => 41 }, "search_intent_info" => { "main_intent" => "commercial" } },
            "ranked_serp_element" => { "serp_item" => { "rank_group" => 4, "url" => "https://acme.example/", "etv" => 210.44 } } } ] } ]) ],
          [ 200, dataforseo([ { "keyword" => "dentist", "item_types" => %w[local_pack organic people_also_ask], "items" => [
            { "type" => "organic", "rank_group" => 1, "domain" => "www.rival.example", "url" => "https://www.rival.example/", "title" => "Rival" },
            { "type" => "organic", "rank_group" => 2, "domain" => "acme.example", "url" => "https://acme.example/", "title" => "Acme" } ] } ]) ]), setting: @setting)

        assert_equal({ "organic_keywords" => 120, "organic_traffic" => 841, "top_3" => 8, "top_10" => 28, "top_20" => 58, "new_keywords" => 4, "lost_keywords" => 2,
                       "paid_keywords" => 6, "paid_traffic" => 40, "paid_traffic_value" => 210 }, api.overview("acme.example"))
        assert_equal({ "total" => 900, "keywords" => [ { "keyword" => "dentist", "volume" => 5400, "cpc" => 9.12, "difficulty" => 41, "intent" => "commercial",
                                                         "position" => 4, "url" => "https://acme.example/", "traffic" => 210.4 } ] }, api.keywords("acme.example"))
        ranking = api.ranking("dentist", location: "Grand Rapids,Michigan,United States")
        assert_equal [ "rival.example", "acme.example" ], ranking["results"].map { it["domain"] }
        assert_equal %w[local_pack people_also_ask], ranking["features"]
        assert_equal "Grand Rapids,Michigan,United States", @transport.calls.last.last.first[:location_name]
        assert_equal "United States", @transport.calls.first.last.first[:location_name]
      end
    end
  end
end
