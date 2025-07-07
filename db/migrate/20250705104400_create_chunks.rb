class CreateChunks < ActiveRecord::Migration[7.1]
  def change
    create_table :chunks do |t|
      t.string :title
      t.text :text
      t.string :section
      t.string :category
      t.string :course_type
      t.text :tags, array: true, default: []
      t.string :language

      t.timestamps
    end

    # Manually add the vector column after table creation
    execute <<-SQL
      ALTER TABLE chunks
      ADD COLUMN embedding vector(384);
    SQL
  end
end
