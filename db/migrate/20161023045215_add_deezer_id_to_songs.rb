class AddDeezerIdToSongs < ActiveRecord::Migration[5.0]
  def change
    add_column :songs, :deezer_id, :integer
  end
end
