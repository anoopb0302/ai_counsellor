require 'net/http'
require 'json'
class ChatMemoryJob < ApplicationJob
  queue_as :low_priority  # Or just :default if you don't have multiple queues

  def perform(session_id)
    ChatSummaryJob.perform_later(session_id)
    ChatFactsJob.perform_later(session_id)
  end
end
