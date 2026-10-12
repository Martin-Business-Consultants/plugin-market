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
          resources :industries, path: "market/industries"
          resources :competitors, path: "market/competitors" do
            resource :check, only: :create, controller: "competitors/checks"
          end
          resources :clients, path: "market/clients", controller: "profiles", only: %i[index show edit update] do
            resource :check, only: :create, controller: "profiles/checks"
            resources :rivalries, only: %i[create update destroy]
            resources :plans, only: %i[index create]
            resources :opportunities, only: :create
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
      Runwell::Plugins.stylesheet :market, "market/market"
      Runwell::Plugins.slot :client_panel, :market, "market/slots/client_panel"
      Runwell::Plugins.nightly :market, -> { Market::WeeklyCheckJob.perform_later }
      Runwell::Plugins.agent_workflow :market, "Planning a client's SEO and marketing", <<~STEPS
        1. `show_client_market` for what's known: their profile (industry, website, service area, offerings, audience, positioning, goals), competitors with their latest website readings and changes, the latest plan and the opportunities. `update_client_market_profile` to fill what's missing; industry_name sets the industry (made if new).
        2. Competitors: `list_competitors` (a competitor is shared by every client it competes with), `create_competitor` with client_id to add one to a client, or `link_market_competitor` for one already watched. kind: direct, indirect, aspirational; threat: high, medium, low. `check_competitor_website` reads a site now; they're read weekly anyway.
        3. `plan_market_with_ai` drafts the big picture and opportunities from all of it (a minute, needs the AI plugin); `show_market_plan` reads it. Or `add_market_opportunity` for one of your own.
        4. Work the opportunities best first: `plan_market_opportunity_as_work` makes one a todo on an open engagement; `update_market_opportunity` marks it done or dismissed. `show_market` and `list_market_opportunities` give the whole portfolio, by industry.
        Never record a competitor or a fact you haven't checked: an AI suggestion is a lead to verify.
      STEPS
    end
  end
end
