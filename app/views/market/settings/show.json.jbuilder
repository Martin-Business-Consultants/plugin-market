json.summary @setting.search_connected? ? "DataForSEO connected; $#{format("%.2f", @setting.spent_this_month)} of $#{format("%.2f", @setting.budget)} spent this month" : "DataForSEO isn't connected"
json.dataforseo do
  json.connected @setting.search_connected?
  json.login @setting.dataforseo_login
  json.balance @setting.balance&.to_f
  json.checked_at @setting.checked_at
  json.last_error @setting.last_error
end
json.budget do
  json.monthly @setting.budget.to_f
  json.spent_this_month @setting.spent_this_month.to_f
  json.remaining @setting.remaining_budget.to_f
end
json.extract! @setting, :country, :language_code, :refresh, :keyword_limit, :backlinks
json.latest_requests @requests do |request|
  json.extract! request, :created_at, :endpoint, :target, :status_code, :status_message, :attempts, :duration_ms, :error
  json.cost request.cost.to_f
end
