module Market
  # Settings › Market: the DataForSEO account search data comes from (its password encrypted),
  # what may be spent on it a month, where searches are measured by default, and how often a
  # client's data is pulled on its own. One row.
  class Setting < ApplicationRecord
    REFRESH = { "off" => "Only when someone asks", "monthly" => "Every month", "weekly" => "Every week" }.freeze
    REFRESH_EVERY = { "monthly" => 1.month, "weekly" => 1.week }.freeze

    encrypts :dataforseo_password

    normalizes :dataforseo_login, with: ->(login) { login.strip.presence }
    normalizes :country, with: ->(country) { country.strip }

    validates :monthly_budget_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :keyword_limit, numericality: { only_integer: true, in: 10..1000 }
    validates :refresh, inclusion: { in: REFRESH.keys }
    validates :country, presence: true
    validates :language_code, format: { with: /\A[a-z]{2}(-[a-z]{2,4})?\z/i, message: "is a code like en" }

    def self.current = first || new

    def search_connected? = dataforseo_login.present? && dataforseo_password.present?

    def budget = monthly_budget_cents.to_d / 100
    def monthly_budget_dollars = budget
    def spent_this_month = SearchRequest.where(created_at: Time.current.beginning_of_month..).sum(:cost).to_d
    def remaining_budget = [ budget - spent_this_month, 0.to_d ].max
    def refresh_every = REFRESH_EVERY[refresh]

    def note_error!(message) = persisted? && update_columns(last_error: message.to_s.truncate(500), updated_at: Time.current)
    def clear_error! = persisted? && last_error && update_columns(last_error: nil, updated_at: Time.current)

    # Asks DataForSEO who we are and what's left on the account (free), and keeps the balance.
    def check!(client: Search::Client.new(setting: self))
      balance = client.balance
      update_columns(balance: balance, checked_at: Time.current, last_error: nil, updated_at: Time.current)
      balance
    end
  end
end
