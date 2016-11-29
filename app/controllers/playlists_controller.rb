require 'net/http'
require 'json'

class PlaylistsController < ApplicationController
  def show
    if (@playlist = $redis.get(params[:id]))
      @playlist = JSON.parse(@playlist)
      puts "got from redis"
  	elsif (@playlist = Playlist.find_by(id: params[:id]))
      puts "print got from db, put into redis"
      d = {
            id: @playlist.id, 
            title: @playlist.title,
            user_id: @playlist.user_id,
            created_at: @playlist.created_at,
            updated_at: @playlist.updated_at,
            private: @playlist.private,
            playing: @playlist.playing,
            psongs: @playlist.psongs,
            songs: @playlist.songs
          }
        d = d.to_json
        d = JSON.parse(d)
        puts d
        d["psongs"].length.times do |i|
          d["psongs"][i][:song] = JSON.parse(@playlist.psongs[i].song.to_json)
          d["psongs"][i][:votes] = JSON.parse(@playlist.psongs[i].votes.to_json)
        end
        @playlist = d
      $redis.set(params[:id], d.to_json)
    else
      # TODO: Doesn't flash warning
      flash[:warning] = "The playlist you tried to access no longer exists"
      return redirect_to root_url
    end
    @likes = Like.where(:playlist_id => params[:id]).count
    @isLiked = false
    if (Like.where(user_id: session[:user_id], playlist_id: params[:id]).count != 0)
      @isLiked = true
    end
    @isPlaying = @playlist["playing"]
    @user = current_user
    @playlist_owner = @playlist["user_id"]

    if @playlist["private"] && @user != @playlist_owner
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
  end

  def poll
    if playlist = JSON.parse($redis.get(params[:id]))
      psongs = playlist["psongs"]
      playlist[:owner] = playlist["user_id"]
      playlist["psongs"].each do |psong|
        psong["voted_user_ids"] = []
        psong["votes"].each do |vote|
          psong["voted_user_ids"] = psong["voted_user_ids"] << vote["user_id"]
        end
      end
      data = playlist.to_json
    elsif playlist = Playlist.find_by(id: params[:id])
      psongs = playlist.psongs
      psong_obj = psongs.map do |psong|
        votes = psong.votes
        voted_user_ids = []
        votes.each do |vote|
          voted_user_ids << vote.user_id
        end
      end
      data = playlist ? { :title => playlist.title, 
                        :owner => playlist.user.id, 
                        :psongs => psong_obj,
                        :songs => playlist.songs } : nil
                        #do something like below to get the votes passed in
    end
    render :json => data
  end

  def next_song
    puts("HEEEY 1")
    if (playlist = Playlist.find_by(id: params[:id]))
      #check if the requester is owner of playlist
      puts("HEEEY 2")
      if (isOwner(current_user, playlist))
        #check for songs on queued list (grabs one with most upvotes)
        puts("HEEEY 3")
        psong = playlist ? playlist.psongs.where(played: false).where(queued: true).order(:upvotes).last : nil
        if (!psong)
          puts("HEEEY 4")
          #if no songs left on the queue
          psong = playlist.psongs.where(played: false).where(queued: false).order(:upvotes).last
        end
        if (!psong)
          puts("HEEEY 5")
          #if no songs in waiting queue
          render :json => nil 
        else
          puts("HEEEY 6")
          #if song found on a queue
          psong.update(played: true)
          render :json => psong.song
        end
      else
        puts("HEEEY 7")
        redirect_to playlist
      end
    else
      puts("HEEEY 8")
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
    # /playlists/13/upvote/7
    id = params[:id]
    psongid = params[:psongid]
    if (playlist = JSON.parse($redis.get(id)))
      song = nil
      playlist["psongs"].length.times do |i|
        if (playlist["psongs"][i]["id"] == psongid.to_i)
          song = playlist["psongs"][i]
          song["upvotes"] = song["upvotes"] + 1
          playlist["psongs"][i] = song
          playlist["psongs"][i]["votes"] << {"id"=>-1, "created_at"=>"N/A", "updated_at"=>"N/A", "user_id"=>session[:user_id], "psong_id"=>psongid}
          @playlist = playlist
          $redis.set(id, playlist.to_json)
          break
        end
      end
    elsif (playlist = Playlist.find(params[id]))
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
    else
      puts json_response
      puts json_response['contributors']
      song = playlist.songs.create(name: json_response['title'], artist: json_response['contributors'].first['name'], deezer_id: song_id)
      psong = Psong.find_by(playlist_id: playlist_id, song_id: song.id)
      if (!is_logged_in || !isOwner(current_user, playlist))
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
      # return user.playlists.exists?(playlist["id"])
      return user["id"] == playlist["user_id"]
    end

    def deezer_song(id)
      url = "http://api.deezer.com/track/#{id}&output=json"
      uri = URI(url)
      response = Net::HTTP.get(uri)
      return JSON.parse(response, symbolize_keys: true)
    end
end
