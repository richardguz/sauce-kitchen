class Playlist < ApplicationRecord

	has_many :likes
	has_many :likers, :through => :likes, :foreign_key => 'user_id'

	has_many :psongs
	has_many :songs, through: :psongs
	belongs_to :user
	validates :title, presence: true, length: {maximum: 50}
	#after_update :broadcast_changes

	def broadcast_changes
		BroadcastMessageJob.perform_later self.title
	end
end
