# app/jobs/chat_sentiment_job.rb
require 'net/http'
require 'json'

class ChatSentimentJob < ApplicationJob
  queue_as :low_priority

  def perform(session_id)
    summary_key = "chat_memory:#{session_id}"
    log_key     = "chat_log:#{session_id}"
    sentiment_key = "chat_sentiment:#{session_id}"

    summary = $redis.get(summary_key)
    chat_log = JSON.parse($redis.get(log_key) || "[]")
    return if summary.blank? || chat_log.empty?

    last_message = chat_log.last["query"]

    prompt = <<~PROMPT

      You are a sentiment extractor AI for a student counselor. You will be given a session summary and the latest message from the student.

      Use this format:
      {
        "label": "POSITIVE" or "NEGATIVE" or "NEUTRAL",
        "score": "Sentiment score in percentage (0-100)",
        "summary": "Brief summary of the sentiment",
      }

      Summary:
      #{summary}

      Latest message:
      #{last_message}

      JSON:
    PROMPT

    sentiment = call_llm(prompt)

    ChatRelevanceJob.perform_later(session_id)

    $redis.set(sentiment_key, sentiment.strip)
  end

  private

  def call_llm(prompt)
    uri = URI("http://localhost:11434/api/generate")
    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    req.body = { model: 'phi3:mini', prompt: prompt, stream: false }.to_json
    res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
    JSON.parse(res.body)["response"]
  end
end
