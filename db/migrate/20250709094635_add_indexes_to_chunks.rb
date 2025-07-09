class AddIndexesToChunks < ActiveRecord::Migration[7.0]
  def change
    add_index :chunks, :category
    add_index :chunks, :subcategory
  end
end