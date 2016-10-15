class Playlist < ApplicationRecord
	has_many :psongs
	has_many :songs, through: :psongs
end
