class AddCurrentSongInfoToPlaylist < ActiveRecord::Migration[5.0]
  def change
  	add_column :playlists, :current_song_title, :string
  	add_column :playlists, :current_song_artist, :string
  end
end
