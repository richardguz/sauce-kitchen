require 'net/http'
require 'json'

class PlaylistsController < ApplicationController
  def show
    @isLiked = false
    @likes = nil
    uid = session[:user_id]
    if (plst = $redis.get(params[:id]))
      plst = JSON.parse(plst)
      @playlist = PlaylistDBHelper.new(plst)
      @likes = @playlist.likes.length
      @playlist.likes.each do |like|
        if uid == like.user_id
          @isLiked = true
        end
      end
  	elsif (@playlist = Playlist.find_by(id: params[:id]))
      c = PlaylistCacheHelper.new(@playlist)
      $redis.set(params[:id], c.to_json)
      @likes = Like.where(:playlist_id => params[:id]).count
      @isLiked = false
      if (Like.where(user_id: session[:user_id], playlist_id: params[:id]).count != 0)
        @isLiked = true
      end
    else
      flash[:warning] = "The playlist you tried to access no longer exists"
      redirect_to root_url
    end
    @isPlaying = @playlist.playing
    @user = current_user
    @playlist_owner = @playlist.user
    if @playlist.private && @user != @playlist_owner
      flash[:info] = "The playlist you tried to access is private"
      redirect_to root_url
    end
  end

  def show_user_playlists
    @playlists = Playlist.where(user_id: params[:id])
    @user = User.find_by(id: params[:id])
    render 'playlists/user_playlists'
  end

  def show_liked_playlists
    @user = User.find_by(id: params[:id])
    render 'playlists/user_likes'
  end

  def new
  	@playlist = Playlist.new
  end

  def create
  	@playlist = Playlist.new(playlist_params)
  	user = User.find_by(id: session[:user_id])
  	@playlist.user = user
  	if @playlist.save
  		redirect_to @playlist
  	else
  		flash.now[:danger] = "Error creating playlist"
  		render 'playlists/new'
  	end
  end

  def update
    @playlist = Playlist.find_by(id: params[:id])
    @playlist.title = params[:playlist][:title]
    @playlist.save
    redirect_to @playlist
  end

  def updatePlaying
    value = params[:value]
    @playlist = Playlist.find_by(id: params[:id])
    @playlist.update_attribute(:playing, value)
    if (plst = $redis.get(params[:id]))
      plst = JSON.parse(plst)
      plst["playing"] = value
      $redis.set(params[:id], plst.to_json)
    end 
  end

  def poll
    if (plst = $redis.get(params[:id]))
      plst = JSON.parse(plst)
      playlist = PlaylistDBHelper.new(plst)
    else
      playlist = Playlist.find_by(id: params[:id])
    end
    psongs = playlist.psongs
    psong_obj = psongs.map do |psong|
      votes = psong.votes
      voted_user_ids = []
      votes.each do |vote|
        voted_user_ids << vote.user_id
      end
      {
        :psong => psong,
        :voted_user_ids => voted_user_ids
      }
    end
    data = playlist ? { :title => playlist.title, 
                        :owner => playlist.user.id, 
                        :psongs => psong_obj,
                        :songs => playlist.songs } : nil
                        #do something like below to get the votes passed in
    render :json => data
  end

  def next_song
    if (playlist = Playlist.find_by(id: params[:id]))
      #check if the requester is owner of playlist
      if (isOwner(current_user, playlist))
        #check for songs on queued list (grabs one with most upvotes)
        psong = playlist ? playlist.psongs.where(played: false).where(queued: true).order(:upvotes).last : nil
        if (!psong)
          #if no songs left on the queue
          psong = playlist.psongs.where(played: false).where(queued: false).order(:upvotes).last
        end
        if (!psong)
          #if no songs in waiting queue
          if ($redis.get(params[:id]))
            plst = PlaylistCacheHelper.new(playlist)
            $redis.set(params[:id], plst.to_json)
          end
          render :json => nil 
        else
          #if song found on a queue
          psong.update(played: true)
          if ($redis.get(params[:id]))
            plst = PlaylistCacheHelper.new(playlist)
            $redis.set(params[:id], plst.to_json)
          end
          render :json => psong.song
        end
      else
        redirect_to playlist
      end
    else
      redirect_to root_url
    end

  end

  def reset_play_history
    if (playlist = Playlist.find_by(id: params[:id]))
      if (isOwner(current_user, playlist))
        #reset each psong played value to false
        playlist.psongs.update_all(played: false)
      else
        redirect_to playlist
      end
    else 
      redirect_to root_url 
    end

  end

  def upvote
    #does playlist exist?
    if (playlist = $redis.get(params[:id]))
      vote = {
        created_at: "N/A",
        updated_at: "N/A",
        id: -1,
        user_id: current_user.id,
        psong_id: params[:psongid]
      }
      playlist = JSON.parse(playlist)
      playlist["psongs"].each do |psong|
        if psong["id"] == params[:psongid].to_i
          psong["votes"] << vote
          psong["upvotes"] += 1
          break
        end
      end
      $redis.set(params[:id], playlist.to_json)
    elsif (playlist = Playlist.find(params[:id]))
      psong = Psong.find(params[:psongid])
      if (psong.votes.create(user_id: current_user.id))
        psong.update(upvotes: 1 + psong.upvotes)
      end
    else
      redirect_to root_url 
    end
  end

  def add_song
    song_id = params[:sid]
    playlist_id = params[:pid]
    json_response = deezer_song(song_id)    
    playlist = Playlist.find(playlist_id)

    if (song = Song.find_by(deezer_id: song_id))
      psong = Psong.create(song_id: song.id, playlist_id: playlist_id)
      if (!is_logged_in || !isOwner(current_user, playlist))
        psong.update_column(:queued, false)
      end
      if (plst = $redis.get(playlist_id))
        plst = JSON.parse(plst)
        playa = PlaylistDBHelper.new(plst)
        playa.songs << SongCacheHelper.new(song)
        playa.psongs << PsongCacheHelper.new(psong)
        $redis.set(playlist_id, playa.to_json)
      end
    else
      song = playlist.songs.create(name: json_response['title'], artist: json_response['contributors'].first['name'], deezer_id: song_id)
      psong = Psong.find_by(playlist_id: playlist_id, song_id: song.id)
      if (!is_logged_in || !isOwner(current_user, playlist))
        psong.update_column(:queued, false)
      end
      if (plst = $redis.get(playlist_id))
        plst = JSON.parse(plst)
        playa = PlaylistDBHelper.new(plst)
        playa.songs << SongCacheHelper.new(song)
        playa.psongs << PsongCacheHelper.new(psong)
        $redis.set(playlist_id, playa.to_json)
      end
    end
  end

  def like
    if (@playlist = $redis.get(params[:id]))
      @playlist = JSON.parse(@playlist)
      del = false
      n_likes = @playlist["likes"].length
      n_likes.times do |i|
        if @playlist["likes"][i]["user_id"] == session[:user_id]
          @playlist["likes"].delete_at(i)
          del = true
          n_likes -= 1
          break
        end
      end
      if !del
        like = {
          created_at: "N/A",
          updated_at: "N/A",
          id: -1,
          playlist_id: params[:id],
          user_id: session[:user_id]
        }
        n_likes += 1
        @playlist["likes"] << like
        ur = ActionController::Base.helpers.asset_path("redheart.png")
      else
        ur = ActionController::Base.helpers.asset_path("clearheart.png")
      end
      ret = {
          :url => ur,
          :n_likes => n_likes
        }
      $redis.set(params[:id], @playlist.to_json)
      render :json => ret
    elsif (@playlist = Playlist.find_by(id: params[:id]))
      if (like_instance = Like.where(playlist_id: params[:id], user_id: session[:user_id])[0])
        like_instance.destroy
        n_likes = Like.where(:playlist_id => params[:id]).count
        ret = {
          :url => ActionController::Base.helpers.asset_path("clearheart.png"),
          :n_likes => n_likes
        }
        if (plst = $redis.get(params[:id]))
          plst = JSON.parse(plst)
          plst["likes"].length.times do |i|
            if plst["likes"][i]["user_id"] == session[:user_id]
              plst["likes"].delete_at(i)
              break
            end
          end
          $redis.set(params[:id], plst.to_json)
        end
        render :json => ret
      else
        lke = Like.create(user_id: session[:user_id], playlist_id: params[:id])
        n_likes = Like.where(:playlist_id => params[:id]).count
        ret = {
          :url => ActionController::Base.helpers.asset_path("redheart.png"),
          :n_likes => n_likes
        }
        if (plst = $redis.get(params[:id]))
          plst = JSON.parse(plst)
          plst["likes"] << LikeCacheHelper.new(lke)
          $redis.set(params[:id], plst.to_json)
        end
        render :json => ret
      end
    else
      flash[:warning] = "The playlist you tried to like no longer exists"
      redirect_to root_url
    end
  end

  private
  	def playlist_params
      params.require(:playlist).permit(:title, :songs, :longitude, :latitude, :private)
  	end

    def isOwner(user, playlist)
      return user.id == playlist.user_id
    end

    def deezer_song(id)
      url = "http://api.deezer.com/track/#{id}&output=json"
      uri = URI(url)
      response = Net::HTTP.get(uri)
      return JSON.parse(response, symbolize_keys: true)
    end

    def didLike(user_id, like_user_id)
      return user_id == like_user_id
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
    @likes = createLikes(playlist.likes)
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
  attr_reader :likes

  def createLikes(likes)
    ret = []
    likes.each do |like|
      lke = LikeDBHelper.new(like)
      ret << lke
    end
    return ret
  end

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

class LikeCacheHelper
  def initialize(like)
    @id = like.id
    @created_at = like.created_at
    @updated_at = like.updated_at
    @user_id = like.user_id
    @playlist_id = like.playlist_id
  end

  attr_reader :id
  attr_reader :created_at
  attr_reader :updated_at
  attr_reader :user_id
  attr_reader :playlist_id
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



#############################################
#############################################
#############################################
#############################################
#############################################
#############################################

class PlaylistDBHelper
  def initialize(playlist)
    @id = playlist["id"]
    @title = playlist["title"]
    @created_at = playlist["created_at"]
    @updated_at = playlist["updated_at"]
    @private = playlist["private"]
    @playing = playlist["playing"]
    @latitude = playlist["latitude"]
    @longitude = playlist["longitude"]
    @psongs = createPsongs(playlist["psongs"])
    @songs = createSongs(playlist["songs"])
    @user = UserDBHelper.new(playlist["user"])
    @likes = createLikes(playlist["likes"])
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
  attr_reader :likes

  def createLikes(likes)
    ret = []
    likes.each do |like|
      lke = LikeDBHelper.new(like)
      ret << lke
    end
    return ret
  end

  private
    def createPsongs(psongs)
      ret = []
      psongs.each do |psong|
        ps = PsongDBHelper.new(psong)
        ret << ps
      end
      return ret
    end

    def createSongs(songs)
      ret = []
      songs.each do |song|
        sng = SongDBHelper.new(song)
        ret << sng
      end
      return ret
    end
end

class LikeDBHelper
  def initialize(like)
    @id = like["id"]
    @created_at = like["created_at"]
    @updated_at = like["updated_at"]
    @user_id = like["user_id"]
    @playlist_id = like["playlist_id"]
  end

  attr_reader :id
  attr_reader :created_at
  attr_reader :updated_at
  attr_reader :user_id
  attr_reader :playlist_id
end

class UserDBHelper
  def initialize(user)
    @id = user["id"]
    @username = user["username"]
    @email = user["email"]
    @password_digest = user["password_digest"]
    @created_at = user["created_at"]
    @updated_at = user["updated_at"]
    @avatar_file_name = user["avatar_file_name"]
    @avatar_content_type = user["avatar_content_type"]
    @avatar_file_size = user["avatar_file_size"]
    @avatar_updated_at = user["avatar_updated_at"]
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

class SongDBHelper
  def initialize(song)
    @id = song["id"]
    @name = song["name"]
    @created_at = song["created_at"]
    @updated_at = song["updated_at"]
    @artist = song["artist"]
    @url = song["url"]
    @album = song["album"]
    @cover_art_url = song["cover_art_url"]
    @deezer_id = song["deezer_id"]
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

class VoteDBHelper
  def initialize(vote)
    @id = vote["id"]
    @created_at = vote["created_at"]
    @updated_at = vote["updated_at"]
    @user_id = vote["user_id"]
    @psong_id = vote["psong_id"]
  end

  attr_reader :id
  attr_reader :created_at
  attr_reader :updated_at
  attr_reader :user_id
  attr_reader :psong_id
end

class PsongDBHelper
  def initialize(psong)
    @id = psong["id"]
    @playlist_id = psong["playlist_id"]
    @song_id = psong["song_id"]
    @created_at = psong["created_at"]
    @updated_at = psong["updated_at"]
    @upvotes = psong["upvotes"]
    @queued = psong["queued"]
    @played = psong["played"]
    @song = SongDBHelper.new(psong["song"])
    @votes = createVotes(psong["votes"])
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
      vte = VoteDBHelper.new(vote)
      ret << vte
    end
    return ret
  end
end
