module Market
  # Opportunities across every client (the portfolio's to-do list for winning markets), and the
  # verbs on one: add, change, mark done or dismissed, open again, delete.
  class OpportunitiesController < ApplicationController
    STATES = %w[open planned done dismissed active all].freeze

    allow_staff only: %i[index update]
    require_permission :manage_market, only: %i[create destroy]
    agent_tool :list_market_opportunities, on: :index, title: "List market opportunities",
      description: "Opportunities across clients, best first (most impact for least effort, then soonest). state: open (the default), planned, done, dismissed, active (open or planned) or all. Narrow by client_id, industry_id, channel or horizon (now: this month, next: this quarter, later).",
      params: { state: STATES, client_id: "integer", industry_id: "integer", channel: Opportunity::CHANNELS.keys, horizon: Opportunity::HORIZONS.keys },
      next_tools: %i[plan_market_opportunity_as_work update_market_opportunity show_client_market]
    agent_tool :add_market_opportunity, on: :create, title: "Add a market opportunity",
      description: "Something worth doing to win this client's market. evidence: what shows it's worth doing.",
      params: { opportunity: { title: "string!", channel: Opportunity::CHANNELS.keys, detail: "text", evidence: "text",
                               impact: Opportunity::IMPACTS, effort: Opportunity::EFFORTS, horizon: Opportunity::HORIZONS.keys } },
      next_tools: %i[show_client_market plan_market_opportunity_as_work]
    agent_tool :update_market_opportunity, on: :update, title: "Change a market opportunity",
      description: "state: done, dismissed, or open (again); or its title, channel, detail, evidence, impact, effort, horizon.",
      params: { opportunity: { state: %w[open done dismissed], title: "string", channel: Opportunity::CHANNELS.keys, detail: "text", evidence: "text",
                               impact: Opportunity::IMPACTS, effort: Opportunity::EFFORTS, horizon: Opportunity::HORIZONS.keys } }
    agent_tool :delete_market_opportunity, on: :destroy, title: "Delete a market opportunity"

    def index
      @state = params[:state].presence_in(STATES) || "open"
      @client = Client.find(params[:client_id]) if params[:client_id].present?
      @industry = Industry.find(params[:industry_id]) if params[:industry_id].present?
      @channel = params[:channel].presence_in(Opportunity::CHANNELS.keys)
      @horizon = params[:horizon].presence_in(Opportunity::HORIZONS.keys)
      scope = Opportunity.includes(:client, :todo)
      scope = scope.where(client: @client) if @client
      scope = scope.where(client_id: Profile.where(industry: @industry).select(:client_id)) if @industry
      scope = scope.where(channel: @channel) if @channel
      scope = scope.where(horizon: @horizon) if @horizon
      @counts = scope.group(:state).count
      scope = scope.where(state: @state == "active" ? Opportunity::ACTIVE : @state) unless @state == "all"
      @opportunities = Opportunity.by_priority(scope.to_a)
      @engagements = Engagement.open.where(client_id: @opportunities.map(&:client_id).uniq).order(created_at: :desc).group_by(&:client_id)
      @people = User.active.people.ordered.to_a
    end

    def create
      client = Client.find(params[:client_id])
      opportunity = client.market_opportunities.new(params.expect(opportunity: %i[title channel detail evidence impact effort horizon]))
      if opportunity.save
        redirect_to market_client_path(client, anchor: "opportunities"), notice: "Added “#{opportunity.title}”."
      else
        redirect_to market_client_path(client, anchor: "opportunities"), alert: opportunity.errors.full_messages.to_sentence
      end
    end

    def update
      opportunity = Opportunity.find(params[:id])
      attributes = params.expect(opportunity: %i[state title channel detail evidence impact effort horizon])
      return head(:forbidden) if attributes.except(:state).present? && !Current.user.can?(:manage_market)

      saved = case attributes.delete(:state)
      when "done" then opportunity.complete(by: Current.user)
      when "dismissed" then opportunity.dismiss(by: Current.user)
      when "open" then opportunity.reopen
      else true
      end
      saved &&= opportunity.update(attributes) if attributes.present?
      redirect_back_or_to market_client_path(opportunity.client, anchor: "opportunities"),
        **(saved ? { notice: "“#{opportunity.title}” #{opportunity.state == "open" ? "saved" : "marked #{opportunity.state}"}." } : { alert: opportunity.errors.full_messages.to_sentence })
    end

    def destroy
      opportunity = Opportunity.find(params[:id])
      opportunity.destroy!
      redirect_back_or_to market_client_path(opportunity.client, anchor: "opportunities"), notice: "Deleted “#{opportunity.title}”."
    end
  end
end
