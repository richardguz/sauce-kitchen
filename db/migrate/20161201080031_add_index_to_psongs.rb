class AddIndexToPsongs < ActiveRecord::Migration[5.0]
  def change
  	add_index :psongs, :playlist_id
  end
end