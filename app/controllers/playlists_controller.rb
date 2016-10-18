class PlaylistsController < ApplicationController
  def show
  	@playlist = Playlist.find_by(id: params[:id])
    @user = current_user
    @playlist_owner = @playlist.user
    if @playlist.private && @user != @playlist_owner
      flash[:info] = "The playlist you tried to access is private"
      redirect_to root_url
    end 
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
    puts "ENTERING"
    puts current_user.id 
    puts session[:user_id]
    puts "EXITING"
    redirect_to @playlist
  end

  private
  	def playlist_params
      params.require(:playlist).permit(:title, :songs, :longitude, :latitude)
  	end
end
