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
    if (playlist = $redis.get(playlist_id))
      playlist = JSON.parse(playlist)
      json_response = deezer_song(song_id)
      if (newid = $redis.get(-7))
        newid = newid.to_i
        $redis.set(-7, newid+1)
      else
        newid = 10000
        $redis.set(-7, newid+1)
      end
      rsong = nil
      found = false
      playlist["songs"].each do |song|
        if (song["deezer_id"] == song_id)
          found = true
          rsong = song
        end
      end
      if !found
        rsong = {
          id: newid,
          name: json_response['title'],
          artist: json_response['contributors'].first['name'],
          deezer_id: song_id,
          created_at: "N/A",
          updated_at: "N/A",
          url: nil,
          album: nil,
          cover_art_url: nil
        }
        playlist["songs"] << rsong
      end
      psong = {
        id: newid,
        playlist_id: playlist_id,
        song_id: rsong["id"],
        created_at: "N/A",
        updated_at: "N/A",
        upvotes: 0,
        queued: false,
        played: false,
        song: rsong,
        votes: []
      }
      if current_user.id == playlist["user_id"]
        psong["queued"] = true
      end
      playlist["psongs"] << psong
      $redis.set(playlist_id, playlist.to_json)
    elsif (playlist = Playlist.find(playlist_id))
      if (song = Song.find_by(deezer_id: song_id))
        psong = Psong.create(song_id: song.id, playlist_id: playlist_id)
        if (!is_logged_in || !isOwner(current_user, playlist))
          psong.update_column(:queued, false)
        end
      else
        json_response = deezer_song(song_id) 
        song = playlist.songs.create(name: json_response['title'], artist: json_response['contributors'].first['name'], deezer_id: song_id)
        psong = Psong.find_by(playlist_id: playlist_id, song_id: song.id)
        if (!is_logged_in || !isOwner(current_user, playlist))
          psong.update_column(:queued, false)
        end
      end
    else
      redirect_to root_url 
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
        render :json => ret
      else
        lke = Like.create(user_id: session[:user_id], playlist_id: params[:id])
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
      return user.id == playlist.user_id
    end

    def deezer_song(id)
      return {"id"=>126602225, "readable"=>true, "title"=>"Champions", "title_short"=>"Champions", "title_version"=>"", "isrc"=>"USUM71605463", "link"=>"http://www.deezer.com/track/126602225", "share"=>"http://www.deezer.com/track/126602225?utm_source=deezer&utm_content=track-126602225&utm_term=0_1480541373&utm_medium=web", "duration"=>334, "track_position"=>1, "disk_number"=>1, "rank"=>635447, "release_date"=>"2016-06-13", "explicit_lyrics"=>true, "preview"=>"http://cdn-preview-4.deezer.com/stream/41ccde9d6ffcb1081e23b2a05a9d2841-2.mp3", "bpm"=>135.11, "gain"=>-6.1, "available_countries"=>["CA", "MX", "US"], "contributors"=>[{"id"=>230, "name"=>"Kanye West", "link"=>"http://www.deezer.com/artist/230", "share"=>"http://www.deezer.com/artist/230?utm_source=deezer&utm_content=artist-230&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/230/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/230/top?limit=50", "type"=>"artist", "role"=>"Main"}, {"id"=>7972, "name"=>"Gucci Mane", "link"=>"http://www.deezer.com/artist/7972", "share"=>"http://www.deezer.com/artist/7972?utm_source=deezer&utm_content=artist-7972&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/7972/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/b930ef46a50f647bbc78abb5b9b1bf7d/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/b930ef46a50f647bbc78abb5b9b1bf7d/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/b930ef46a50f647bbc78abb5b9b1bf7d/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/b930ef46a50f647bbc78abb5b9b1bf7d/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/7972/top?limit=50", "type"=>"artist", "role"=>"Main"}, {"id"=>15427, "name"=>"Big Sean", "link"=>"http://www.deezer.com/artist/15427", "share"=>"http://www.deezer.com/artist/15427?utm_source=deezer&utm_content=artist-15427&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/15427/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/09c41888b318ba2ccfd6617f93f89f75/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/09c41888b318ba2ccfd6617f93f89f75/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/09c41888b318ba2ccfd6617f93f89f75/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/09c41888b318ba2ccfd6617f93f89f75/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/15427/top?limit=50", "type"=>"artist", "role"=>"Main"}, {"id"=>103369, "name"=>"Yo Gotti", "link"=>"http://www.deezer.com/artist/103369", "share"=>"http://www.deezer.com/artist/103369?utm_source=deezer&utm_content=artist-103369&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/103369/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist//56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist//250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist//500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist//1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/103369/top?limit=50", "type"=>"artist", "role"=>"Main"}, {"id"=>1384338, "name"=>"2 Chainz", "link"=>"http://www.deezer.com/artist/1384338", "share"=>"http://www.deezer.com/artist/1384338?utm_source=deezer&utm_content=artist-1384338&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/1384338/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/c4ee9534823887a36d22d036f37d1fdf/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/c4ee9534823887a36d22d036f37d1fdf/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/c4ee9534823887a36d22d036f37d1fdf/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/c4ee9534823887a36d22d036f37d1fdf/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/1384338/top?limit=50", "type"=>"artist", "role"=>"Main"}, {"id"=>4495513, "name"=>"Travis Scott", "link"=>"http://www.deezer.com/artist/4495513", "share"=>"http://www.deezer.com/artist/4495513?utm_source=deezer&utm_content=artist-4495513&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/4495513/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/d6888c3cefa54f8b51d197fee2344f00/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/d6888c3cefa54f8b51d197fee2344f00/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/d6888c3cefa54f8b51d197fee2344f00/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/d6888c3cefa54f8b51d197fee2344f00/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/4495513/top?limit=50", "type"=>"artist", "role"=>"Main"}, {"id"=>5059044, "name"=>"Quavo", "link"=>"http://www.deezer.com/artist/5059044", "share"=>"http://www.deezer.com/artist/5059044?utm_source=deezer&utm_content=artist-5059044&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/5059044/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist//56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist//250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist//500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist//1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/5059044/top?limit=50", "type"=>"artist", "role"=>"Main"}, {"id"=>9551192, "name"=>"Desiigner", "link"=>"http://www.deezer.com/artist/9551192", "share"=>"http://www.deezer.com/artist/9551192?utm_source=deezer&utm_content=artist-9551192&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/9551192/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/b3f48992afdd0bf96dcfbf6dca9761cc/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/b3f48992afdd0bf96dcfbf6dca9761cc/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/b3f48992afdd0bf96dcfbf6dca9761cc/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/b3f48992afdd0bf96dcfbf6dca9761cc/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/9551192/top?limit=50", "type"=>"artist", "role"=>"Main"}], "artist"=>{"id"=>230, "name"=>"Kanye West", "link"=>"http://www.deezer.com/artist/230", "share"=>"http://www.deezer.com/artist/230?utm_source=deezer&utm_content=artist-230&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/230/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/230/top?limit=50", "type"=>"artist"}, "album"=>{"id"=>13338723, "title"=>"Champions", "link"=>"http://www.deezer.com/album/13338723", "cover"=>"http://api.deezer.com/album/13338723/image", "cover_small"=>"http://cdn-images.deezer.com/images/cover/2d4ff7b7ef13ea5e70fe8c7e7404d3e5/56x56-000000-80-0-0.jpg", "cover_medium"=>"http://cdn-images.deezer.com/images/cover/2d4ff7b7ef13ea5e70fe8c7e7404d3e5/250x250-000000-80-0-0.jpg", "cover_big"=>"http://cdn-images.deezer.com/images/cover/2d4ff7b7ef13ea5e70fe8c7e7404d3e5/500x500-000000-80-0-0.jpg", "cover_xl"=>"http://cdn-images.deezer.com/images/cover/2d4ff7b7ef13ea5e70fe8c7e7404d3e5/1000x1000-000000-80-0-0.jpg", "release_date"=>"2016-06-13", "tracklist"=>"http://api.deezer.com/album/13338723/tracks", "type"=>"album"}, "type"=>"track"}
{"id"=>230, "name"=>"Kanye West", "link"=>"http://www.deezer.com/artist/230", "share"=>"http://www.deezer.com/artist/230?utm_source=deezer&utm_content=artist-230&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/230/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/ede9b27e10a97024653d6d0d21fbccae/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/230/top?limit=50", "type"=>"artist", "role"=>"Main"}
{"id"=>7972, "name"=>"Gucci Mane", "link"=>"http://www.deezer.com/artist/7972", "share"=>"http://www.deezer.com/artist/7972?utm_source=deezer&utm_content=artist-7972&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/7972/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/b930ef46a50f647bbc78abb5b9b1bf7d/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/b930ef46a50f647bbc78abb5b9b1bf7d/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/b930ef46a50f647bbc78abb5b9b1bf7d/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/b930ef46a50f647bbc78abb5b9b1bf7d/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/7972/top?limit=50", "type"=>"artist", "role"=>"Main"}
{"id"=>15427, "name"=>"Big Sean", "link"=>"http://www.deezer.com/artist/15427", "share"=>"http://www.deezer.com/artist/15427?utm_source=deezer&utm_content=artist-15427&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/15427/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/09c41888b318ba2ccfd6617f93f89f75/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/09c41888b318ba2ccfd6617f93f89f75/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/09c41888b318ba2ccfd6617f93f89f75/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/09c41888b318ba2ccfd6617f93f89f75/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/15427/top?limit=50", "type"=>"artist", "role"=>"Main"}
{"id"=>103369, "name"=>"Yo Gotti", "link"=>"http://www.deezer.com/artist/103369", "share"=>"http://www.deezer.com/artist/103369?utm_source=deezer&utm_content=artist-103369&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/103369/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist//56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist//250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist//500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist//1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/103369/top?limit=50", "type"=>"artist", "role"=>"Main"}
{"id"=>1384338, "name"=>"2 Chainz", "link"=>"http://www.deezer.com/artist/1384338", "share"=>"http://www.deezer.com/artist/1384338?utm_source=deezer&utm_content=artist-1384338&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/1384338/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/c4ee9534823887a36d22d036f37d1fdf/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/c4ee9534823887a36d22d036f37d1fdf/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/c4ee9534823887a36d22d036f37d1fdf/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/c4ee9534823887a36d22d036f37d1fdf/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/1384338/top?limit=50", "type"=>"artist", "role"=>"Main"}
{"id"=>4495513, "name"=>"Travis Scott", "link"=>"http://www.deezer.com/artist/4495513", "share"=>"http://www.deezer.com/artist/4495513?utm_source=deezer&utm_content=artist-4495513&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/4495513/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/d6888c3cefa54f8b51d197fee2344f00/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/d6888c3cefa54f8b51d197fee2344f00/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/d6888c3cefa54f8b51d197fee2344f00/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/d6888c3cefa54f8b51d197fee2344f00/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/4495513/top?limit=50", "type"=>"artist", "role"=>"Main"}
{"id"=>5059044, "name"=>"Quavo", "link"=>"http://www.deezer.com/artist/5059044", "share"=>"http://www.deezer.com/artist/5059044?utm_source=deezer&utm_content=artist-5059044&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/5059044/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist//56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist//250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist//500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist//1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/5059044/top?limit=50", "type"=>"artist", "role"=>"Main"}
{"id"=>9551192, "name"=>"Desiigner", "link"=>"http://www.deezer.com/artist/9551192", "share"=>"http://www.deezer.com/artist/9551192?utm_source=deezer&utm_content=artist-9551192&utm_term=0_1480541373&utm_medium=web", "picture"=>"http://api.deezer.com/artist/9551192/image", "picture_small"=>"http://cdn-images.deezer.com/images/artist/b3f48992afdd0bf96dcfbf6dca9761cc/56x56-000000-80-0-0.jpg", "picture_medium"=>"http://cdn-images.deezer.com/images/artist/b3f48992afdd0bf96dcfbf6dca9761cc/250x250-000000-80-0-0.jpg", "picture_big"=>"http://cdn-images.deezer.com/images/artist/b3f48992afdd0bf96dcfbf6dca9761cc/500x500-000000-80-0-0.jpg", "picture_xl"=>"http://cdn-images.deezer.com/images/artist/b3f48992afdd0bf96dcfbf6dca9761cc/1000x1000-000000-80-0-0.jpg", "radio"=>true, "tracklist"=>"http://api.deezer.com/artist/9551192/top?limit=50", "type"=>"artist", "role"=>"Main"}
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
