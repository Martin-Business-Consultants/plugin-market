json.summary "#{@opportunities.size} #{@state == "all" ? "" : "#{@state} "}#{"opportunity".pluralize(@opportunities.size)}#{" for #{@client.name}" if @client}#{" in #{@industry.name}" if @industry}"
json.counts @counts
json.opportunities @opportunities do |opportunity|
  json.partial! "market/opportunities/opportunity", opportunity: opportunity
end
