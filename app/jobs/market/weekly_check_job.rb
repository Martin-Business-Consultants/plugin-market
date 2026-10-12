module Market
  # The nightly run's part: every website not read in a week is read again, one job each, so a
  # slow site holds up nothing else.
  class WeeklyCheckJob < ApplicationJob
    def perform
      return unless Runwell::Plugins.enabled?(:market)

      [ Competitor, Profile ].each do |model|
        due = model.watchable.to_a
        latest = Snapshot.latest_for(due)
        due.each { |subject| CheckJob.perform_later(subject) if latest[subject.id].nil? || latest[subject.id].taken_at < Watched::CHECK_EVERY.ago }
      end
    end
  end
end
