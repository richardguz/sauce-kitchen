class PlaylistsController < ApplicationController
  def show
  	@playlist = Playlist.find_by(id: params[:id])
  end

  def new
  	@playlist = Playlist.new
  	puts @playlist
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

  private
  	def playlist_params
  		params.require(:playlist).permit(:title, :songs) 
  	end
end
