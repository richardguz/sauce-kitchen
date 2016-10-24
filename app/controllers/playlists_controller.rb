class PlaylistsController < ApplicationController
  def show
  	if (@playlist = Playlist.find_by(id: params[:id]))
      @likes = Like.where(:playlist_id => params[:id]).count
      @isLiked = false
      if (Like.where(user_id: session[:user_id], playlist_id: params[:id]).count != 0)
        @isLiked = true
      end
      puts "eyyy"
      puts Like.where(user_id: session[:user_id], playlist_id: params[:id])
      puts "LIKES"
      puts @likes
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

  def poll
    playlist = Playlist.find_by(id: params[:id])
    data = playlist ? { :title => playlist.title, 
                        :owner => playlist.user.id, 
                        :psongs => playlist.psongs, 
                        :songs => playlist.songs} : nil
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
    if (playlist = Playlist.find_by(id: params[:id]))
      psong = Psong.find_by(song_id: params[:songid], playlist_id: params[:id])
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
    title = params[:title]
    playlist = Playlist.find(playlist_id)
    song = playlist.songs.create(name: title, deezer_id: song_id)
    psong = Psong.find_by(playlist_id: playlist_id, song_id: song.id)
    psong.update_column(:queued, false)
  end

  def like
    if (@playlist = Playlist.find_by(id: params[:id]))
      if (like_instance = Like.where(playlist_id: params[:id], user_id: session[:user_id])[0])
        like_instance.destroy
        n_likes = Like.where(:playlist_id => params[:id]).count
        ret = {
          :url => '/assets/clearheart.png',
          :n_likes => n_likes
        }
        render :json => ret
      else
        Like.create(user_id: session[:user_id], playlist_id: params[:id])
        n_likes = Like.where(:playlist_id => params[:id]).count
        ret = {
          :url => '/assets/redheart.png',
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
end
