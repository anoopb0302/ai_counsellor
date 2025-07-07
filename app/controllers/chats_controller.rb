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

    answer = call_llm(prompt, 'phi3:mini')

    # Step 4: Save in Redis session chat log
    chat_log_key = SESSION_KEY.call(session.id)
    chat_log = JSON.parse($redis.get(chat_log_key) || "[]")
    chat_log << { query: query, response: answer }
    $redis.set(chat_log_key, chat_log.last(20).to_json)


    # puts chat_log
    # Step 5: Redirect to refresh chat UI
    # redirect_to root_path

    # respond_to do |format|
    #   format.html { redirect_to root_path }
    #   format.turbo_stream {
    #     render turbo_stream: turbo_stream.replace("chat_box", partial: "chats/chat_box", locals: { chat_log: chat_log })
    #   }
    # end

    respond_to do |format|
      format.html { redirect_to root_path }
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace("chat_box", partial: "chats/chat_box", locals: { chat_log: chat_log })
      }
    end


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
