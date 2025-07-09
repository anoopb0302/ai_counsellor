# rake chunks:import FILE=db/pw_general_chunk.json
# rake chunks:import FILE=db/pw_gate_chunk.json
# rake chunks:import FILE=db/pw_cuet_chunk.json
# rake chunks:import FILE=db/pw_board_chunk.json
# rake chunks:import FILE=db/pw_iitjee_chunk.json
# rake chunks:import FILE=db/pw_neet_chunk.json
# rake chunks:import FILE=db/pw_olympiad_chunk.json


require 'json'
require 'net/http'
require 'uri'
namespace :chunks do
  desc "Import and embed chunks from JSON"
  task import: :environment do
    file_path = ENV["FILE"]

    unless file_path && File.exist?(file_path)
      puts "File not found or not provided. Usage: rake chunks:import FILE=path/to/file.json"
      exit
    end

    puts "Loading file: #{file_path}"
    # Chunk.delete_all

    # file_path = Rails.root.join("db", "course_chunk_1.json")
    # unless File.exist?(file_path)
    #   puts "File not found: #{file_path}"
    #   exit
    # end

    # data = JSON.parse(File.read(file_path))



    data = JSON.parse(File.read(file_path))

    data.each_with_index do |chunk, i|
      puts "[#{i + 1}/#{data.size}] Embedding: #{chunk['title']}"

      uri = URI("http://localhost:8000/embed")
      req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')

      embedding_input = "#{chunk['title']} — #{chunk['text']}"
      req.body = { texts: [embedding_input] }.to_json
      # req.body = { texts: [chunk['text']] }.to_json

      res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }

      if res.code == "200"
        embedding = JSON.parse(res.body)["embedding"]
        embedding_sql_vector = "'[#{embedding.join(',')}]'::vector"

        tags_sql_array = "{" + chunk["tags"].map { |t| "\"#{t}\"" }.join(",") + "}"

        sql = <<~SQL
          INSERT INTO chunks
            (title, text, section, category, subcategory, course_type, tags, language, embedding, custom_id, created_at, updated_at)
          VALUES (
            #{ActiveRecord::Base.connection.quote(chunk["title"])},
            #{ActiveRecord::Base.connection.quote(chunk["text"])},
            #{ActiveRecord::Base.connection.quote(chunk["section"])},
            #{ActiveRecord::Base.connection.quote(chunk["category"])},
            #{ActiveRecord::Base.connection.quote(chunk["subcategory"])},
            #{ActiveRecord::Base.connection.quote(chunk["course_type"])},
            '#{tags_sql_array}',
            #{ActiveRecord::Base.connection.quote(chunk["language"])},
            #{embedding_sql_vector},
            #{ActiveRecord::Base.connection.quote(chunk["id"])},
            NOW(),
            NOW()
          )
        SQL

        ActiveRecord::Base.connection.execute(sql)
      else
        puts "Failed embedding for #{chunk['title']}: #{res.code} #{res.body}"
      end
    end

    puts "All chunks re-imported with fresh embeddings."
  end
end
