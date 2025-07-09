class LlmPromptBuilder
  def initialize(query)
    @query = query.strip
  end

  def build_prompt
    return nil if @query.blank?

    embedding = nil
    initial_chunks = []
    top_chunks = []

    total_time = Benchmark.realtime do
      embed_time = Benchmark.realtime do
        embedding = embed(@query)
      end
      Rails.logger.info "[TIMING] Embedding took #{embed_time.round(2)}s"

      search_time = Benchmark.realtime do
        initial_chunks = search_similar_chunks(embedding)
      end
      Rails.logger.info "[TIMING] Vector search took #{search_time.round(2)}s"

      rerank_time = Benchmark.realtime do
        top_chunks = rerank_chunks(initial_chunks).take(3)
      end
      Rails.logger.info "[TIMING] Reranking took #{rerank_time.round(2)}s"
    end

    context = top_chunks.map { |c| "#{c.title} — #{c.text}" }.join("\n\n")

    Rails.logger.info "[TIMING] Total prompt build time: #{total_time.round(2)}s"


    Rails.logger.info "context: #{context}"


    <<~PROMPT
      You are a helpful AI counselor for PhysicsWallah students.

      Answer the following question based on the provided context. If the answer is not found in the context, say "I'm not sure about that" rather than guessing.

      Context:
      #{context}

      Question:
      #{@query}

      Answer:
    PROMPT
  end

  private

  def embed(text)
    cache_key = "embed:#{Digest::SHA256.hexdigest(text)}"

    if Rails.cache.exist?(cache_key)
      Rails.logger.debug("[EMBED] Cache HIT for '#{text.truncate(40)}'")
    end

    Rails.cache.fetch(cache_key, expires_in: 12.hours) do
      Rails.logger.debug("[EMBED] Cache MISS for '#{text.truncate(40)}'")

      response = Net::HTTP.post(
        URI("http://localhost:8000/embed"),
        { texts: [text] }.to_json,
        "Content-Type" => "application/json"
      )

      raise "Embedding failed: #{response.body}" unless response.code == "200"

      JSON.parse(response.body)["embedding"]
    end
  end

  def search_similar_chunks(vector)
    query_down = @query.downcase
    filters = []

    # Category filter based on known list
    Chunk::CATEGORIES.each do |category|
      if query_down.include?(category.downcase)
        filters << ActiveRecord::Base.send(:sanitize_sql_array, ["LOWER(category) = ?", category.downcase])
      end
    end

    # Subcategory filter from DB
    matched_subcategories = Chunk.distinct.pluck(:subcategory).compact.select do |sc|
      query_down.include?(sc.to_s.downcase)
    end

    if matched_subcategories.any?
      filters << ActiveRecord::Base.send(:sanitize_sql_array, ["LOWER(subcategory) IN (?)", matched_subcategories.map(&:downcase)])
    end

    # Apply filters
    chunks = if filters.any?
      Chunk.where(filters.join(" AND "))
    else
      Chunk.all
    end

    chunks
      .order(Arel.sql("embedding <-> '[#{vector.join(',')}]'"))
      .limit(20)
  end

  def rerank_chunks(chunks)
    query_down = @query.downcase
    keywords = query_down.scan(/\w+/)

    chunks.map do |chunk|
      score = 0

      score += 2 if chunk.title.to_s.downcase.include?(query_down)
      score += 1 if chunk.text.to_s.downcase.include?(query_down)

      score += 1 if query_down.include?(chunk.category.to_s.downcase)
      score += 1 if query_down.include?(chunk.subcategory.to_s.downcase)

      score += 1 if chunk.tags.any? { |tag| keywords.include?(tag.downcase) }

      Rails.logger.info "\e[32m[RERANK] Title: #{chunk.title}, Score: #{score}\e[0m"

      [chunk, score]
    end.sort_by { |_, score| -score }.map(&:first)
  end
end
