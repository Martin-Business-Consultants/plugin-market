module Market
  # A Runwell plugin: it owns its tables (market_*), points at core records by id, and reaches the
  # core only through the plugin contract (docs/plugin-contract.md in Runwell). Remove it and
  # Runwell runs as before.
  class Engine < ::Rails::Engine
    # Routes join the app's route set (as market_*), so the core layout's helpers work on the
    # plugin's pages.
    initializer "market.routes" do |app|
      app.routes.append do
        scope module: "market", as: "market" do
          get "market", to: "overview#show", as: :overview
          resource :settings, path: "market/settings", controller: "settings", only: %i[show update] do
            resource :check, only: :create, controller: "settings/checks"
          end
          resources :findings, path: "market/findings", only: %i[index create update]
          resources :industries, path: "market/industries"
          resources :competitors, path: "market/competitors" do
            resource :check, only: :create, controller: "competitors/checks"
          end
          resources :clients, path: "market/clients", only: %i[index show edit update] do
            resource :check, only: :create, controller: "clients/checks"
            resources :rivalries, only: %i[create update destroy]
            resources :plans, only: %i[index create]
            resources :opportunities, only: :create
            resource :search, only: :show, controller: "clients/searches"
            resources :search_pulls, only: %i[index create], controller: "clients/search_pulls", path: "search/pulls"
            resources :keywords, only: %i[create destroy], controller: "clients/keywords"
          end
          resources :opportunities, path: "market/opportunities", only: %i[index update destroy] do
            resource :todo, only: :create, controller: "opportunities/todos"
          end
        end
      end
    end

    initializer "market.helpers" do
      ActiveSupport.on_load(:action_view) { include Market::MarketHelper }
    end

    # A client's market. Never a column on clients.
    initializer "market.models" do
      ActiveSupport.on_load(:runwell_client) do
        has_one :market_profile, class_name: "Market::Profile", dependent: :destroy
        has_many :market_rivalries, class_name: "Market::Rivalry", dependent: :delete_all
        has_many :market_opportunities, class_name: "Market::Opportunity", dependent: :delete_all
        has_many :market_plans, class_name: "Market::Plan", dependent: :destroy
        has_many :market_keywords, class_name: "Market::Keyword", dependent: :destroy
        has_many :market_findings, class_name: "Market::Finding", dependent: :delete_all
        has_many :market_search_pulls, class_name: "Market::SearchPull", dependent: :destroy
      end
    end

    config.to_prepare do
      Runwell::Plugins.register :market, name: "Market", version: Market::VERSION,
        author: "Martin Business Consultants", enabled_by_default: false, requires: ">= 2.21.0",
        homepage: "https://github.com/Martin-Business-Consultants/plugin-market",
        description: "The big picture behind every client's SEO and marketing: their industry, their competitors " \
                     "(each website read and watched weekly for what changes), and a plan drafted by the AI plugin " \
                     "from all of it: the opportunities by channel, impact and effort, each a click from being work."
      # icon: arrived in Runwell 2.25; an older core would refuse it and fail to boot.
      nav_icon = Runwell::Plugins.method(:nav).parameters.any? { |_, name| name == :icon } ? { icon: "boost" } : {}
      Runwell::Plugins.nav :market, "Market", -> { market_overview_path }, **nav_icon
      Runwell::Plugins.permission :market, :manage_market, name: "Change industries, competitors, market profiles and plans", roles: %w[owner manager]
      Runwell::Plugins.settings :market, "Market", -> { market_settings_path }
      Runwell::Plugins.stylesheet :market, "market/market"
      # The AI plugin's Ask panel (2.16): one-click questions on a client, answered through
      # Market's tools.
      if Runwell::Plugins.respond_to?(:ai_prompt)
        Runwell::Plugins.ai_prompt :market, "What should we do next to win this client's market?", types: [ "Client" ]
        Runwell::Plugins.ai_prompt :market, "What changed in this client's market lately?", types: [ "Client" ]
      end
      Runwell::Plugins.slot :client_panel, :market, "market/slots/client_panel"
      Runwell::Plugins.nightly :market, -> { Market::NightlyJob.perform_later }
      Runwell::Plugins.agent_workflow :market, "Planning a client's SEO and marketing", <<~STEPS
        1. `list_market_findings` first: what the data already says (stable keys, severity, exact evidence, sources). With `since` (the last answer's `as_of`) it answers only what's new, changed, resolved or dismissed: hear each change once. `show_market` is the whole portfolio at a glance.
        2. `show_client_market` for a client: profile, competitors with their latest website readings, findings, plan and opportunities. `update_client_market_profile` to fill what's missing (industry_name makes the industry if new; search_location is where their customers search from, a DataForSEO location like "Grand Rapids,Michigan,United States").
        3. Competitors: `list_competitors`, `create_competitor` with client_id, or `link_market_competitor` for one already watched. Websites are read weekly; `check_competitor_website` reads one now.
        4. Search: `show_market_search` (visibility, estimated traffic, keywords, tracked rankings, sites sharing their keywords). `track_market_keywords` for searches worth winning; `pull_market_search` spends from the month's DataForSEO budget to refresh it all (`list_market_search_pulls` says how it went and what it cost).
        5. `plan_market_with_ai` drafts the big picture and opportunities from all of it (needs the AI plugin); or `add_market_opportunity` for one of your own, citing a finding's evidence. Work them best first: `plan_market_opportunity_as_work` makes a todo on an open engagement; `update_market_opportunity` marks one done or dismissed.
        Never record a competitor, keyword or fact you haven't checked: AI suggestions are leads to verify. Search traffic is DataForSEO's estimate; say so.
      STEPS
    end
  end
end
