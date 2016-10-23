function playNextSong(pid){
  	$.get("/playlists/" + pid + "/next_song/json", function(song){
    	DZ.player.playTracks([song.deezer_id]);
  	});
  }

function resetPlaylist(pid){
  $.get("/playlists/" + pid + "/reset_play_history", function(){});
}

function searchDeezer(searchString){
	$.ajax({
    url: "https://api.deezer.com/search?q=" + searchString + "&callback=?",
    dataType: 'json',
    jsonpCallback: 'callback',
    type: 'GET',
    success: function (data) {
        console.log(data);
    }
	});
}