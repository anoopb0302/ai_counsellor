class AddSubcategoryAndCustomIdToChunks < ActiveRecord::Migration[7.1]
  def change
    add_column :chunks, :subcategory, :string
    add_column :chunks, :custom_id, :string
  end
end
