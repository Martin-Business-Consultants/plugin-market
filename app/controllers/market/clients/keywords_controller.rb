module Market
  module Clients
    # The searches tracked for a client: added (one a line), and taken off.
    class KeywordsController < ApplicationController
      require_permission :manage_market
      agent_tool :track_market_keywords, on: :create, title: "Track searches for a client",
        description: "Keywords to track for a client, one a line or comma-separated (\"emergency dentist grand rapids\"), each checked from the client's search location on every search pull: where they rank and where each competitor does. Up to #{Keyword::MAX_PER_CLIENT} a client. source: manual (the default), gap (from a keyword gap), plan (an AI plan's suggestion) or ranked (one they already rank for).",
        params: { keyword: { keywords: "text!", source: Keyword::SOURCES } }, next_tools: %i[pull_market_search show_market_search]
      agent_tool :untrack_market_keyword, on: :destroy, title: "Stop tracking a search", description: "Forgets the keyword and its ranking history."

      before_action :set_client

      def create
        attributes = params.expect(keyword: %i[keywords source])
        added, skipped = Keyword.track(@client, attributes[:keywords], source: attributes[:source].presence_in(Keyword::SOURCES) || "manual")
        message = added.any? ? "Tracking #{added.map { "“#{it.keyword}”" }.to_sentence}." : "Nothing new to track."
        message += " #{skipped} already tracked or over the limit." if skipped.positive?
        redirect_to market_client_path(@client, anchor: "search"), (added.any? ? :notice : :alert) => message
      end

      def destroy
        keyword = Keyword.where(client: @client).find(params[:id])
        keyword.destroy!
        redirect_to market_client_path(@client, anchor: "search"), notice: "Stopped tracking “#{keyword.keyword}”."
      end
    end
  end
end
