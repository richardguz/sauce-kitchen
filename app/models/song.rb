class Song < ApplicationRecord
	has_many :psongs
	has_many :playlists, through: :psongs
end
