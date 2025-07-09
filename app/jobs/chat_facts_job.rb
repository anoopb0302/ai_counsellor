# app/jobs/chat_facts_job.rb

require 'net/http'
require 'json'

# class ChatFactsJob < ApplicationJob
#   queue_as :low_priority

#   def perform(session_id)
#     chat_log = JSON.parse($redis.get("chat_log:#{session_id}") || "[]")
#     return if chat_log.empty?

#     extraction_prompt = <<~PROMPT
#       Extract key facts about the student from this conversation.

#       Output JSON format:
#       {
#         "name": "Student's name if mentioned",
#         "age": "Student's age if mentioned",
#         "mobile": "Student's mobile number if mentioned",
#         "email": "Student's email if mentioned",  
#         "location": "Student's location if mentioned",
#         "education": "Current education level if mentioned",
#         "interests": "Student's interests if mentioned",
#         "goal": "Short goal like 'Crack NEET/IIT JEE/GATE 2026'",
#         "exam": "Mentioned exam like NEET/IIT JEE/GATE etc.",
#         "year": "Target year if mentioned",
#         "language": "Preferred language if mentioned",
#         "background": "Brief background if mentioned",
#         "other": "Any other relevant facts"
#       }

#       Only include fields that were actually mentioned.

#       Chat:
#       #{chat_log.last(1).map { |c| "Student: #{c['query']}\nCounselor: #{c['response']}" }.join("\n")}

#       JSON:
#     PROMPT

#     raw = call_llm(extraction_prompt)
#     facts = JSON.parse(raw) rescue nil
#     $redis.set("chat_facts:#{session_id}", facts.to_json) if facts
#   end

#   def call_llm(prompt)
#     uri = URI("http://localhost:11434/api/generate")
#     req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
#     req.body = { model: 'phi3:mini', prompt: prompt, stream: false }.to_json
#     res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
#     JSON.parse(res.body)["response"]
#   end
# end


class ChatFactsJob < ApplicationJob
  queue_as :low_priority

  def perform(session_id)
    chat_log = JSON.parse($redis.get("chat_log:#{session_id}") || "[]")
    return if chat_log.empty?

    new_turn = chat_log.last
    return if new_turn["query"].blank? || new_turn["response"].blank?

    old_facts = JSON.parse($redis.get("chat_facts:#{session_id}") || "{}")

    extraction_prompt = <<~PROMPT
      You are a fact extractor AI for a student counselor. You will be given a previous JSON and a new chat turn.

      Merge new facts from the chat into the existing JSON, only if they were clearly mentioned by the student do not assume.

      Use this format:
      {
        "name": "Student's name if mentioned",
        "age": "Student's age if mentioned",
        "mobile": "Student's mobile number if mentioned",
        "email": "Student's email if mentioned",
        "location": "Student's location if mentioned",
        "education": "Current education level if mentioned",
        "interests": "Student's interests if mentioned",
        "goal": "Short goal like 'Crack NEET/IIT JEE/GATE 2026'",
        "exam": "Mentioned exam like NEET/IIT JEE/GATE etc.",
        "year": "Target year if mentioned",
        "language": "Preferred language if mentioned",
        "background": "Brief background if mentioned",
        "other": "Any other relevant facts"
      }

      Previous JSON:
      #{JSON.pretty_generate(old_facts)}

      New Chat:
      Student: #{new_turn["query"]}
      Counselor: #{new_turn["response"]}

      Updated JSON:
    PROMPT

    raw_response = call_llm(extraction_prompt)

    # Attempt parsing
    new_facts = JSON.parse(raw_response) rescue nil

    if new_facts
      $redis.set("chat_facts:#{session_id}", new_facts.to_json)
    else
      Rails.logger.warn("[FACTS] Failed to parse updated facts for session #{session_id}")
    end
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

