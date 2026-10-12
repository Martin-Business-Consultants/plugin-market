module Market
  module Competitors
    # Reads a competitor's website again now, in the background.
    class ChecksController < ApplicationController
      require_permission :manage_market
      agent_tool :check_competitor_website, on: :create, title: "Read a competitor's website again",
        description: "Reads the competitor's website in the background (a few seconds) and records what changed since the last reading. Websites are read weekly anyway."

      def create
        competitor = Competitor.find(params[:competitor_id])
        return redirect_to(market_competitor_path(competitor), alert: "Add #{competitor.name}'s website first.") unless competitor.domain

        competitor.check_later
        redirect_to market_competitor_path(competitor), notice: "Reading #{competitor.domain}: refresh in a few seconds."
      end
    end
  end
end
