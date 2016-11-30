function playNextSong(pid){
  	$.get("/playlists/" + pid + "/next_song/json", function(song){
    	DZ.player.playTracks([song.deezer_id]);
  	});
  }

function resetPlaylist(pid){
  $.get("/playlists/" + pid + "/reset_play_history", function(){});
}

function togglePlaylistPlaying(pid, value){
	if (value) {
		$.get("/playlists/" + pid + "/set_playing_true", function(){});
	}
	else {
		$.get("/playlists/" + pid + "/set_playing_false", function(){});
	}
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
    $("#songSearchResults").append("<tr song_id=" + searchResults.data[i].id + " title=" + searchResults.data[i].title + "><td>" + searchResults.data[i].title + "</td><td>" + searchResults.data[i].artist.name + "</td><td><button class='btn btn-default' onclick='addSongToWaiting(this);'><span class='glyphicon glyphicon glyphicon-plus'></span></button></td></tr>");
	}	
}

function addSongToWaiting(element){
	//first make song unclickable and change button
	$(element).attr('disabled','disabled');
	$(element).css('color','green');

	//then get attributes and update
	var trEl = $(element).parent().parent()
	var song_id = trEl.attr('song_id');
	var title = trEl.attr('title');

	//make request to update in db
	console.log("/playlists/" + getPlaylistId() + "/add_song/" + song_id + "/" + title);
	$.post("/playlists/" + getPlaylistId() + "/add_song/" + song_id + "/" + title, function(){
		console.log(title)
		console.log("id: " + song_id)
		console.log("request to add song successful");
		//update locally TODO
	});
}


function getPlaylistId(){
	var path = window.location.pathname;
	var pid = path.split('/')[2];
	return pid;
}