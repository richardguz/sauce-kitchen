class AddUpvotesToPsongs < ActiveRecord::Migration[5.0]
  def change
  	add_column :psongs, :upvotes, :integer, default: 0
  	add_column :psongs, :queued, :boolean, default: true
  end
end
