require 'json'

class PsongsController < ApplicationController
	def promote
		user = current_user
		if (psong = Psong.find(params[:id]))
			if (psong.playlist.user.id == user.id)
				psong.update_column(:queued, true)
				updateRedis(psong, true)
			else
				redirect_to root_url
			end
		else
			redirect_to root_url
		end
	end

	def demote
		user = current_user
		user = current_user
		if (psong = Psong.find(params[:id]))
			if (psong.playlist.user.id == user.id)
				psong.update_column(:queued, false)
				updateRedis(psong, false)
			else
				redirect_to root_url
			end
		else
			redirect_to root_url
		end
	end

	private
		def updateRedis(psong, value)
			if (plst = $redis.get(psong.playlist_id))
				plst = JSON.parse(plst)
				plst["psongs"].length.times do |i|
					if plst["psongs"][i]["id"] == psong.id
						plst["psongs"][i]["queued"] = value
					end
				end
				$redis.set(psong.playlist_id, plst.to_json)
			end
		end
end

class PlaylistCacheHelper
  def initialize(playlist)
    @id = playlist.id
    @title = playlist.title
    @created_at = playlist.created_at
    @updated_at = playlist.updated_at
    @private = playlist.private
    @playing = playlist.playing
    @latitude = playlist.latitude
    @longitude = playlist.longitude
    @psongs = createPsongs(playlist.psongs)
    @songs = createSongs(playlist.songs)
    @user = UserCacheHelper.new(playlist.user)
  end
  attr_reader :id
  attr_reader :title
  attr_reader :created_at
  attr_reader :updated_at
  attr_reader :private
  attr_reader :playing
  attr_reader :latitude
  attr_reader :longitude
  attr_reader :psongs
  attr_reader :songs
  attr_reader :user

  private
    def createPsongs(psongs)
      ret = []
      psongs.each do |psong|
        ps = PsongCacheHelper.new(psong)
        ret << ps
      end
      return ret
    end

    def createSongs(songs)
      ret = []
      songs.each do |song|
        sng = SongCacheHelper.new(song)
        ret << sng
      end
      return ret
    end
end

class UserCacheHelper
  def initialize(user)
    @id = user.id
    @username = user.username
    @email = user.email
    @password_digest = user.password_digest
    @created_at = user.created_at
    @updated_at = user.updated_at
    @avatar_file_name = user.avatar_file_name
    @avatar_content_type = user.avatar_content_type
    @avatar_file_size = user.avatar_file_size
    @avatar_updated_at = user.avatar_updated_at
  end

  attr_reader :id
  attr_reader :username
  attr_reader :email
  attr_reader :password_digest
  attr_reader :created_at
  attr_reader :updated_at
  attr_reader :avatar_file_name
  attr_reader :avatar_content_type
  attr_reader :avatar_file_size
  attr_reader :avatar_updated_at
end

class SongCacheHelper
  def initialize(song)
    @id = song.id
    @name = song.name
    @created_at = song.created_at
    @updated_at = song.updated_at
    @artist = song.artist
    @url = song.url
    @album = song.album
    @cover_art_url = song.cover_art_url
    @deezer_id = song.deezer_id
  end
  attr_reader :id
  attr_reader :name
  attr_reader :created_at
  attr_reader :updated_at
  attr_reader :artist
  attr_reader :url
  attr_reader :album
  attr_reader :cover_art_url
  attr_reader :deezer_id
end

class VoteCacheHelper
  def initialize(vote)
    @id = vote.id
    @created_at = vote.created_at
    @updated_at = vote.updated_at
    @user_id = vote.user_id
    @psong_id = vote.psong_id
  end

  attr_reader :id
  attr_reader :created_at
  attr_reader :updated_at
  attr_reader :user_id
  attr_reader :psong_id
end

class PsongCacheHelper
  def initialize(psong)
    @id = psong.id
    @playlist_id = psong.playlist_id
    @song_id = psong.song_id
    @created_at = psong.created_at
    @updated_at = psong.updated_at
    @upvotes = psong.upvotes
    @queued = psong.queued
    @played = psong.played
    @song = SongCacheHelper.new(psong.song)
    @votes = createVotes(psong.votes)
  end
  attr_reader :id
  attr_reader :playlist_id
  attr_reader :song_id
  attr_reader :created_at
  attr_reader :updated_at
  attr_reader :upvotes
  attr_reader :queued
  attr_reader :played
  attr_reader :song
  attr_reader :votes

  private
  def createVotes(votes)
    ret = []
    votes.each do |vote|
      vte = VoteCacheHelper.new(vote)
      ret << vte
    end
    return ret
  end
end
