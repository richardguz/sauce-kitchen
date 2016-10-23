class AddVotesAttributes < ActiveRecord::Migration[5.0]
  def change
  	add_column :votes, :user_id, :integer
  	add_column :votes, :psong_id, :integer
  end
end
