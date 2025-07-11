class ChatsController < ApplicationController
  SESSION_KEY     = ->(id) { "chat_log:#{id}" }
  MEMORY_KEY      = ->(id) { "chat_memory:#{id}" }
  FACTS_KEY       = ->(id) { "chat_facts:#{id}" }

  def index
    @chat_session_id = params[:chat_session_id] || generate_new_session_id
    chat_log_key = SESSION_KEY.call(@chat_session_id)
    @chat_log = JSON.parse($redis.get(chat_log_key) || "[]")
  end

  def create
    @chat_session_id = params[:chat_session_id]
    query = params[:query].to_s.strip
    return redirect_to chat_session_path(@chat_session_id), alert: "Empty query" if query.blank?

    prompt = LlmPromptBuilder.new(query, @chat_session_id).build_prompt
    return redirect_to chat_session_path(@chat_session_id), alert: "Could not generate prompt" if prompt.nil?

    chat_log_key = SESSION_KEY.call(@chat_session_id)
    chat_log = JSON.parse($redis.get(chat_log_key) || "[]")
    chat_log << { "query" => query, "response" => nil }
    $redis.set(chat_log_key, chat_log.to_json)
    $redis.set("chat_typing:#{@chat_session_id}", true)

    LlmResponseJob.perform_later(@chat_session_id, query, prompt)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("chat_messages", partial: "chats/chat_box", locals: { chat_log: chat_log }),
          turbo_stream.replace("chat_typing", partial: "chats/chat_typing")
        ]
      end
      format.html { redirect_to chat_session_path(@chat_session_id) }
    end
  end

  private

  def generate_new_session_id
    SecureRandom.uuid.tap do |id|
      redirect_to chat_session_path(id) and return
    end
  end
end
