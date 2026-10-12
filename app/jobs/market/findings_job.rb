module Market
  # Works one client's findings out again, after something they're drawn from changed.
  class FindingsJob < ApplicationJob
    def perform(client) = Finding.refresh(client)
  end
end
