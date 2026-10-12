json.summary "#{@clients.size} #{"client".pluralize(@clients.size)}#{" with gaps to fill" if @show == "gaps"}#{" in #{@industry.name}" if @industry}"
json.clients @clients do |client|
  profile = @profiles[client.id]
  json.merge! agent_ref(client)
  json.market_url market_client_url(client)
  json.industry profile&.industry && agent_ref(profile.industry)
  json.website profile&.website
  json.competitors @rivals[client.id].to_i
  json.open_opportunities @open[client.id].to_i
  json.last_planned_at @planned_at[client.id]
  json.missing profile ? profile.gaps : [ "a market profile" ]
end
