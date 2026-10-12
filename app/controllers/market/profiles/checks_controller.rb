module Market
  module Profiles
    # Reads a client's own website again now, in the background.
    class ChecksController < ApplicationController
      require_permission :manage_market
      agent_tool :check_client_website, on: :create, title: "Read a client's website again",
        description: "Reads the client's own website (from their market profile) in the background, a few seconds: its pages, posts, locations and the tools it runs, to compare with competitors'. Websites are read weekly anyway."

      before_action :set_client

      def create
        profile = @client.market_profile
        return redirect_to(market_client_path(@client), alert: "Add #{@client.name}'s website to their market profile first.") unless profile&.domain

        profile.check_later
        redirect_to market_client_path(@client), notice: "Reading #{profile.domain}: refresh in a few seconds."
      end
    end
  end
end
