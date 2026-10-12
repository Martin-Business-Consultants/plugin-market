require "market/version"
require "market/engine"

# Market: the big picture behind each client's SEO and marketing. Industries group clients and
# the competitors they share; each competitor's site is read from outside and watched for
# changes; each client has a market profile (who they serve, where, against whom); and a plan,
# drafted by the install's AI from all of it, lists the opportunities by channel, impact and
# effort, each one a click from being work on an engagement.
module Market
  # Plugin tables are prefixed with the plugin's key.
  def self.table_name_prefix = "market_"
end
