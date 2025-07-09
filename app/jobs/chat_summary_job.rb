# app/jobs/chat_summary_job.rb

require 'net/http'
require 'json'

# class ChatSummaryJob < ApplicationJob
#   queue_as :low_priority

#   def perform(session_id)
#     chat_log = JSON.parse($redis.get("chat_log:#{session_id}") || "[]")
#     return if chat_log.empty?

#     summary_prompt = <<~PROMPT
#       Summarize the student's background and goals in 2–3 lines based on this chat.

#       Chat:
#       #{chat_log.last(1).map { |c| "Student: #{c['query']}\nCounselor: #{c['response']}" }.join("\n")}

#       Summary:
#     PROMPT

#     summary = call_llm(summary_prompt)
#     $redis.set("chat_memory:#{session_id}", summary.strip)
#   end

#   def call_llm(prompt)
#     uri = URI("http://localhost:11434/api/generate")
#     req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
#     req.body = { model: 'phi3:mini', prompt: prompt, stream: false }.to_json
#     res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
#     JSON.parse(res.body)["response"]
#   end
# end


class ChatSummaryJob < ApplicationJob
  queue_as :low_priority

  def perform(session_id)
    chat_log = JSON.parse($redis.get("chat_log:#{session_id}") || "[]")
    return if chat_log.empty?

    new_turn = chat_log.last
    return if new_turn["query"].blank? || new_turn["response"].blank?

    old_summary = $redis.get("chat_memory:#{session_id}").to_s.strip

    # update_prompt = <<~PROMPT
    #   The student's background summary so far is:

    #   #{old_summary.presence || "(none)"}

    #   New interaction:
    #   Student: #{new_turn["query"]}
    #   Counselor: #{new_turn["response"]}

    #   Update the summary to include any new relevant facts. Keep it brief and concise (1–3 lines).
    # PROMPT

    summary_prompt = <<~PROMPT
      You are an assistant helping maintain a running summary of a student's counseling session.

      Given the previous summary and a new chat turn, update the summary **only** with new facts or goals mentioned.

      Keep the updated summary brief (max 3 lines) and only reflect new or clarified details.

      Previous Summary:
      #{last_summary.presence || "(none)"}

      New Chat:
      #{chat_log.last(1).map { |c| "Student: #{c['query']}\nCounselor: #{c['response']}" }.join("\n")}

      Updated Summary:
    PROMPT



    updated_summary = call_llm(summary_prompt).strip
    puts "Updated summary: #{updated_summary}"
    Rails.logger.info "[SUMMARY] Updated summary for session #{session_id}: #{updated_summary}"
    $redis.set("chat_memory:#{session_id}", updated_summary)
  end

  def call_llm(prompt)
    uri = URI("http://localhost:11434/api/generate")
    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    req.body = { model: 'phi3:mini', prompt: prompt, stream: false }.to_json
    res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
    JSON.parse(res.body)["response"]
  end
end
