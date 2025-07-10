# app/controllers/admin/reports_controller.rb
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
        facts: JSON.parse($redis.get("chat_facts:#{sid}") || "{}"),
        sentiment: $redis.get("chat_sentiment:#{sid}")
      }
    end
  
    # Apply filters
    @sessions = @sessions.select do |s|
      facts = s[:facts]
      sentiment = JSON.parse(s[:sentiment] || "{}")
  
      matches_name = @filters[:name].blank? || facts["name"].to_s.downcase.include?(@filters[:name].downcase)
      matches_goal = @filters[:goal].blank? || facts["goal"].to_s.downcase.include?(@filters[:goal].downcase)
      matches_sentiment = @filters[:sentiment].blank? || sentiment["label"].to_s == @filters[:sentiment]
  
      matches_name && matches_goal && matches_sentiment
    end
  end
  

  def show
    session_id = params[:id]
    @summary = $redis.get("chat_memory:#{session_id}")
    @chat_log = JSON.parse($redis.get("chat_log:#{session_id}") || "[]")
  end
end
