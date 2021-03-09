class Product < ApplicationRecord
  has_many :line_items
  validates :title, :description, :image_url, presence: true
  validates :title, uniqueness: true
end
