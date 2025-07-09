class AddIndexToChunksCustomId < ActiveRecord::Migration[7.1]
  def change
    add_index :chunks, :custom_id, unique: true
  end
end