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
    url: "https://api.deezer.com/search?q=" + searchString + "&output=jsonp" + "&callback=?",
    dataType: 'jsonp',
    type: 'GET',
    success: function (data) {
        console.log(data);
        displaySearchResults(data);
    }
	});
}

function displaySearchResults(searchResults){
	$("#songSearchResults").empty();
	var len = searchResults.data.length;
	for (var i = 0; i < len; i++) {
    $("#songSearchResults").append("<li song_id=" + searchResults.data[i].id + " title=" + searchResults.data[i].title + ">" + searchResults.data[i].title + " - " + searchResults.data[i].artist.name + "<button onclick='addSongToWaiting(this);'><span class='glyphicon glyphicon glyphicon-plus'></span></button></li>");
	}	
}

function addSongToWaiting(element){
	var song_id = $(element).parent().attr('song_id');
	var title = $(element).parent().attr('title');

	//make request to update in db
	$.get("/playlists/" + getPlaylistId() + "/add_song/" + song_id + "/" + title, function(){
		console.log("request to add song successful");
		//update locally TODO
	});
}

function getPlaylistId(){
	var path = window.location.pathname;
	var pid = path.split('/')[2];
	return pid;
}