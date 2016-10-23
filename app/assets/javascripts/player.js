function playNextSong(pid){
  	$.get("/playlists/" + pid + "/next_song/json", function(song){
    	DZ.player.playTracks([song.deezer_id]);
  	});
  }

function resetPlaylist(pid){
  $.get("/playlists/" + pid + "/reset_play_history", function(){});
}

function searchDeezer(searchString){
	$.get("https://api.deezer.com/search?q=" + searchString, function(songs){
		console.log(songs);
	});
}