require 'test_helper'

class PlaylistAccessTest < ActionDispatch::IntegrationTest
	def setup
		@user = users(:markus)
		@user2 = users(:kyle)
		@playlist = playlists(:playlist1)
		@user.playlists << @playlist
	end

  test "user accessing other user's public playlist" do
  	login_as(@user2)
  	get "/playlists/#{@playlist.id}"
  	assert_select "h1", text: "Playlist for the boys"
  end

  test "user accessing his own private playlist" do
  	@playlist.private = true
  	@playlist.save

  	login_as(@user)
  	get "/playlists/#{@playlist.id}"
  	assert_select "h1", text: "Playlist for the boys"
  end

  test "user accessing another user's private playlist" do
  	@playlist.private = true
  	@playlist.save

  	login_as(@user2)
  	get "/playlists/#{@playlist.id}"
  	assert_select "h1", false, text: "Playlist for the boys"
  	assert_redirected_to root_url
  	follow_redirect!
  	assert_not flash.empty?
  end
end
