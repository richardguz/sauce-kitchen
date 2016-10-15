class Playlist < ApplicationRecord
	has_many :psongs
	has_many :songs, through: :psongs
	belongs_to :user
	validates :title, presence: true, length: {maximum: 50}
end
