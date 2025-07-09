class AddCategorySubcategoryIndexToChunks < ActiveRecord::Migration[7.0]
  def change
    add_index :chunks, [:category, :subcategory], name: "index_chunks_on_category_and_subcategory"
  end
end