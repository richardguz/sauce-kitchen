class AddIndexToPlaylists < ActiveRecord::Migration[5.0]
  def change
  	add_index :playlists, :psong_id
  end
end
