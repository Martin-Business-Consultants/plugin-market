module Market
  # The nightly run: websites not read this week are read (WeeklyCheckJob), clients due a search
  # pull by Settings › Market's refresh get one (within the month's budget, which each call
  # checks), and every client's findings are worked out again, so age-based ones (stale data,
  # recent site changes) come and go on their own.
  class NightlyJob < ApplicationJob
    def perform
      return unless Runwell::Plugins.enabled?(:market)

      WeeklyCheckJob.perform_later
      schedule_pulls
      Client.where(id: Profile.select(:client_id)).or(Client.where(id: Rivalry.select(:client_id))).find_each { FindingsJob.perform_later(it) }
    end

    private
      def schedule_pulls
        setting = Setting.current
        every = setting.refresh_every
        return unless every && setting.search_connected? && setting.remaining_budget.positive?

        profiles = Profile.where.not(domain: [ nil, "" ]).where(client: Client.active).to_a
        last = SearchPull.where(client_id: profiles.map(&:client_id), state: %w[ready partial queued running]).group(:client_id).maximum(:created_at)
        profiles.each do |profile|
          next if last[profile.client_id] && last[profile.client_id] > every.ago + 1.hour

          SearchPull.create!(client_id: profile.client_id).run_later
        end
      end
  end
end
