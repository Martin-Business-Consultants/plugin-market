json.summary "#{@competitors.size} #{"competitor".pluralize(@competitors.size)}#{" in #{@industry.name}" if @industry}#{" against #{@client.name}" if @client}"
json.competitors @competitors do |competitor|
  reading = @readings[competitor.id]
  json.merge! agent_ref(competitor)
  json.url market_competitor_url(competitor)
  json.extract! competitor, :name, :website
  json.industry competitor.industry && agent_ref(competitor.industry)
  json.against competitor.clients.map { agent_ref(it) }
  json.latest_reading market_reading_line(reading)
  json.tools market_tool_labels(reading)
  json.read_at reading&.taken_at
  json.recent_changes reading&.differences || []
end
