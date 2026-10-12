json.client agent_ref(@client)
json.summary @data.pulled? ? "#{@client.name}'s search data from DataForSEO (#{Market::Setting.current.country}), pulled #{@data.last_pull&.finished_at&.to_date&.to_fs(:long)}" : "No search data for #{@client.name} yet"
json.country Market::Setting.current.country
json.search_location @data.profile&.search_location
json.last_pull @data.last_pull&.slice(:id, :state, :cost, :error, :notes, :finished_at)
json.sites @data.sites do |site|
  json.name site.name
  json.domain site.domain
  json.client_site site.own
  json.overview site.overview&.data
  json.overview_at site.overview&.taken_at
  json.previous_overview site.previous&.data
  json.previous_overview_at site.previous&.taken_at
  json.backlinks site.backlinks&.data
  json.keywords_total site.keywords&.data&.dig("total")
  json.keywords Array(site.keywords&.data&.dig("keywords")).first(@limit)
end
json.tracked @data.tracked do |row|
  json.keyword row[:keyword].keyword
  json.id row[:keyword].id
  json.source row[:keyword].source
  json.checked_at row[:ranking]&.checked_at
  json.location row[:ranking]&.location
  json.client_position row[:position]
  json.client_position_before row[:before]
  json.client_url row[:ranking]&.client_url
  json.competitors row[:competitors]
  json.on_the_page row[:ranking]&.features || []
end
json.also_competing_in_search @data.unwatched
