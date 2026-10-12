module Market
  # Competitors, each watched once however many clients it competes with: its website's
  # readings and what changed in them, and how it competes with each client.
  class CompetitorsController < ApplicationController
    allow_staff only: %i[index show]
    require_permission :manage_market, except: %i[index show]
    agent_tool :list_competitors, on: :index, title: "List competitors",
      description: "Every competitor watched, with its website, industry, the clients it competes with, the tools its site runs (ads, analytics, call tracking, chat, reviews, booking) and its page and post counts from the latest reading. industry_id or client_id narrows it; q searches names and websites.",
      params: { industry_id: "integer", client_id: "integer", q: "string" }, next_tools: %i[show_competitor create_competitor]
    agent_tool :show_competitor, on: :show, title: "Show a competitor",
      description: "A competitor: its website's latest reading in full (home page title, headings, platform, tools, socials, structured data; sitemap pages, posts, locations, services, last changed), every change seen between readings, and how it competes with each client.",
      next_tools: %i[check_competitor_website update_competitor link_market_competitor]
    agent_tool :create_competitor, on: :create, title: "Add a competitor",
      description: "A competitor, its website read in the background. With client_id it's added to that client (kind: direct, indirect, aspirational; threat: high, medium, low). A website already watched answers with that competitor instead: link it with link_market_competitor.",
      params: { competitor: { name: "string!", website: "string", industry_id: "integer", strengths: "text", weaknesses: "text", notes: "text",
                              client_id: "integer", kind: Rivalry::KINDS.keys, threat: Rivalry::THREATS } },
      next_tools: %i[show_competitor show_client_market]
    agent_tool :update_competitor, on: :update, title: "Change a competitor",
      description: "Its name, website, industry, strengths, weaknesses or notes. A new website is read in the background.",
      params: { competitor: { name: "string", website: "string", industry_id: "integer", strengths: "text", weaknesses: "text", notes: "text" } }
    agent_tool :delete_competitor, on: :destroy, title: "Delete a competitor",
      description: "Stops watching it, for every client, and forgets its readings."

    before_action :set_competitor, only: %i[show edit update destroy]

    def index
      @industry = Industry.find(params[:industry_id]) if params[:industry_id].present?
      @client = Client.find(params[:client_id]) if params[:client_id].present?
      competitors = Competitor.ordered.includes(:industry, :clients)
      competitors = competitors.where(industry: @industry) if @industry
      competitors = competitors.where(id: Rivalry.where(client: @client).select(:competitor_id)) if @client
      if (@q = params[:q].to_s.strip.presence)
        competitors = competitors.where("market_competitors.name LIKE :q OR market_competitors.domain LIKE :q", q: "%#{Competitor.sanitize_sql_like(@q.downcase)}%")
      end
      @competitors = competitors.to_a
      @readings = Snapshot.latest_for(@competitors)
    end

    def show
      @snapshots = @competitor.snapshots.to_a
      @rivalries = @competitor.rivalries.includes(:client).by_threat.to_a
    end

    def new
      @competitor = Competitor.new(industry_id: params[:industry_id] || Profile.find_by(client_id: params[:client_id])&.industry_id)
      @client = Client.find_by(id: params[:client_id])
    end

    def create
      attributes = params.expect(competitor: %i[name website industry_id strengths weaknesses notes client_id kind threat])
      @client = Client.find_by(id: attributes.delete(:client_id))
      rivalry = attributes.extract!(:kind, :threat).compact_blank
      existing = Competitor.matching(name: attributes[:name], website: attributes[:website])
      @competitor = existing || Competitor.new(attributes)

      if existing || @competitor.save
        @competitor.check_later if @competitor.domain.present? && @competitor.snapshots.none?
        if @client
          link = @competitor.rivalries.find_or_initialize_by(client: @client)
          link.update!(rivalry) if link.new_record? || rivalry.any?
          redirect_to market_client_path(@client), notice: existing ? "#{@competitor.name} was already watched: now one of #{@client.name}'s competitors." : "#{@competitor.name} added to #{@client.name}'s competitors; reading its website."
        else
          redirect_to market_competitor_path(@competitor), notice: existing ? "#{@competitor.name} is already watched." : "#{@competitor.name} added; reading its website."
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      was = @competitor.domain
      if @competitor.update(params.expect(competitor: %i[name website industry_id strengths weaknesses notes]))
        @competitor.check_later if @competitor.domain.present? && @competitor.domain != was
        redirect_to market_competitor_path(@competitor), notice: "#{@competitor.name} saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @competitor.destroy!
      redirect_to market_competitors_path, notice: "#{@competitor.name} deleted, for every client."
    end

    private
      def set_competitor = @competitor = Competitor.find(params[:id])
  end
end
