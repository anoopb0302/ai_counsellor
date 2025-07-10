# app/jobs/chat_relevance_job.rb
require 'net/http'
require 'json'

class ChatRelevanceJob < ApplicationJob
  queue_as :low_priority

  def perform(session_id)
    summary_key    = "chat_memory:#{session_id}"
    log_key        = "chat_log:#{session_id}"
    relevance_key  = "chat_relevance:#{session_id}"
    sentiment_key = "chat_sentiment:#{session_id}"

    summary   = $redis.get(summary_key)
    sentiment   = $redis.get(sentiment_key)
    chat_log  = JSON.parse($redis.get(log_key) || "[]")
    return if summary.blank? || chat_log.empty? || sentiment.blank?

    last_message = chat_log.last["query"]

    # prompt = <<~PROMPT
    #   You are an AI assistant that checks if a student's message is relevant to their educational goals.

    #   You will be given:
    #   - A summary of the student's background.
    #   - The latest message from the student.

    #   Your task is to determine if the message is relevant to their goal (e.g., NEET, JEE, GATE) or off-topic.

    #   Respond in this JSON format:
    #   {
    #     "label": "RELEVANT" or "OFF_TOPIC",
    #     "confidence": "0-100",
    #     "explanation": "Brief explanation about why it is or isn’t relevant"
    #   }

    #   Summary:
    #   #{summary}

    #   Latest message:
    #   #{last_message}

    #   JSON:
    # PROMPT

    prompt = <<~PROMPT
      Analyze the relevance of this student's conversation with respect to academic guidance, exam preparation, and educational counseling.

      You will be given:
      - A summary of the student's chat conversation.
      - The sentiment of the student's chat conversation.
      - The latest chat messages with the student.

      Summary:
      #{summary}

      Sentiment:
      #{sentiment}

      Chat:
      #{chat_log.last(5).map { |c| "Student: #{c['query']}\nCounselor: #{c['response']}" }.join("\n")}

      Respond in this JSON format:
      {
        "relevance": "RELEVANT" | "OFF_TOPIC" | "PARTIALLY_RELEVANT",
        "score": "0 to 100",
        "summary": "Brief explanation about why it is or isn’t relevant"
      }

      JSON:
    PROMPT

    relevance = call_llm(prompt)
    $redis.set(relevance_key, relevance.strip)
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
