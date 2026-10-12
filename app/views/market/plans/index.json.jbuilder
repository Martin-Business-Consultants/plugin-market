json.summary @plan ? "#{@client.name}'s latest plan is #{@plan.state}#{", drafted #{@plan.finished_at.to_date.to_fs(:long)}" if @plan.ready? && @plan.finished_at}" : "No plan for #{@client.name} yet"
json.client agent_ref(@client)
json.latest do
  if @plan
    json.extract! @plan, :id, :state, :summary, :positioning, :industry_suggestion, :competitor_suggestions, :error, :finished_at
    json.opportunities @plan.opportunities do |opportunity|
      json.merge! agent_ref(opportunity)
      json.extract! opportunity, :title, :channel, :impact, :effort, :horizon, :state
    end
  else
    json.nil!
  end
end
json.earlier @plans.drop(1) do |plan|
  json.extract! plan, :id, :state, :summary, :finished_at
end
