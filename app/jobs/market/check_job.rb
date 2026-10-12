module Market
  # Reads one website (a competitor's, or a client's own) off the request.
  class CheckJob < ApplicationJob
    def perform(subject) = subject.check_now
  end
end
