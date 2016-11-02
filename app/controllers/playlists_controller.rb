require 'net/http'
require 'json'

class PlaylistsController < ApplicationController
  def show
  	if (@playlist = Playlist.find_by(id: params[:id]))
      @likes = Like.where(:playlist_id => params[:id]).count
      @isLiked = false
      if (Like.where(user_id: session[:user_id], playlist_id: params[:id]).count != 0)
        @isLiked = true
      end
      @isPlaying = @playlist.playing
      @user = current_user
      @playlist_owner = @playlist.user
      if @playlist.private && @user != @playlist_owner
        flash[:info] = "The playlist you tried to access is private"
        redirect_to root_url
      end
    else
      flash[:warning] = "The playlist you tried to access no longer exists"
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
  end

  def poll
    playlist = Playlist.find_by(id: params[:id])
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
          render :json => nil 
        else
          #if song found on a queue
          psong.update(played: true)
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
    if (playlist = Playlist.find(params[:id]))
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
      if !(isOwner(current_user, playlist))
        psong.update_column(:queued, false)
    end
    else
      puts json_response
      puts json_response['contributors']
      song = playlist.songs.create(name: json_response['title'], artist: json_response['contributors'].first['name'], deezer_id: song_id)
      psong = Psong.find_by(playlist_id: playlist_id, song_id: song.id)
      if !(isOwner(current_user, playlist))
        psong.update_column(:queued, false)
      end
    end
  end

  def like
    if (@playlist = Playlist.find_by(id: params[:id]))
      if (like_instance = Like.where(playlist_id: params[:id], user_id: session[:user_id])[0])
        like_instance.destroy
        n_likes = Like.where(:playlist_id => params[:id]).count
        ret = {
          :url => ActionController::Base.helpers.asset_path("clearheart.png"),
          :n_likes => n_likes
        }
        render :json => ret
      else
        Like.create(user_id: session[:user_id], playlist_id: params[:id])
        n_likes = Like.where(:playlist_id => params[:id]).count
        ret = {
          :url => ActionController::Base.helpers.asset_path("redheart.png"),
          :n_likes => n_likes
        }
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
      return user.playlists.exists?(playlist.id)
    end

    def deezer_song(id)
      url = "http://api.deezer.com/track/#{id}&output=json"
      uri = URI(url)
      response = Net::HTTP.get(uri)
      return JSON.parse(response, symbolize_keys: true)
    end
end
