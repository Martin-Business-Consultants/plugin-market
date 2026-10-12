module Market
  # The plugin's pages use the core's layout, and vanish while it's switched off.
  class ApplicationController < ::ApplicationController
    layout "application"

    before_action { head :not_found unless Runwell::Plugins.enabled?(:market) }

    private
      def set_client = @client = Client.find(params[:client_id] || params[:id])
  end
end
