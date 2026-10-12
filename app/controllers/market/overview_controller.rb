module Market
  # The big picture across every client: industries and who's in them, the best opportunities
  # still open, what competitors changed lately, and the clients whose market isn't known yet.
  class OverviewController < ApplicationController
    allow_staff
    agent_tool :show_market, on: :show, title: "Show the market overview",
      description: "Every industry with its clients and competitors, the best open opportunities across clients (most impact for least effort first), what competitors' websites changed in the last 30 days, and the active clients with no market profile or industry yet.",
      next_tools: %i[show_client_market list_market_opportunities show_industry]

    def show
      @industries = Industry.ordered.to_a
      @clients_by_industry = Profile.where.not(industry_id: nil).group(:industry_id).count
      @competitors_by_industry = Competitor.where.not(industry_id: nil).group(:industry_id).count
      profiles = Profile.where(client: Client.active).to_a
      @unprofiled = Client.active.ordered.where.not(id: profiles.select(&:industry_id).map(&:client_id)).to_a
      open = Opportunity.open.where(client: Client.active).includes(:client).to_a
      @open_count = open.size
      @quick_wins = open.count(&:quick_win?)
      @opportunities = Opportunity.by_priority(open).first(10)
      @changes = Snapshot.with_changes.where(subject_type: Competitor.polymorphic_name, taken_at: 30.days.ago..).latest_first.limit(12).includes(:subject).to_a
      @competitor_count = Competitor.count
      @findings = Finding.open.where(client: Client.active).where(severity: %w[high medium]).includes(:client).by_severity.limit(8).to_a
    end
  end
end
