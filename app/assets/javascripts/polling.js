function pollPlaylist(pid, uid){
	$.get("/playlists/json/" + pid, function(playlist){
		//updates title of the playlist
		console.log(playlist['songs']);
		if (uid == playlist['owner'].toString())
			$('#title span').text(playlist['title']);
		else
			$('#title').text(playlist['title']);
			//updates the songs listed in the playlist
		$.each(playlist.songs, function(index, element){
			if ($('#songList li[songid=' + element.id + ']').length == 0){
				$('#songList').append('<li songid=' + element.id + '>' + element.title + '</ul>');
			}
		});
	}, "json");

}