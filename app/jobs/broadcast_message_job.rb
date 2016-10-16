class BroadcastMessageJob < ApplicationJob
  queue_as :default

  def perform(title)
  	puts "IN BROADCAST"
    ActionCable.server.broadcast('playlist_channel',
    playlist: title)
	end

end
