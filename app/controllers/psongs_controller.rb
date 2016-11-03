class PsongsController < ApplicationController
	def promote
		user = current_user
		if (psong = Psong.find(params[:id]))
			if (psong.playlist.user == user)
				psong.update_column(:queued, true)
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

end
