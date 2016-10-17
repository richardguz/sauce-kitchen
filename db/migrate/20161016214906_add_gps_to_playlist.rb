class AddGpsToPlaylist < ActiveRecord::Migration[5.0]
  def change
  	add_column :playlists, :latitude, :decimal, default: 0.0, scale: 10, precision:15
  	add_column :playlists, :longitude, :decimal, default: 0.0, scale: 10, precision:15
  end
end
