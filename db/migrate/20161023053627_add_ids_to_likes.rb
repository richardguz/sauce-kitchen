class AddIdsToLikes < ActiveRecord::Migration[5.0]
  def change
    add_column :likes, :user_id, :integer
    add_column :likes, :playlist_id, :integer
  end
end
