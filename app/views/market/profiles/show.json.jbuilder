json.merge! agent_ref(@client)
json.url market_client_url(@client)
json.summary "#{@client.name}: #{@profile.industry&.name || "no industry"}, #{@rivalries.size} #{"competitor".pluralize(@rivalries.size)}, " \
             "#{@opportunities.count(&:active?)} open or planned #{"opportunity".pluralize(@opportunities.count(&:active?))}" \
             "#{"; missing #{@profile.gaps.to_sentence}" if @profile.gaps.any?}"
json.profile do
  json.industry @profile.industry && agent_ref(@profile.industry)
  json.extract! @profile, :website, :service_area, :offerings, :audience, :positioning, :goals, :notes
  json.missing @profile.gaps
end
json.own_website do
  @own ? json.partial!("market/shared/reading", reading: @own) : json.nil!
end
json.competitors @rivalries do |rivalry|
  json.merge! agent_ref(rivalry.competitor)
  json.rivalry_id rivalry.id
  json.extract! rivalry, :kind, :threat, :notes
  json.website rivalry.competitor.website
  json.extract! rivalry.competitor, :strengths, :weaknesses
  reading = @readings[rivalry.competitor_id]
  json.latest_reading do
    reading ? json.partial!("market/shared/reading", reading: reading) : json.nil!
  end
end
json.plan do
  if @plan
    json.extract! @plan, :id, :state, :summary, :positioning, :industry_suggestion, :competitor_suggestions, :error, :finished_at
  else
    json.nil!
  end
end
json.opportunities @opportunities do |opportunity|
  json.partial! "market/opportunities/opportunity", opportunity: opportunity
end
