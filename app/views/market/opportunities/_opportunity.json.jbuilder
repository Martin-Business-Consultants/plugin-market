json.merge! agent_ref(opportunity)
json.extract! opportunity, :title, :channel, :detail, :evidence, :impact, :effort, :horizon, :state, :decided_by_name, :decided_at
json.client agent_ref(opportunity.client)
json.todo opportunity.todo && agent_ref(opportunity.todo)
