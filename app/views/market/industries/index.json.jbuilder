json.summary "#{@industries.size} #{"industry".pluralize(@industries.size)}"
json.industries @industries do |industry|
  json.merge! agent_ref(industry)
  json.url market_industry_url(industry)
  json.extract! industry, :name, :naics_code, :description
  json.clients @clients[industry.id].to_i
  json.competitors @competitors[industry.id].to_i
  json.open_opportunities @open[industry.id].to_i
end
