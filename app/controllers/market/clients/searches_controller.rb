module Market
  module Clients
    # A client's search data, for agents and harnesses: every site's visibility (latest and the
    # pull before), the keywords each ranks for, the sites that share the client's keywords,
    # and where everyone ranks for the tracked keywords. The client's page shows the same.
    class SearchesController < ApplicationController
      allow_staff
      agent_tool :show_market_search, on: :show, title: "Show a client's search data",
        description: "From the latest DataForSEO pulls: for the client and each competitor, visibility now and at the pull before (organic keywords, estimated monthly traffic, keywords in the top 3, 10 and 20, paid keywords), backlinks if pulled, and up to `keywords` (default 50, max 500) of the keywords each ranks for, by search volume; the sites that share the client's keywords; and each tracked keyword with the client's position and each competitor's, now and before.",
        params: { keywords: "integer" }, next_tools: %i[list_market_findings track_market_keywords pull_market_search]

      before_action :set_client

      def show
        @limit = params[:keywords].to_i.clamp(0, 500).nonzero? || 50
        @data = Search::Overview.new(@client)
      end
    end
  end
end
