class AddAmplitudeDataToSongs < ActiveRecord::Migration[5.0]
  def change
  	rename_column :songs, :title, :name
  	add_column :songs, :artist, :string
  	add_column :songs, :url, :string
  	add_column :songs, :album, :string
  	add_column :songs, :cover_art_url, :string
  	add_column :psongs, :played, :boolean, default: false
  end
end
