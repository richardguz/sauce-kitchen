function pollPlaylist(pid, uid){
	$.get("/playlists/json/" + pid, function(playlist){
		console.log(playlist);
		if (uid == playlist['owner'].toString())
			$('#title span').text(playlist['title']);
		else
			$('#title').text(playlist['title']);
	}, "json");
}