json.summary "#{@industries.size} #{"industry".pluralize(@industries.size)}, #{@competitor_count} #{"competitor".pluralize(@competitor_count)} watched, " \
             "#{@open_count} open #{"opportunity".pluralize(@open_count)} (#{@quick_wins} quick #{"win".pluralize(@quick_wins)}), " \
             "#{@unprofiled.size} active #{"client".pluralize(@unprofiled.size)} with no industry"
json.industries @industries do |industry|
  json.merge! agent_ref(industry)
  json.extract! industry, :name, :naics_code
  json.clients @clients_by_industry[industry.id].to_i
  json.competitors @competitors_by_industry[industry.id].to_i
end
json.best_opportunities @opportunities do |opportunity|
  json.merge! agent_ref(opportunity)
  json.extract! opportunity, :title, :channel, :impact, :effort, :horizon
  json.client agent_ref(opportunity.client)
end
json.competitor_changes @changes do |snapshot|
  json.competitor agent_ref(snapshot.subject)
  json.taken_at snapshot.taken_at
  json.changes snapshot.differences
end
json.top_findings @findings do |finding|
  json.partial! "market/findings/finding", finding: finding
end
json.clients_without_industry @unprofiled.map { agent_ref(it) }
