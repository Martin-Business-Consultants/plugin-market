module Market
  # A client's plans, drafted by the install's AI from what's known about their market.
  class PlansController < ApplicationController
    allow_staff only: :index
    require_permission :manage_market, only: :create
    agent_tool :show_market_plan, on: :index, title: "Show a client's market plan",
      description: "The latest plan for a client: whether it's still drafting, its summary of the market, the angle to win on, the industry and competitors it suggests checking, and the opportunities it added. Earlier plans are listed by date.",
      next_tools: %i[show_client_market plan_market_opportunity_as_work update_client_market_profile create_competitor]
    agent_tool :plan_market_with_ai, on: :create, title: "Draft a client's market plan with AI",
      description: "Has the install's AI draft the big picture for this client from their profile, their website's and competitors' latest readings and what's already planned: a summary, the angle to win on, an industry and competitors to check, and opportunities by channel, impact, effort and when, added to the client's list. In the background, a minute or so; needs the AI plugin on. Fill in the profile and competitors first: it plans from what's known.",
      next_tools: %i[show_market_plan]

    before_action :set_client

    def index
      @plans = @client.market_plans.latest_first.includes(:user, :opportunities).to_a
      @plan = @plans.first
    end

    def create
      return redirect_to(market_client_path(@client), alert: "Plans need the AI plugin on, set up and within its budget, and #{@client.name} not kept out of AI.") unless Plan.ai_available_for?(@client)
      return redirect_to(market_client_path(@client), alert: "A plan for #{@client.name} is already being drafted.") if @client.market_plans.any? { it.working? }

      plan = @client.market_plans.create!(user: Current.user)
      plan.run_later
      redirect_to market_client_path(@client, anchor: "plan"), notice: "Drafting #{@client.name}'s plan: a minute or so."
    end
  end
end
