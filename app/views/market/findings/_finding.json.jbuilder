json.merge! agent_ref(finding)
json.extract! finding, :key, :kind, :severity, :channel, :title, :detail, :evidence, :sources, :state, :first_seen_at, :last_seen_at, :changed_at, :resolved_at, :dismissed_at, :dismissed_by_name
json.client agent_ref(finding.client)
json.market_url market_client_url(finding.client, anchor: "findings")
