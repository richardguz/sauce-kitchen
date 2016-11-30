module PlaylistsHelper
	def cache_key_for_psong(psong)
		"psong-#{psong.id}-#{psong.updated_at}"
	end
	def cache_key_for_psong_waiting(psong)
		"psongwaiting-#{psong.id}-#{psong.updated_at}"
	end
	def cache_key_for_user_player(user)
		"userplayer-#{user.id}-#{user.updated_at}"
	end
end
