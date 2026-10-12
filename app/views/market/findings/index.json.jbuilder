json.summary "#{@findings.size} #{@state == "all" ? "" : "#{@state} "}#{"finding".pluralize(@findings.size)}#{" for #{@client.name}" if @client}#{" in #{@industry.name}" if @industry}#{" changed since #{@since.iso8601}" if @since}"
json.as_of @as_of.utc.iso8601
json.findings @findings do |finding|
  json.partial! "market/findings/finding", finding: finding
end
