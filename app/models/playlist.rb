class Playlist < ApplicationRecord
	has_many :psongs
	has_many :songs, through: :psongs
	belongs_to :user
end
