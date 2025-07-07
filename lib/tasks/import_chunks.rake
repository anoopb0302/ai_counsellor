require 'json'
require 'net/http'
require 'uri'

namespace :chunks do
  desc "Import and embed chunks from JSON"
  task import: :environment do
    file_path = Rails.root.join("db", "course_chunk_1.json")
    unless File.exist?(file_path)
      puts "File not found: #{file_path}"
      exit
    end

    data = JSON.parse(File.read(file_path))

    data.each_with_index do |chunk, i|
      puts "[#{i+1}/#{data.size}] Embedding: #{chunk['title']}"

      # Call the local embedding server
      uri = URI("http://localhost:8000/embed")
      req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      req.body = { texts: [chunk['text']] }.to_json

      res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }

      if res.code == "200"
        embedding = JSON.parse(res.body)["embedding"]
        # embedding_sql_vector = "(#{embedding.join(',')})"
        # embedding_sql_vector = "vector[#{embedding.join(',')}]"
        embedding_sql_vector = "'[#{embedding.join(',')}]'::vector"

        tags_sql_array = "{" + chunk["tags"].map { |t| "\"#{t}\"" }.join(",") + "}"

        sql = <<~SQL
          INSERT INTO chunks
            (title, text, section, category, course_type, tags, language, embedding, created_at, updated_at)
          VALUES (
            #{ActiveRecord::Base.connection.quote(chunk["title"])},
            #{ActiveRecord::Base.connection.quote(chunk["text"])},
            #{ActiveRecord::Base.connection.quote(chunk["section"])},
            #{ActiveRecord::Base.connection.quote(chunk["category"])},
            #{ActiveRecord::Base.connection.quote(chunk["course_type"])},
            '#{tags_sql_array}',
            #{ActiveRecord::Base.connection.quote(chunk["language"])},
            #{embedding_sql_vector},
            NOW(),
            NOW()
          )
        SQL

        ActiveRecord::Base.connection.execute(sql)
      else
        puts "Failed embedding: #{res.code} #{res.body}"
      end
    end

    puts "All chunks imported and embedded."
  end
end
