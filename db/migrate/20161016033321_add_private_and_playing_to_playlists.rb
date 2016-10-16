class AddPrivateAndPlayingToPlaylists < ActiveRecord::Migration[5.0]
  def change
    add_column :playlists, :private, :boolean, default: false
    add_column :playlists, :playing, :boolean, default: false
  end
end
