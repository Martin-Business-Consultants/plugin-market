json.merge! agent_ref(@industry)
json.url market_industry_url(@industry)
json.summary "#{@industry.name}: #{@clients.size} #{"client".pluralize(@clients.size)}, #{@competitors.size} #{"competitor".pluralize(@competitors.size)}, #{@open.values.sum} open #{"opportunity".pluralize(@open.values.sum)}"
json.extract! @industry, :name, :naics_code, :description, :notes
json.clients @clients do |client|
  json.merge! agent_ref(client)
  json.competitors @rivals[client.id].to_i
  json.open_opportunities @open[client.id].to_i
end
json.competitors @competitors do |competitor|
  json.merge! agent_ref(competitor)
  json.website competitor.website
  json.against competitor.clients.map { agent_ref(it) }
  json.latest_reading market_reading_line(@readings[competitor.id])
end
json.open_by_channel @channels do |channel, opportunities|
  json.channel channel
  json.count opportunities.size
  json.top Market::Opportunity.by_priority(opportunities).first(3).map { { "title" => it.title, "client" => it.client.name } }
end
