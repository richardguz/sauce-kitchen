require 'json'

class PsongsController < ApplicationController
	def promote
		user = current_user
		if (playlist = JSON.parse($redis.get(params[:playlist_id])))
			playlist["psongs"].each do |song|
				if song["id"].to_i == params[:psong_id].to_i
					song["queued"] = true
					$redis.set(params[:playlist_id], playlist.to_json)
					break
				end
			end
		elsif (psong = Psong.find(params[:psong_id]))
			if (psong.playlist.user == user)
				psong.update_column(:queued, true)
				if (playlist = $redis.get(psong.playlist_id))
					playlist = JSON.parse(playlist)
					playlist["psongs"].each do |song|
						puts song["id"]
						puts params[:psong_id]
						if song["id"].to_i == params[:psong_id].to_i
							puts "YA"
							song["queued"] = true
							$redis.set(psong.playlist_id, playlist.to_json)
							break
						end
					end
				end
			else
				redirect_to root_url
			end
		else
			redirect_to root_url
		end
	end

	def demote
		user = current_user
		if (playlist = JSON.parse($redis.get(params[:playlist_id])))
			playlist["psongs"].each do |song|
				if song["id"].to_i == params[:psong_id].to_i
					song["queued"] = false
					$redis.set(params[:playlist_id], playlist.to_json)
					break
				end
			end
		elsif (psong = Psong.find(params[:psong_id]))
			if (psong.playlist.user == user)
				psong.update_column(:queued, true)
				if (playlist = $redis.get(psong.playlist_id))
					playlist = JSON.parse(playlist)
					playlist["psongs"].each do |song|
						puts song["id"]
						puts params[:psong_id]
						if song["id"].to_i == params[:psong_id].to_i
							puts "YA"
							song["queued"] = false
							$redis.set(psong.playlist_id, playlist.to_json)
							break
						end
					end
				end
			else
				redirect_to root_url
			end
		else
			redirect_to root_url
		end
	end
end
