module Market
  # Pulls one client's search data off the request (SearchPull#run!): a minute or two.
  class SearchPullJob < ApplicationJob
    def perform(pull) = pull.run!
  end
end
