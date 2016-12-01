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
                        :songs => playlist.songs,
                        :current_song_title => playlist.current_song_title,
                        :current_song_artist => playlist.current_song_artist,
                        :playing => playlist.playing } : nil
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
          playlist.update(current_song_title: psong.song.name)
          playlist.update(current_song_artist: psong.song.artist)
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
    playlist = Playlist.find(playlist_id)
    if (song = Song.find_by(deezer_id: song_id))
      psong = Psong.create(song_id: song.id, playlist_id: playlist_id)
      if (!is_logged_in || !isOwner(current_user, playlist))
        psong.update_column(:queued, false)
    end
    else
      json_response = deezer_song(song_id) 
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
      return user.playlists.exists?(playlist.id)
    end

    def deezer_song(id)
      if (id == 126602225)
        return {"id"=>126602225, "readable"=>true, "title"=>"Champions", "title_short"=>"Champions", "title_version"=>"", "isrc"=>"USUM71605463", "link"=>"http://www.deezer.com/track/126602225", "share"=>"http://www.deezer.com/track/126602225?utm_source=deezer&utm_content=track-126602225&utm_term=0_1480541373&utm_medium=web", "duration"=>334, "track_position"=>1, "disk_number"=>1, "rank"=>635447, "release_date"=>"2016-06-13", "explicit_lyrics"=>true, "preview"=>"http://cdn-preview-4.deezer.com/stream/41ccde9d6ffcb1081e23b2a05a9d2841-2.mp3", "bpm"=>135.11, "gain"=>-6.1, "available_countries"=>["CA", "MX", "US"], "contributors"=>[{"id"=>230, "name"=>"Kanye West", "link"=>"http://www.deezer.com/artist/230", "share"=>"http://www.deezer.com/artist/230?utm_source=deezer&utm_content=artist-230&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/230/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/230/top?limit=50", "type"=>"artist", "role"=>"Main"}, {"id"=>7972, "name"=>"Gucci Mane", "link"=>"http://www.deezer.com/artist/7972", "share"=>"http://www.deezer.com/artist/7972?utm_source=deezer&utm_content=artist-7972&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/7972/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/b930ef46a50f647bbc78abb5b9b1bf7d/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/b930ef46a50f647bbc78abb5b9b1bf7d/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/b930ef46a50f647bbc78abb5b9b1bf7d/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/b930ef46a50f647bbc78abb5b9b1bf7d/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/7972/top?limit=50", "type"=>"artist", "role"=>"Main"}, {"id"=>15427, "name"=>"Big Sean", "link"=>"http://www.deezer.com/artist/15427", "share"=>"http://www.deezer.com/artist/15427?utm_source=deezer&utm_content=artist-15427&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/15427/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/09c41888b318ba2ccfd6617f93f89f75/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/09c41888b318ba2ccfd6617f93f89f75/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/09c41888b318ba2ccfd6617f93f89f75/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/09c41888b318ba2ccfd6617f93f89f75/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/15427/top?limit=50", "type"=>"artist", "role"=>"Main"}, {"id"=>103369, "name"=>"Yo Gotti", "link"=>"http://www.deezer.com/artist/103369", "share"=>"http://www.deezer.com/artist/103369?utm_source=deezer&utm_content=artist-103369&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/103369/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist//56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist//250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist//500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist//1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/103369/top?limit=50", "type"=>"artist", "role"=>"Main"}, {"id"=>1384338, "name"=>"2 Chainz", "link"=>"http://www.deezer.com/artist/1384338", "share"=>"http://www.deezer.com/artist/1384338?utm_source=deezer&utm_content=artist-1384338&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/1384338/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/c4ee9534823887a36d22d036f37d1fdf/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/c4ee9534823887a36d22d036f37d1fdf/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/c4ee9534823887a36d22d036f37d1fdf/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/c4ee9534823887a36d22d036f37d1fdf/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/1384338/top?limit=50", "type"=>"artist", "role"=>"Main"}, {"id"=>4495513, "name"=>"Travis Scott", "link"=>"http://www.deezer.com/artist/4495513", "share"=>"http://www.deezer.com/artist/4495513?utm_source=deezer&utm_content=artist-4495513&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/4495513/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/d6888c3cefa54f8b51d197fee2344f00/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/d6888c3cefa54f8b51d197fee2344f00/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/d6888c3cefa54f8b51d197fee2344f00/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/d6888c3cefa54f8b51d197fee2344f00/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/4495513/top?limit=50", "type"=>"artist", "role"=>"Main"}, {"id"=>5059044, "name"=>"Quavo", "link"=>"http://www.deezer.com/artist/5059044", "share"=>"http://www.deezer.com/artist/5059044?utm_source=deezer&utm_content=artist-5059044&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/5059044/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist//56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist//250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist//500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist//1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/5059044/top?limit=50", "type"=>"artist", "role"=>"Main"}, {"id"=>9551192, "name"=>"Desiigner", "link"=>"http://www.deezer.com/artist/9551192", "share"=>"http://www.deezer.com/artist/9551192?utm_source=deezer&utm_content=artist-9551192&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/9551192/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/b3f48992afdd0bf96dcfbf6dca9761cc/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/b3f48992afdd0bf96dcfbf6dca9761cc/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/b3f48992afdd0bf96dcfbf6dca9761cc/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/b3f48992afdd0bf96dcfbf6dca9761cc/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/9551192/top?limit=50", "type"=>"artist", "role"=>"Main"}], "artist"=>{"id"=>230, "name"=>"Kanye West", "link"=>"http://www.deezer.com/artist/230", "share"=>"http://www.deezer.com/artist/230?utm_source=deezer&utm_content=artist-230&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/230/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/230/top?limit=50", "type"=>"artist"}, "album"=>{"id"=>13338723, "title"=>"Champions", "link"=>"http://www.deezer.com/album/13338723", "cover"=>"http://api.deezer.com/album/13338723/image", "cover_small"=>"http://cdn-images.deezer.com/images/cover/2d4ff7b7ef13ea5e70fe8c7e7404d3e5/56x56-000000-80-0-0.jpg", "cover_medium"=>"http://cdn-images.deezer.com/images/cover/2d4ff7b7ef13ea5e70fe8c7e7404d3e5/250x250-000000-80-0-0.jpg", "cover_big"=>"http://cdn-images.deezer.com/images/cover/2d4ff7b7ef13ea5e70fe8c7e7404d3e5/500x500-000000-80-0-0.jpg", "cover_xl"=>"http://cdn-images.deezer.com/images/cover/2d4ff7b7ef13ea5e70fe8c7e7404d3e5/1000x1000-000000-80-0-0.jpg", "release_date"=>"2016-06-13", "tracklist"=>"http://api.deezer.com/album/13338723/tracks", "type"=>"album"}, "type"=>"track"}
{"id"=>230, "name"=>"Kanye West", "link"=>"http://www.deezer.com/artist/230", "share"=>"http://www.deezer.com/artist/230?utm_source=deezer&utm_content=artist-230&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/230/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/230/top?limit=50", "type"=>"artist", "role"=>"Main"}
{"id"=>7972, "name"=>"Gucci Mane", "link"=>"http://www.deezer.com/artist/7972", "share"=>"http://www.deezer.com/artist/7972?utm_source=deezer&utm_content=artist-7972&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/7972/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/b930ef46a50f647bbc78abb5b9b1bf7d/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/b930ef46a50f647bbc78abb5b9b1bf7d/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/b930ef46a50f647bbc78abb5b9b1bf7d/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/b930ef46a50f647bbc78abb5b9b1bf7d/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/7972/top?limit=50", "type"=>"artist", "role"=>"Main"}
{"id"=>15427, "name"=>"Big Sean", "link"=>"http://www.deezer.com/artist/15427", "share"=>"http://www.deezer.com/artist/15427?utm_source=deezer&utm_content=artist-15427&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/15427/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/09c41888b318ba2ccfd6617f93f89f75/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/09c41888b318ba2ccfd6617f93f89f75/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/09c41888b318ba2ccfd6617f93f89f75/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/09c41888b318ba2ccfd6617f93f89f75/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/15427/top?limit=50", "type"=>"artist", "role"=>"Main"}
{"id"=>103369, "name"=>"Yo Gotti", "link"=>"http://www.deezer.com/artist/103369", "share"=>"http://www.deezer.com/artist/103369?utm_source=deezer&utm_content=artist-103369&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/103369/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist//56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist//250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist//500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist//1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/103369/top?limit=50", "type"=>"artist", "role"=>"Main"}
{"id"=>1384338, "name"=>"2 Chainz", "link"=>"http://www.deezer.com/artist/1384338", "share"=>"http://www.deezer.com/artist/1384338?utm_source=deezer&utm_content=artist-1384338&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/1384338/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/c4ee9534823887a36d22d036f37d1fdf/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/c4ee9534823887a36d22d036f37d1fdf/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/c4ee9534823887a36d22d036f37d1fdf/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/c4ee9534823887a36d22d036f37d1fdf/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/1384338/top?limit=50", "type"=>"artist", "role"=>"Main"}
{"id"=>4495513, "name"=>"Travis Scott", "link"=>"http://www.deezer.com/artist/4495513", "share"=>"http://www.deezer.com/artist/4495513?utm_source=deezer&utm_content=artist-4495513&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/4495513/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/d6888c3cefa54f8b51d197fee2344f00/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/d6888c3cefa54f8b51d197fee2344f00/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/d6888c3cefa54f8b51d197fee2344f00/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/d6888c3cefa54f8b51d197fee2344f00/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/4495513/top?limit=50", "type"=>"artist", "role"=>"Main"}
{"id"=>5059044, "name"=>"Quavo", "link"=>"http://www.deezer.com/artist/5059044", "share"=>"http://www.deezer.com/artist/5059044?utm_source=deezer&utm_content=artist-5059044&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/5059044/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist//56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist//250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist//500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist//1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/5059044/top?limit=50", "type"=>"artist", "role"=>"Main"}
{"id"=>9551192, "name"=>"Desiigner", "link"=>"http://www.deezer.com/artist/9551192", "share"=>"http://www.deezer.com/artist/9551192?utm_source=deezer&utm_content=artist-9551192&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/9551192/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/b3f48992afdd0bf96dcfbf6dca9761cc/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/b3f48992afdd0bf96dcfbf6dca9761cc/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/b3f48992afdd0bf96dcfbf6dca9761cc/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/b3f48992afdd0bf96dcfbf6dca9761cc/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/9551192/top?limit=50", "type"=>"artist", "role"=>"Main"}
      else
        url = "http://api.deezer.com/track/#{id}&output=json"
        uri = URI(url)
        response = Net::HTTP.get(uri)
        return JSON.parse(response, symbolize_keys: true)
      end
    end
end
