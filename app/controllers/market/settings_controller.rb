module Market
  # Settings › Market: the DataForSEO account, the month's budget and what's been spent, where
  # searches are measured, and how often clients' search data is pulled on its own.
  class SettingsController < ApplicationController
    require_permission :manage_settings
    agent_tool :show_market_settings, on: :show, title: "Show Market's settings",
      description: "Whether DataForSEO is connected (never the password), its balance when last checked, the month's search budget, what's been spent and is left, the country and language searches are measured in, how often search data is pulled on its own, and the latest requests with what each cost.",
      next_tools: %i[update_market_settings check_market_dataforseo]
    agent_tool :update_market_settings, on: :update, title: "Change Market's settings",
      description: "dataforseo_login and dataforseo_password (a blank password keeps the saved one), monthly_budget_dollars, country (a DataForSEO location name: \"United States\"), language_code (en), refresh (off, monthly, weekly), keyword_limit (10–1000 keywords per site per pull), backlinks (true needs DataForSEO's Backlinks subscription).",
      params: { setting: { dataforseo_login: "string", dataforseo_password: "string", monthly_budget_dollars: "number", country: "string",
                           language_code: "string", refresh: Setting::REFRESH.keys, keyword_limit: "integer", backlinks: "boolean" } }

    before_action :set_setting

    def show
      @requests = SearchRequest.latest_first.limit(25).to_a
    end

    def update
      attributes = params.expect(setting: %i[dataforseo_login dataforseo_password monthly_budget_dollars country language_code refresh keyword_limit backlinks])
      attributes.delete(:dataforseo_password) if attributes[:dataforseo_password].blank?
      if (dollars = attributes.delete(:monthly_budget_dollars)).present?
        attributes[:monthly_budget_cents] = (dollars.to_d * 100).round
      end
      if @setting.update(attributes)
        redirect_to market_settings_path, notice: "Market's settings saved."
      else
        @requests = SearchRequest.latest_first.limit(25).to_a
        render :show, status: :unprocessable_entity
      end
    end

    private
      def set_setting = @setting = Setting.current
  end
end
