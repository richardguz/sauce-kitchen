class Psong < ApplicationRecord
	belongs_to :song
	belongs_to :playlist
	has_many :votes, dependent: :destroy
  has_many :upvoted_users, through: :votes, source: :user
end
