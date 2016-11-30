module PlaylistsHelper
	def didUserVote(user, votes)
		votes.each do |vote|
			if vote.user_id == user.id
				return true
			end
		end
		return false
	end
end
