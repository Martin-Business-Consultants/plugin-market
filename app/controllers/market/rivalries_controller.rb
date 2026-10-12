module Market
  # A competitor of one client: added from those already watched, changed, or taken off.
  class RivalriesController < ApplicationController
    require_permission :manage_market
    agent_tool :link_market_competitor, on: :create, title: "Add a watched competitor to a client",
      description: "Makes a competitor already watched (competitor_id) one of this client's. kind: direct, indirect, aspirational; threat: high, medium, low.",
      params: { rivalry: { competitor_id: "integer!", kind: Rivalry::KINDS.keys, threat: Rivalry::THREATS, notes: "text" } }, next_tools: %i[show_client_market]
    agent_tool :update_market_rivalry, on: :update, title: "Change how a competitor competes with a client",
      params: { rivalry: { kind: Rivalry::KINDS.keys, threat: Rivalry::THREATS, notes: "text" } }
    agent_tool :unlink_market_competitor, on: :destroy, title: "Take a competitor off a client",
      description: "It stays watched, for any other client and on its own."

    before_action :set_client
    after_action -> { Finding.refresh_later(@client) }, if: -> { response.redirect? }

    def create
      rivalry = @client.market_rivalries.new(params.expect(rivalry: %i[competitor_id kind threat notes]))
      if rivalry.save
        redirect_to market_client_path(@client), notice: "#{rivalry.competitor.name} is now one of #{@client.name}'s competitors."
      else
        redirect_to market_client_path(@client), alert: rivalry.errors.full_messages.to_sentence
      end
    end

    def update
      rivalry = @client.market_rivalries.find(params[:id])
      if rivalry.update(params.expect(rivalry: %i[kind threat notes]))
        redirect_to market_client_path(@client), notice: "#{rivalry.competitor.name} saved."
      else
        redirect_to market_client_path(@client), alert: rivalry.errors.full_messages.to_sentence
      end
    end

    def destroy
      rivalry = @client.market_rivalries.find(params[:id])
      rivalry.destroy!
      redirect_to market_client_path(@client), notice: "#{rivalry.competitor.name} is no longer one of #{@client.name}'s competitors."
    end
  end
end
