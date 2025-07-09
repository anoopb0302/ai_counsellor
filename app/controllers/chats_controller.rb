class ChatsController < ApplicationController
  require 'net/http'
  require 'json'

  SESSION_KEY = ->(session_id) { "chat_log:#{session_id}" }
  MEMORY_KEY = ->(session_id) { "chat_memory:#{session_id}" }
  FACTS_KEY = ->(session_id) { "chat_facts:#{session_id}" }

  # Skip CSRF for JSON API, fallback to UI
  skip_forgery_protection only: [:create]
  protect_from_forgery unless: -> { request.format.json? }

  def index
    session[:init] ||= true
    chat_log_key = SESSION_KEY.call(session.id)
    @chat_log = JSON.parse($redis.get(chat_log_key) || "[]")
    # puts @chat_log.inspect
  end

  def create
    # query = params[:query].to_s.strip
    # return redirect_to root_path, alert: "Empty query" if query.blank?

    # # Step 1: Embed the query
    # vector = embed_query(query)

    # # Step 2: Initial vector search (top 10 for reranking headroom)
    # initial_chunks = Chunk.order(Arel.sql("embedding <-> '[#{vector.join(',')}]'")).limit(10)

    # # Step 3: Rerank based on title-query overlap
    # reranked_chunks = rerank_chunks_by_title_match(initial_chunks, query)

    # # Step 4: Prepare top 3 final context chunks
    # top_chunks = reranked_chunks.take(3).map { |c| "#{c.title} — #{c.text}" }.join("\n\n")

    # # Step 5: Build the LLM prompt
    # prompt = <<~PROMPT

    #   You are a helpful AI counselor for PhysicsWallah students.

    #   Answer the following question based on the provided context. If the answer is not found in the context, say "I'm not sure about that" rather than guessing.

    #   Context:
    #   #{top_chunks}

    #   Question:
    #   #{query}

    #   Answer:
    # PROMPT
  
    # chat_log_key = SESSION_KEY.call(session.id)

    query = params[:query].to_s.strip
    return redirect_to root_path, alert: "Empty query" if query.blank?

    prompt = LlmPromptBuilder.new(query, session.id.to_s).build_prompt
    return redirect_to root_path, alert: "Could not generate prompt" if prompt.nil?

    session[:typing] = true
    # Append user message without response
    # chat_log_key = "SESSION_KEY:#{session.id}"

    chat_log_key = SESSION_KEY.call(session.id)

    chat_log = JSON.parse($redis.get(chat_log_key) || "[]")
    chat_log << { "query" => query, "response" => nil }
    $redis.set(chat_log_key, chat_log.to_json)


    # Set typing indicator in Redis
    $redis.set("chat_typing:#{session.id}", true)


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


  end

  private

  # def embed_query(text)
  #   uri = URI("http://localhost:8000/embed")
  #   req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
  #   req.body = { texts: [text] }.to_json
  #   res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
  #   JSON.parse(res.body)["embedding"]
  # end

  # def summarize_chat(session_id, chat_log)
  #   return if chat_log.blank?
  
  #   summary_prompt = <<~PROMPT
  #     Summarize the student's background, goals, and any personal information shared based on this chat.
  
  #     Chat Log:
  #     #{chat_log.map { |entry| "Student: #{entry["query"]}\nCounselor: #{entry["response"]}" }.join("\n\n")}
  
  #     Summary (keep it concise and factual):
  #   PROMPT
  
  #   summary = call_llm(summary_prompt, "phi3:mini").strip
  #   $redis.set(MEMORY_KEY.call(session_id), summary)
  #   Rails.logger.info "[MEMORY] Saved summary: #{summary}"
  #   summary
  # end
  
  

  def call_llm(prompt, model)
    uri = URI("http://localhost:11434/api/generate")
    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    req.body = { model: model, prompt: prompt, stream: false }.to_json
    res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
    JSON.parse(res.body)["response"]
  end
  
  # def rerank_chunks_by_title_match(chunks, query)
  #   keywords = query.downcase.scan(/\w+/).uniq

  #   chunks.sort_by do |chunk|
  #     title = chunk.title.to_s.downcase
  #     title_words = title.scan(/\w+/)
  #     score = (title_words & keywords).size

  #     # Boost if the full phrase appears
  #     score += 10 if title.include?(query.downcase)

  #     # Sort descending by score (higher is better), fallback to original order
  #     [-score, chunks.index(chunk)]
  #   end
  # end
end
