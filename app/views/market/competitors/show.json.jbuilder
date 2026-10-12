reading = @snapshots.first
json.merge! agent_ref(@competitor)
json.url market_competitor_url(@competitor)
json.summary "#{@competitor.name}: #{market_reading_line(reading)}"
json.extract! @competitor, :name, :website, :strengths, :weaknesses, :notes
json.industry @competitor.industry && agent_ref(@competitor.industry)
json.against @rivalries do |rivalry|
  json.client agent_ref(rivalry.client)
  json.extract! rivalry, :id, :kind, :threat, :notes
end
json.latest_reading do
  reading ? json.partial!("market/shared/reading", reading: reading) : json.nil!
end
json.changes(@snapshots.select { it.differences.any? }) do |snapshot|
  json.read_at snapshot.taken_at
  json.changes snapshot.differences
end
