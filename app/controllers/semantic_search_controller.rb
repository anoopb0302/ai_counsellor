class SemanticSearchController < ApplicationController
  require 'net/http'
  require 'json'
  protect_from_forgery unless: -> { request.format.json? }

  def create
    query = params[:query].to_s.strip

    if query.blank?
      render json: { error: "Query cannot be blank" }, status: :bad_request
      return
    end

    # Embed the query
    vector = embed_query(query)

    # Search chunks by similarity
    results = Chunk.order(Arel.sql("embedding <-> '[#{vector.join(',')}]'")).limit(3)


    context = results.map { |c| "#{c.title}: #{c.text.truncate(150)}" }.join("\n\n")


    puts "Context for query '#{query}':"
    puts context

    prompt = <<~PROMPT
      You are a helpful academic counselor at Physics Wallah.
    
      Based on the following internal content from our platform:
    
      #{context}
    
      Answer this question for the student in a concise and informative manner:
    
      "#{query}"
    PROMPT
    
    # final_answer = call_ollama(prompt, 'mistral')
    # final_answer = call_ollama(prompt, 'phi3')
    # final_answer = call_ollama(prompt, 'gemma:2b')
    final_answer = call_ollama(prompt, 'phi3:mini')
    # final_answer = call_ollama(prompt, 'phi3-mini:latest')
    # final_answer = call_ollama(prompt, 'tinyllama')
    

    render json: {
      answer: final_answer,
      sources: results.map { |c| { title: c.title, section: c.section } }
    }
  end

  private

  def embed_query(text)
    uri = URI("http://localhost:8000/embed")
    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    req.body = { texts: [text] }.to_json

    res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }

    raise "Embedding failed: #{res.code} #{res.body}" unless res.code == "200"

    JSON.parse(res.body)["embedding"]
  end

  def call_ollama(prompt, model)
    uri = URI("http://localhost:11434/api/generate")
    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    req.body = {
      model: model,
      prompt: prompt,
      stream: false
    }.to_json
  
    res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
  
    raise "#{model.capitalize} failed: #{res.code} #{res.body}" unless res.code == "200"
  
    JSON.parse(res.body)["response"]
  end
  

end



