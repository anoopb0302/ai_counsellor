class Chunk < ApplicationRecord
  # Validations
  validates :title, :text, :category, :course_type, :language, presence: true
  validates :custom_id, uniqueness: true, allow_nil: true

  # Optional: validate tags is an array
  validate :tags_must_be_array

  # Scopes
  scope :by_category, ->(cat) { where(category: cat) }
  scope :by_subcategory, ->(subcat) { where(subcategory: subcat) }
  scope :by_language, ->(lang) { where(language: lang) }

  private

  def tags_must_be_array
    errors.add(:tags, "must be an array") unless tags.is_a?(Array)
  end
end
