class ChatsController < ApplicationController
  require 'net/http'
  require 'json'

  SESSION_KEY = ->(session_id) { "chat_log:#{session_id}" }

  # Skip CSRF for JSON API, fallback to UI
  skip_forgery_protection only: [:create]
  protect_from_forgery unless: -> { request.format.json? }

  def index
    chat_log_key = SESSION_KEY.call(session.id)
    @chat_log = JSON.parse($redis.get(chat_log_key) || "[]")
    # puts @chat_log.inspect
  end

  def create
    query = params[:query].to_s.strip
    return redirect_to root_path, alert: "Empty query" if query.blank?

    # Step 1: Embed the query
    vector = embed_query(query)

    # Step 2: Semantic search
    results = Chunk.order(Arel.sql("embedding <-> '[#{vector.join(',')}]'")).limit(3)
    context = results.map { |c| "#{c.title}: #{c.text.truncate(150)}" }.join("\n\n")

    # Step 3: Prompt LLM
    prompt = <<~PROMPT
      You are a helpful academic counselor for Physics Wallah.

      Based on the following context:

      #{context}

      Answer this question:
      "#{query}"
    PROMPT




    session[:typing] = true
    # Append user message without response
    # chat_log_key = "SESSION_KEY:#{session.id}"

    chat_log_key = SESSION_KEY.call(session.id)

    chat_log = JSON.parse($redis.get(chat_log_key) || "[]")
    chat_log << { "query" => query, "response" => nil }
    $redis.set(chat_log_key, chat_log.to_json)


    # Set typing indicator in Redis
    $redis.set("chat_typing:#{session.id}", true)


    # answer = call_llm(prompt, 'phi3:mini')

    # answer = 'Hey, I am still learning how to answer questions. Please try again later.'

    # Step 4: Save in Redis session chat log
    # chat_log_key = SESSION_KEY.call(session.id)
    # chat_log = JSON.parse($redis.get(chat_log_key) || "[]")
    # chat_log << { query: query, response: answer }

    # chat_log << {
    #   "query" => query,
    #   "response" => answer
    #   }

    # $redis.set(chat_log_key, chat_log.last(20).to_json)

    # respond_to do |format|
    #   format.turbo_stream {
    #     render turbo_stream: turbo_stream.replace(
    #       "chat_box",
    #       partial: "chats/chat_box",
    #       locals: { chat_log: chat_log }
    #     )
    #   }
    #   format.html { redirect_to root_path }
    # end


    LlmResponseJob.perform_later(session.id.to_s, query, prompt)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("chat_messages", partial: "chats/chat_box", locals: { chat_log: chat_log }),
          turbo_stream.replace("chat_typing", partial: "chats/chat_typing")
        ]
      end
      format.html { redirect_to root_path }
    end

    # Background thread to simulate async LLM response replaced with sidekiq job

    # Thread.new do
    #   answer = call_llm(prompt, 'phi3:mini')
    #   chat_log.last["response"] = answer
    #   $redis.set(chat_log_key, chat_log.to_json)
    #   session[:typing] = false

    #   Turbo::StreamsChannel.broadcast_replace_to(
    #     session.id,
    #     target: "chat_messages",
    #     partial: "chats/chat_box",
    #     locals: { chat_log: chat_log }
    #   )

    #   Turbo::StreamsChannel.broadcast_replace_to(
    #     session.id,
    #     target: "chat_typing",
    #     content: "<turbo-frame id='chat_typing'></turbo-frame>" # clear typing indicator
    #   )
    # end


  end

  private

  def embed_query(text)
    uri = URI("http://localhost:8000/embed")
    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    req.body = { texts: [text] }.to_json
    res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
    JSON.parse(res.body)["embedding"]
  end

  def call_llm(prompt, model)
    uri = URI("http://localhost:11434/api/generate")
    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    req.body = { model: model, prompt: prompt, stream: false }.to_json
    res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
    JSON.parse(res.body)["response"]
  end
end
