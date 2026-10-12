require_relative "../test_helper"

module Market
  class OpportunityTest < ActiveSupport::TestCase
    setup { @client = clients(:acme) }

    def opportunity(title, **attributes) = @client.market_opportunities.create!(title: title, channel: "seo", **attributes)

    test "best first: most impact for least effort, then soonest" do
      slow = opportunity("Slow", impact: "high", effort: "high")
      quick = opportunity("Quick", impact: "high", effort: "low")
      later = opportunity("Later", impact: "high", effort: "low", horizon: "later")
      small = opportunity("Small", impact: "low", effort: "low")

      assert_equal [ quick, later, slow, small ], Opportunity.by_priority([ small, slow, later, quick ])
      assert quick.quick_win?
      assert_not small.quick_win?
    end

    test "planned as work: a todo on the engagement, linking back" do
      item = opportunity("Publish town pages", detail: "One per town.", evidence: "Rival has 15")
      todo = item.plan_as_work(engagement: engagements(:retainer), by: users(:ted), link: "<a href=\"/market\">Acme's market</a>", owner_id: users(:sarah).id)

      assert todo.persisted?
      assert_equal "Publish town pages", todo.title
      assert_equal users(:sarah), todo.owner
      assert_includes todo.description.to_s, "One per town."
      assert_includes todo.description.to_s, "Acme's market"
      assert_equal [ "planned", todo ], [ item.reload.state, item.todo ]
      assert Event.exists?(kind: "todo.created", subject: todo)
    end

    test "done, dismissed, and open again" do
      item = opportunity("Ask for reviews")
      item.complete(by: users(:ted))
      assert_equal [ "done", users(:ted).display_name ], [ item.state, item.decided_by_name ]
      item.dismiss(by: users(:ted))
      assert_equal "dismissed", item.state
      item.reopen
      assert_equal [ "open", nil ], [ item.state, item.decided_at ]
    end
  end
end
