require_relative "../test_helper"

module Market
  # What people do: fill in a market, add competitors, plan, and work the opportunities.
  class FlowsTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    setup do
      ::Setting.current.toggle_plugin!(:market, enabled: true)
      @client = clients(:acme)
      sign_in_as users(:sarah)
    end

    test "a profile saved with a new industry and website, read in the background" do
      assert_enqueued_with(job: CheckJob) do
        patch market_client_path(@client), params: { profile: { industry_name: "Residential plumbing", website: "https://acme.example", audience: "Homeowners" } }
      end
      assert_redirected_to market_client_path(@client)
      profile = @client.reload.market_profile
      assert_equal [ "Residential plumbing", "acme.example", "Homeowners" ], [ profile.industry.name, profile.domain, profile.audience ]

      get edit_market_client_path(@client)
      assert_response :success
      patch market_client_path(@client), params: { profile: { website: "not a url" } }
      assert_response :unprocessable_entity
    end

    test "a competitor added to a client, and the same website again links the one already watched" do
      assert_enqueued_with(job: CheckJob) do
        post market_competitors_path, params: { competitor: { name: "Rival", website: "https://rival.example", client_id: @client.id, kind: "direct", threat: "high" } }
      end
      assert_redirected_to market_client_path(@client)
      rival = Competitor.find_by!(name: "Rival")
      assert_equal [ "direct", "high" ], rival.rivalries.first.values_at(:kind, :threat)

      post market_competitors_path, params: { competitor: { name: "Rival Plumbing Co", website: "https://www.rival.example/", client_id: clients(:globex).id } }
      assert_equal 1, Competitor.count
      assert_equal [ @client, clients(:globex) ].map(&:id).sort, rival.reload.rivalries.map(&:client_id).sort

      get new_market_competitor_path(client_id: @client.id)
      assert_response :success
      post market_competitors_path, params: { competitor: { name: "" } }
      assert_response :unprocessable_entity
    end

    test "rivalries changed and taken off; the competitor stays" do
      rival = Competitor.create!(name: "Rival")
      post market_client_rivalries_path(@client), params: { rivalry: { competitor_id: rival.id, kind: "aspirational", threat: "low" } }
      rivalry = @client.market_rivalries.first
      assert_equal "aspirational", rivalry.kind

      post market_client_rivalries_path(@client), params: { rivalry: { competitor_id: rival.id } }
      assert_match "already one of theirs", flash[:alert]

      patch market_client_rivalry_path(@client, rivalry), params: { rivalry: { threat: "high", notes: "Took two jobs from us" } }
      assert_equal "high", rivalry.reload.threat

      delete market_client_rivalry_path(@client, rivalry)
      assert_not Rivalry.exists?(rivalry.id)
      assert Competitor.exists?(rival.id)
    end

    test "websites read again on demand" do
      rival = Competitor.create!(name: "Rival", website: "https://rival.example")
      assert_enqueued_with(job: CheckJob, args: [ rival ]) { post market_competitor_check_path(rival) }
      post market_client_check_path(@client)
      assert_match "website", flash[:alert]
    end

    test "a plan needs the AI plugin, then drafts in the background" do
      post market_client_plans_path(@client)
      assert_match "AI plugin", flash[:alert] unless defined?(::Ai)

      with_ai({}) do
        assert_enqueued_with(job: PlanJob) { post market_client_plans_path(@client) }
        assert_redirected_to market_client_path(@client, anchor: "plan")
        assert_equal 1, @client.market_plans.count

        post market_client_plans_path(@client)
        assert_match "already being drafted", flash[:alert]

        get market_client_path(@client)
        assert_select "[data-controller='poll']"
      end
    end

    test "a drafted plan's suggestions can be taken in one click" do
      plan = @client.market_plans.create!(user: users(:ted), state: "ready", summary: "The towns are open.", positioning: "Same-day.",
        industry_suggestion: { "name" => "Residential plumbing" }, competitor_suggestions: [ { "name" => "Drain Kings", "website" => "https://drainkings.example" } ])

      with_ai({}) do
        get market_client_path(@client)
        assert_includes response.body, "The towns are open."
        assert_includes response.body, "Drain Kings"
        get market_client_plans_path(@client)
        assert_response :success
      end

      patch market_client_path(@client), params: { profile: { industry_name: "Residential plumbing" } }
      post market_competitors_path, params: { competitor: { name: "Drain Kings", website: "https://drainkings.example", client_id: @client.id } }
      assert_not plan.reload.industry_suggestion_new?
      assert_empty plan.new_competitor_suggestions
    end

    test "opportunities: added, planned as work, done, opened again, deleted" do
      post market_client_opportunities_path(@client), params: { opportunity: { title: "Ask every customer for a review", channel: "reviews", impact: "high", effort: "low", horizon: "now" } }
      opportunity = @client.market_opportunities.find_by!(title: "Ask every customer for a review")

      post market_opportunity_todo_path(opportunity), params: { todo: { engagement_id: engagements(:retainer).id, owner_id: users(:sarah).id } }
      todo = opportunity.reload.todo
      assert_equal [ "planned", "Ask every customer for a review", engagements(:retainer) ], [ opportunity.state, todo.title, todo.engagement ]
      assert_includes todo.description.to_s, market_client_url(@client, anchor: "opportunities")

      post market_opportunity_todo_path(opportunity), params: { todo: { engagement_id: engagements(:globex_site).id } }
      assert_match "open", flash[:alert]

      patch market_opportunity_path(opportunity), params: { opportunity: { state: "done" } }
      assert_equal "done", opportunity.reload.state
      patch market_opportunity_path(opportunity), params: { opportunity: { state: "open" } }
      assert_equal "planned", opportunity.reload.state

      delete market_opportunity_path(opportunity)
      assert_not Opportunity.exists?(opportunity.id)
    end

    test "industries added, changed and deleted; their clients stay" do
      post market_industries_path, params: { industry: { name: "HVAC", naics_code: "238220" } }
      industry = Industry.find_by!(name: "HVAC")
      assert_redirected_to market_industry_path(industry)
      Profile.for(@client).revise(industry_name: "HVAC")

      get edit_market_industry_path(industry)
      assert_response :success
      patch market_industry_path(industry), params: { industry: { naics_code: "12345678" } }
      assert_response :unprocessable_entity

      delete market_industry_path(industry)
      assert_nil @client.market_profile.reload.industry
    end

    test "members read and mark opportunities done, but change nothing else" do
      member = User.create!(email_address: "member@example.com", name: "Mo Member", role: "member", password: "password")
      opportunity = @client.market_opportunities.create!(title: "Post monthly", channel: "content")
      sign_in_as member

      get market_client_path(@client)
      assert_response :success
      assert_select "a[href='#{edit_market_client_path(@client)}']", 0

      patch market_opportunity_path(opportunity), params: { opportunity: { state: "done" } }
      assert_equal "done", opportunity.reload.state
      patch market_opportunity_path(opportunity), params: { opportunity: { title: "Changed" } }
      assert_response :forbidden

      patch market_client_path(@client), params: { profile: { goals: "Nope" } }
      assert_nil @client.market_profile
      delete market_opportunity_path(opportunity)
      assert Opportunity.exists?(opportunity.id)
    end

    test "the nightly run reads what hasn't been read this week" do
      fresh = Competitor.create!(name: "Fresh", website: "https://fresh.example")
      read(fresh)
      stale = Competitor.create!(name: "Stale", website: "https://stale.example")
      Competitor.create!(name: "No site")

      assert_enqueued_jobs 1, only: CheckJob do
        WeeklyCheckJob.perform_now
      end
      assert_enqueued_with(job: CheckJob, args: [ stale ])
    end
  end
end
