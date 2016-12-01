module PlaylistsHelper
	# Show playlist page
	def cache_key_for_psong(psong)
		"psong-#{psong.id}-#{psong.updated_at}"
	end
	def cache_key_for_psong_waiting(psong)
		"psongwaiting-#{psong.id}-#{psong.updated_at}"
	end
	def cache_key_for_user_player(user)
		"userplayer-#{user.id}-#{user.updated_at}"
	end
	def cache_key_for_playlist_queued
		max_stale = @playlist.psongs.max_by(&:updated_at).updated_at
 		"playlistqueued-#{@playlist.id}-#{max_stale}" 
	end
	def cache_key_for_playlist_waiting
		max_stale = @playlist.psongs.max_by(&:updated_at).updated_at
 		"playlistwaiting-#{@playlist.id}-#{max_stale}" 
	end

	#User Playlist page
	def cache_key_for_user_playlists(playlist)
		"userplaylist-#{playlist.id}-#{playlist.updated_at}"
	end

	def cache_key_for_user_playlists_table
		max_stale = @playlists.max_by(&:updated_at).updated_at
 		"userplaylisttable-#{@user.id}-#{max_stale}" 
	end
end
