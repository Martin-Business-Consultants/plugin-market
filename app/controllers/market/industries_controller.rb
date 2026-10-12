module Market
  # Industries: the clients in each and the competitors they share, to see a market whole and
  # plan what worked for one client for the others.
  class IndustriesController < ApplicationController
    allow_staff only: %i[index show]
    require_permission :manage_market, except: %i[index show]
    agent_tool :list_industries, on: :index, title: "List industries",
      description: "Every industry with its NAICS code, how many clients and competitors are in it, and its open opportunities.",
      next_tools: %i[show_industry create_industry]
    agent_tool :show_industry, on: :show, title: "Show an industry",
      description: "An industry's clients (with competitors and open opportunities), its competitors (with whom they compete and their latest readings), and the opportunities open across its clients by channel: what works in this market.",
      next_tools: %i[show_client_market show_competitor]
    agent_tool :create_industry, on: :create, title: "Add an industry",
      description: "An industry to group clients and competitors by. naics_code: 2 to 6 digits, optional.",
      params: { industry: { name: "string!", naics_code: "string", description: "text", notes: "text" } }, next_tools: %i[show_industry]
    agent_tool :update_industry, on: :update, title: "Change an industry",
      params: { industry: { name: "string", naics_code: "string", description: "text", notes: "text" } }
    agent_tool :delete_industry, on: :destroy, title: "Delete an industry",
      description: "Forgets the industry; its clients and competitors stay, with no industry."

    before_action :set_industry, only: %i[show edit update destroy]

    def index
      @industries = Industry.ordered.to_a
      @clients = Profile.where.not(industry_id: nil).group(:industry_id).count
      @competitors = Competitor.where.not(industry_id: nil).group(:industry_id).count
      @open = Opportunity.open.joins("JOIN market_profiles ON market_profiles.client_id = market_opportunities.client_id")
                         .group("market_profiles.industry_id").count
    end

    def show
      @clients = @industry.clients.to_a
      @rivals = Rivalry.where(client: @clients).group(:client_id).count
      @competitors = @industry.competitors.ordered.includes(:clients).to_a
      @readings = Snapshot.latest_for(@competitors)
      open = Opportunity.open.where(client: @clients).includes(:client).to_a
      @open = open.group_by(&:client_id).transform_values(&:size)
      @channels = open.group_by(&:channel).sort_by { -it.last.size }
    end

    def new
      @industry = Industry.new
    end

    def create
      @industry = Industry.new(industry_params)
      if @industry.save
        redirect_to market_industry_path(@industry), notice: "#{@industry.name} added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @industry.update(industry_params)
        redirect_to market_industry_path(@industry), notice: "#{@industry.name} saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @industry.destroy!
      redirect_to market_industries_path, notice: "#{@industry.name} deleted; its clients and competitors stay."
    end

    private
      def set_industry = @industry = Industry.find(params[:id])
      def industry_params = params.expect(industry: %i[name naics_code description notes])
  end
end
