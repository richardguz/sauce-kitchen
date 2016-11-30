class PsongsController < ApplicationController
	def promote
		user = current_user
		if (psong = Psong.find(params[:id]))
			if (psong.playlist.user == user)
				psong.update_column(:queued, true)
				# if (plst = $redis.get(psong.playlist_id))
			else
				redirect_to root_url
			end
		else
			redirect_to root_url
		end
	end

	def demote
		user = current_user
		if (psong = Psong.find(params[:id]))
			if (psong.playlist.user == user)
				psong.update_column(:queued, false)
			else
				redirect_to root_url
			end
		else
			redirect_to root_url
		end
	end

	# private
	# 	def updateRedis(psong, value)
	# 		if (plst = $redis.get(psong.playlist_id))
	# 			plst = JSON.parse(plst)
	# 			plst["psongs"].length.times do |i|

	# 			end
end
