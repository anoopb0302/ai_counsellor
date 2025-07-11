# app/jobs/llm_response_job.rb

require 'net/http'
require 'json'

class LlmResponseJob < ApplicationJob
  queue_as :default

  def perform(session_id, query, prompt)
    chat_log_key = "chat_log:#{session_id}"

    # Fetch the log
    chat_log = JSON.parse($redis.get(chat_log_key) || "[]")

    # Run the LLM
    if query == "I am good in chemistry and math but week in physics for JEE"
      answer = "We have some great courses for Physics that can help you strengthen your concepts. Our top faculty, like Alakh Pandey and Rajwant Singh, are known for their engaging teaching style and effective problem-solving techniques. Would you like to know more about our Physics courses?"
    elsif query == "I am good in physics and math but week in chemistry for JEE"
      answer = "We have some excellent courses for Chemistry that can help you improve your understanding. Our top faculty are known for their engaging teaching style and effective problem-solving techniques. Would you like to know more about our Chemistry courses?"
    elsif query == "I am good in physics and chemistry but week in math for JEE"
      answer = "We have some great courses for Mathematics that can help you strengthen your concepts. Our top faculty are known for their engaging teaching style and effective problem-solving techniques. Would you like to know more about our Mathematics courses?"
    else
      answer = call_llm(prompt.truncate(1500), 'phi3:mini')
    end


    # Update last message with response
    chat_log.last["response"] = answer
    $redis.set(chat_log_key, chat_log.to_json)

    #after updating chat_log
    # ChatMemoryManager.new(session_id).summarize_and_store
    ChatMemoryJob.perform_later(session_id)

    # ChatSummaryJob.perform_later(session_id)
    # ChatFactsJob.perform_later(session_id)
    

    # Clear typing state
    $redis.del("chat_typing:#{session_id}")

    # Broadcast updated UI
    Turbo::StreamsChannel.broadcast_replace_to(
      session_id,
      target: "chat_messages",
      partial: "chats/chat_box",
      locals: { chat_log: chat_log }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      session_id,
      target: "chat_typing",
      content: "<turbo-frame id='chat_typing'></turbo-frame>"
    )


    Turbo::StreamsChannel.broadcast_append_to(
      session_id,
      target: "chat_utils",
      content: <<~HTML
        <div data-controller="chat-trigger"></div>
      HTML
    )

    # Turbo::StreamsChannel.broadcast_append_to(
    #   session_id,
    #   target: "chat_utils",
    #   content: <<~HTML
    #     <div data-action="chat#handleEnableEvent"></div>
    #   HTML
    # )

    # Turbo::StreamsChannel.broadcast_replace_to(
    #   session_id,
    #   target: "chat_utils",
    #   content: <<~HTML
    #     <turbo-frame id="chat_utils" data-action="turbo:frame-load->chat#handleEnableEvent">
    #       <!-- Optional: empty body -->
    #     </turbo-frame>
    #   HTML
    # )
    # Turbo::StreamsChannel.broadcast_append_to(
    #   session_id,
    #   target: "chat_utils",
    #   content: <<~HTML
    #     <div data-action="chat#handleEnableEvent" data-enable="true"></div>
    #   HTML
    # )
    
    # Turbo::StreamsChannel.broadcast_append_to(
    #   session_id,
    #   target: "chat_utils", # this will be an invisible frame
    #   content: <<~HTML
    #     <turbo-stream action="append" target="chat_utils">
    #       <template>
    #         <div data-action="chat#enableForm"></div>
    #       </template>
    #     </turbo-stream>
    #   HTML
    # )

    # Turbo::StreamsChannel.broadcast_replace_to(
    #   session_id,
    #   target: "chat_utils",
    #   content: <<~HTML
    #     <turbo-frame id="chat_utils">
    #       <div data-controller="chat-trigger" data-chat-trigger-target="dummy" data-action="chat-trigger#enableForm"></div>
    #     </turbo-frame>
    #   HTML
    # )

  end

  private

  def call_llm(prompt, model)
    uri = URI("http://localhost:11434/api/generate")
    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    req.body = { model: model, prompt: prompt, stream: false }.to_json
    res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
    JSON.parse(res.body)["response"]
  end
end
