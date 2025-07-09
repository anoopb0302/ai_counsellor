class AddLowercaseIndexesToChunks < ActiveRecord::Migration[7.0]
  def change
    add_index :chunks, "LOWER(language)", name: "index_chunks_on_lower_language"
    add_index :chunks, "LOWER(course_type)", name: "index_chunks_on_lower_course_type"
    add_index :chunks, "LOWER(section)", name: "index_chunks_on_lower_section"
  end
end