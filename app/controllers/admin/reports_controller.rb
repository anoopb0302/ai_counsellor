class Admin::ReportsController < ApplicationController
  def index
    keys = $redis.keys("chat_log:*")
    session_ids = keys.map { |k| k.split(":").last }

    @filters = {
      name: params[:name].to_s.strip,
      goal: params[:goal].presence,
      sentiment: params[:sentiment].presence
    }

    @sessions = session_ids.map do |sid|
      {
        id: sid,
        facts: safe_parse_json($redis.get("chat_facts:#{sid}")),
        sentiment: safe_parse_json($redis.get("chat_sentiment:#{sid}")),
        relevance: safe_parse_json($redis.get("chat_relevance:#{sid}")),
        summary: $redis.get("chat_memory:#{sid}")
      }
    end

    @sessions = @sessions.select do |s|
      facts = s[:facts]
      sentiment = s[:sentiment] || {}
      relevance = s[:relevance] || {}
      matches_name = @filters[:name].blank? || facts["name"].to_s.downcase.include?(@filters[:name].downcase)
      matches_goal = @filters[:goal].blank? || facts["goal"].to_s.downcase.include?(@filters[:goal].downcase)
      matches_sentiment = @filters[:sentiment].blank? || sentiment["label"].to_s == @filters[:sentiment]
      matches_relevance = @filters[:relevance].blank? || sentiment["relevance"].to_s == @filters[:relevance]

      matches_name && matches_goal && matches_sentiment && matches_relevance
    end



  end

  def show
    session_id = params[:id]
    @summary = $redis.get("chat_memory:#{session_id}")

    @sentiment = safe_parse_json($redis.get("chat_sentiment:#{session_id}" ) || "{}")

    @chat_log = JSON.parse($redis.get("chat_log:#{session_id}") || "[]")
  end

  private

  def safe_parse_json(str)
    return {} unless str.is_a?(String) && str.strip.present?
    json_part = str[/\{.*?\}/m]
    JSON.parse(json_part)
  rescue JSON::ParserError
    { "raw" => str.to_s.truncate(60) }
  end
  
end
