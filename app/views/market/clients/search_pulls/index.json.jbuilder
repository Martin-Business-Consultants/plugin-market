json.summary "#{@pulls.size} search #{"pull".pluralize(@pulls.size)} for #{@client.name}"
json.client agent_ref(@client)
json.pulls @pulls do |pull|
  json.extract! pull, :id, :state, :force, :error, :notes, :created_at, :started_at, :finished_at
  json.cost pull.cost.to_f
  json.working pull.working?
  json.by pull.user&.display_name
end
