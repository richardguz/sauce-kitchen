module PlaylistsHelper
	def did_user_upvote?(user, psong)
		psong["votes"].each do |vote|
			if vote["user_id"] == user.id
				return true
			end
		end
		false
	end
end