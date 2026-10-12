module Market
  module Settings
    # Checks the DataForSEO login by asking for the account's balance (which costs nothing).
    class ChecksController < ApplicationController
      require_permission :manage_settings
      agent_tool :check_market_dataforseo, on: :create, title: "Check the DataForSEO connection",
        description: "Signs in to DataForSEO with the saved login and answers the account's balance; costs nothing."

      def create
        setting = Setting.current
        balance = setting.check!
        redirect_to market_settings_path, notice: "Connected to DataForSEO: $#{format("%.2f", balance)} left on the account."
      rescue Search::Client::Error => error
        setting.note_error!(error.message)
        redirect_to market_settings_path, alert: error.message
      end
    end
  end
end
