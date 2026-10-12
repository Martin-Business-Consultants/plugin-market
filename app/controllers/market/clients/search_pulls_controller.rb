module Market
  module Clients
    # A client's search pulls: the history, and a new one, which spends from the month's budget.
    class SearchPullsController < ApplicationController
      allow_staff only: :index
      require_permission :manage_market, only: :create
      agent_tool :list_market_search_pulls, on: :index, title: "List a client's search pulls",
        description: "Every pull of a client's search data from DataForSEO, latest first: when, by whom, its state (ready, partial, stopped, failed, or still running), what it cost and its notes (what was kept as fresh, what couldn't be got and why).",
        next_tools: %i[show_market_search pull_market_search]
      agent_tool :pull_market_search, on: :create, title: "Pull a client's search data",
        description: "Spends from the month's DataForSEO budget (Settings › Market) to get, for the client's site and each competitor's: visibility and estimated traffic, the keywords each ranks for, backlinks if switched on; the sites that share the client's keywords; and where everyone ranks for the client's tracked keywords, searched from their search location. In the background, a minute or two. Parts pulled in the last day are kept rather than bought again unless force is true. The findings are worked out again at the end.",
        params: { pull: { force: "boolean" } }, next_tools: %i[list_market_search_pulls show_market_search list_market_findings]

      before_action :set_client

      def index
        @pulls = SearchPull.where(client: @client).latest_first.includes(:user).limit(30).to_a
      end

      def create
        setting = Setting.current
        back = market_client_path(@client, anchor: "search")
        return redirect_to(back, alert: "Connect DataForSEO in Settings › Market first.") unless setting.search_connected?
        return redirect_to(back, alert: "Add #{@client.name}'s website to their market profile first.") unless Profile.find_by(client: @client)&.domain
        return redirect_to(back, alert: "A pull for #{@client.name} is already running.") if SearchPull.where(client: @client, state: %w[queued running]).any?(&:working?)
        return redirect_to(back, alert: "This month's search budget is spent: raise it in Settings › Market.") unless setting.remaining_budget.positive?

        pull = SearchPull.create!(client: @client, user: Current.user, force: ActiveModel::Type::Boolean.new.cast(params.dig(:pull, :force)) || false)
        pull.run_later
        redirect_to back, notice: "Pulling #{@client.name}'s search data: a minute or two. At most $#{format("%.2f", SearchPull.ceiling_for(@client, setting: setting))}."
      end
    end
  end
end
