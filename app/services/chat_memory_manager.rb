# app/services/chat_memory_manager.rb
class ChatMemoryManager
  def initialize(session_id)
    @session_id = session_id
    @chat_log_key = "chat_log:#{session_id}"
    @memory_key = "chat_memory:#{session_id}"
    @facts_key = "chat_facts:#{session_id}"
  end

  # def summarize_and_store
  #   chat_log = JSON.parse($redis.get(@chat_log_key) || "[]")


  #   summary_prompt = <<~PROMPT
  #     Summarize the student's key facts and background based on this conversation. Keep it brief.

  #     Chat:
  #     #{chat_log.last(2).reject { |h| h["response"].nil? }.map { |c| "Student: #{c['query']}\nCounselor: #{c['response']}" }.join("\n")}

  #     Summary:
  #   PROMPT

  #   summary = call_llm(summary_prompt).strip
  #   $redis.set(@memory_key, summary)
  #   summary
  # end

  # def summarize_and_store
  #   chat_log = JSON.parse($redis.get(@chat_log_key) || "[]")
  #   return if chat_log.empty?

  #   summary = extract_summary(chat_log)
  #   $redis.set(@summary_key, summary)

  #   facts = extract_structured_facts(chat_log)
  #   $redis.set(@facts_key, facts.to_json) if facts
  # end

  def fetch
    puts "Fetching memory for session #{@session_id}"
    puts "Memory key: #{@memory_key}"
    return $redis.get(@memory_key), $redis.get(@facts_key)
  end

  private

#   def extract_summary(chat_log)
#     summary_prompt = <<~PROMPT
#       Summarize the student's background and goals in 2–3 lines based on this chat.

#       Chat:
#       #{chat_log.last(1).map { |c| "Student: #{c['query']}\nCounselor: #{c['response']}" }.join("\n")}

#       Summary:
#     PROMPT

#     call_llm(summary_prompt)
#   end

#   def extract_structured_facts(chat_log)
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
#         "language": "Preferred language if mentioned"
#         "background": "Brief background if mentioned",
#         "other": "Any other relevant facts"
#       }

#       Only include fields that were actually mentioned.

#       Chat:
#       #{chat_log.last(1).map { |c| "Student: #{c['query']}\nCounselor: #{c['response']}" }.join("\n")}

#       JSON:
#     PROMPT

#     raw = call_llm(extraction_prompt)
#     JSON.parse(raw) rescue nil
#   end

#   def call_llm(prompt)
#     uri = URI("http://localhost:11434/api/generate")
#     req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
#     req.body = { model: 'phi3:mini', prompt: prompt, stream: false }.to_json
#     res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
#     JSON.parse(res.body)["response"]
#   end
# end
