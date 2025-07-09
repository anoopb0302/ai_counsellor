class AddGinIndexToChunksTags < ActiveRecord::Migration[7.0]
  def change
    add_index :chunks, :tags, using: :gin
  end
end