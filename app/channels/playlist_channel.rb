# Be sure to restart your server when you modify this file. Action Cable runs in a loop that does not support auto reloading.
class PlaylistChannel < ApplicationCable::Channel
  def subscribed
   	stream_from "playlist_channel"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def speak(data)
  	ActionCable.server.broadcast 'playlist_channel', data['title']
  end
end
