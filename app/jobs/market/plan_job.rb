module Market
  # Drafts a plan off the request (Plan#run!): the AI takes a minute.
  class PlanJob < ApplicationJob
    def perform(plan) = plan.run!
  end
end
