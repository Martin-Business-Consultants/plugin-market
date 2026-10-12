module Market
  # Each client's market: the list of clients with what's known about theirs, and one client's
  # page (profile, competitors side by side, the plan and its opportunities).
  class ProfilesController < ApplicationController
    SHOW = %w[active all gaps].freeze

    allow_staff only: %i[index show]
    require_permission :manage_market, except: %i[index show]
    agent_tool :list_market_clients, on: :index, title: "List clients' markets",
      description: "Clients with their industry, website, how many competitors are watched, open opportunities and when the plan was last drafted. show: active (the default), all, or gaps (no profile, industry or competitors yet). industry_id: one industry's.",
      params: { show: SHOW, industry_id: "integer" }, next_tools: %i[show_client_market]
    agent_tool :show_client_market, on: :show, title: "Show a client's market",
      description: "A client's market profile (industry, website, service area, offerings, audience, positioning, goals) and what's missing from it, their website's latest reading, each competitor with how it competes, its latest reading and recent changes, the latest plan (summary, positioning, suggestions) and the opportunities, best first.",
      next_tools: %i[update_client_market_profile create_competitor plan_market_with_ai plan_market_opportunity_as_work]
    agent_tool :update_client_market_profile, on: :update, title: "Change a client's market profile",
      description: "Any of: industry_name (the industry, made if new; \"\" clears it), website, service_area, offerings, audience, positioning, goals, notes. A new website is read in the background.",
      params: { profile: { industry_name: "string", website: "string", service_area: "text", offerings: "text", audience: "text", positioning: "text", goals: "text", notes: "text" } },
      next_tools: %i[show_client_market]

    before_action :set_client, only: %i[show edit update]

    def index
      @show = params[:show].presence_in(SHOW) || "active"
      @industry = Industry.find(params[:industry_id]) if params[:industry_id].present?
      clients = @show == "all" ? Client.ordered : Client.active.ordered
      @profiles = Profile.where(client: clients).includes(:industry).index_by(&:client_id)
      clients = clients.where(id: Profile.where(industry: @industry).select(:client_id)) if @industry
      @rivals = Rivalry.where(client: clients).group(:client_id).count
      @open = Opportunity.open.where(client: clients).group(:client_id).count
      @planned_at = Plan.where(client: clients, state: "ready").group(:client_id).maximum(:finished_at)
      @clients = clients.to_a
      @clients = @clients.select { gap?(it) } if @show == "gaps"
    end

    def show
      @profile = Profile.for(@client)
      @rivalries = @client.market_rivalries.includes(competitor: :industry).by_threat.to_a
      @readings = Snapshot.latest_for(@rivalries.map(&:competitor))
      @own = @profile.persisted? ? @profile.latest_snapshot : nil
      @plan = @client.market_plans.latest_first.first
      @opportunities = Opportunity.by_priority(@client.market_opportunities.includes(:client, :todo).to_a)
      @others = Competitor.ordered.where.not(id: @rivalries.map(&:competitor_id)).pluck(:name, :id)
    end

    def edit
      @profile = Profile.for(@client)
    end

    def update
      @profile = Profile.for(@client)
      was = @profile.domain
      if @profile.revise(profile_params)
        @profile.check_later if @profile.domain.present? && @profile.domain != was
        redirect_to market_client_path(@client), notice: "#{@client.name}'s market saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private
      def profile_params = params.expect(profile: %i[industry_name website service_area offerings audience positioning goals notes])

      def gap?(client)
        profile = @profiles[client.id]
        profile.nil? || profile.industry_id.nil? || @rivals[client.id].to_i.zero?
      end
  end
end
