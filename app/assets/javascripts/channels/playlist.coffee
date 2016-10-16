App.playlist = App.cable.subscriptions.create "PlaylistChannel",
  connected: ->
    # Called when the subscription is ready for use on the server

  disconnected: ->
    # Called when the subscription has been terminated by the server

  received: (data) ->
    $('#title').text data['playlist']

  speak: (title) ->
    @perform 'speak', title: title
