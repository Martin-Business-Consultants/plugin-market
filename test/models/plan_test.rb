require_relative "../test_helper"

module Market
  class PlanTest < ActiveSupport::TestCase
    setup do
      @client = clients(:acme)
      Profile.for(@client).revise(industry_name: "Plumbing", website: "https://acme.example", service_area: "Springfield")
      @rival = Competitor.create!(name: "Rival", website: "https://rival.example")
      Rivalry.create!(client: @client, competitor: @rival, threat: "high")
      read(@rival, locations: 15)
      @client.market_opportunities.create!(title: "Claim the Google Business Profile", channel: "local")
      @plan = @client.market_plans.create!(user: users(:ted))
    end

    def answer
      { "summary" => "Rival owns the towns around Springfield.", "positioning" => "The plumber who shows up the same day.",
        "industry" => { "name" => "Residential plumbing", "naics_code" => "238220", "why" => "Homes, not sites" },
        "competitors_to_check" => [ { "name" => "Rival", "website" => "rival.example", "why" => "Already listed" },
                                    { "name" => "Drain Kings", "website" => "drainkings.example", "why" => "Ranks for drains" } ],
        "opportunities" => [
          { "channel" => "local", "title" => "Publish a page for each town served", "detail" => "One per town.", "evidence" => "Rival has 15 location pages",
            "impact" => "high", "effort" => "medium", "horizon" => "now" },
          { "channel" => "local", "title" => "claim the google business profile", "detail" => "", "evidence" => "", "impact" => "high", "effort" => "low", "horizon" => "now" },
          { "channel" => "nonsense", "title" => "Start a newsletter", "detail" => "", "evidence" => "", "impact" => "huge", "effort" => "low", "horizon" => "later" }
        ] }
    end

    test "a plan is drafted from the brief, adding new opportunities and suggestions to check" do
      prompt = nil
      with_ai(->(request) { prompt = request[:prompt]; answer }) { @plan.run! }

      assert @plan.reload.ready?
      assert_includes prompt, "Rival (direct, high threat)"
      assert_includes prompt, "\"locations\":15"
      assert_includes prompt, "Claim the Google Business Profile"
      assert_equal "Rival owns the towns around Springfield.", @plan.summary
      assert_equal [ "Publish a page for each town served", "Start a newsletter" ], @plan.opportunities.order(:id).map(&:title)
      newsletter = @plan.opportunities.find_by!(title: "Start a newsletter")
      assert_equal [ "seo", "medium" ], [ newsletter.channel, newsletter.impact ]

      assert_equal [ "Drain Kings" ], @plan.new_competitor_suggestions.map { it["name"] }
      assert_equal "https://drainkings.example", @plan.new_competitor_suggestions.first["website"]
      assert @plan.industry_suggestion_new?
    end

    test "a plan that fails keeps why and changes nothing" do
      with_ai(->(_) { raise "model overloaded" }) { @plan.run! }

      assert @plan.reload.failed?
      assert_match "model overloaded", @plan.error
      assert_equal 1, @client.market_opportunities.count
    end

    test "no AI plugin, no plans" do
      assert_not Plan.ai_available_for?(@client) unless defined?(::Ai)
      with_ai({}) { assert Plan.ai_available_for?(@client) }
    end
  end
end
