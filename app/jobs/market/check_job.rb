module Market
  # Reads one website (a competitor's, or a client's own) off the request, then works out the
  # findings again for every client it concerns.
  class CheckJob < ApplicationJob
    def perform(subject)
      subject.check_now
      clients = subject.is_a?(Profile) ? [ subject.client ] : subject.clients.to_a
      clients.each { Finding.refresh(it) }
    end
  end
end
