function pollPlaylist(pid, uid){
	$.get("/playlists/json/" + pid, function(playlist){
		//updates title of the playlist
		var songs = playlist.songs;
		var psongs = playlist.psongs;
		console.log(songs);

		//updates the title
		//updates to any other additional general info would go here too
		if (uid == playlist['owner'].toString())
			$('#title span').text(playlist['title']);
		else
			$('#title').text(playlist['title']);

		//updates the songs and how they're displayed
		for (j = 0; j < songs.length; j++){
			//finds the psong corresponding to the song
			var psong;
			for (var i = 0; i < psongs.length; i++){
				if (psongs[i].song_id == songs[j].id){
					psong = psongs[i];
				}
			}
			//add any songs to the queues if they aren't already there
			if (psong.queued)
				handleQueued(songs[j], psong);
			else
				handleWaiting(songs[j], psong);

		}
		sortByUpvotes('queuedSongsList');
		sortByUpvotes('waitingSongsList');
	}, "json");

}

function sortByUpvotes(listElementId){
	var list = $('#' + listElementId);
	var orderedList = list.find('li').sort(function(a,b){ return $(b).attr('upvotes') - $(a).attr('upvotes'); });
	list.find('li').remove();
	list.append(orderedList);
}

function updateSongQueue(song, psong, listId){
	//console.log(psong.upvotes);
	if ($('#' + listId + ' li[songid=' + song.id + ']').length == 0){
				appendToSongsList(song, psong, listId);
	}
	else{
		//remove the <li> if the upvotes are not accurate, and reappend updated version
		displayedUpvotes = $('#' + listId + ' li[songid=' + song.id + ']').attr('upvotes');
		if (displayedUpvotes != psong.upvotes){
			$('#' + listId + ' li[songid=' + song.id + ']').remove();
			appendToSongsList(song, psong, listId);
		}

	}
}

function handleQueued(song, psong){
	if (song.id == 5)
		console.log("in handle queued");
	//checks if it's in list passed in
	if ($('#queuedSongsList li[songid=' + song.id + ']').length > 0){
		if (song.id == 5)
			console.log("found in queued list");
		//check upvotes and update if upvotes don't match
		displayedUpvotes = $('#queuedSongsList li[songid=' + song.id + ']').attr('upvotes');
		if (displayedUpvotes != psong.upvotes){
			$('#queuedSongsList li[songid=' + song.id + ']').remove();
			appendToSongsList(song, psong, "queuedSongsList");
		}
	}
	else{
		if (song.id == 5)
			console.log("not found in queued list");
		//check if in waiting instead
		if ($('#waitingSongsList li[songid=' + song.id + ']').length > 0){
			//if in waiting, remove
			if (song.id == 5)
				console.log("removing from waiting list");
			$('#waitingSongsList li[songid=' + song.id + ']').remove();
		}
		//add to queued b/c it currently isn't there
		if (song.id == 5)
				console.log("adding to queued list");
		appendToSongsList(song, psong, "queuedSongsList");
	}
}

function handleWaiting(song, psong){
	//checks if it's in list passed in
	if (song.id == 5)
		console.log("in handle waiting");
	if ($('#waitingSongsList li[songid=' + song.id + ']').length > 0){
		if (song.id == 5)
			console.log("found waiting list");
		//check upvotes and update if upvotes don't match
		displayedUpvotes = $('#waitingSongsList li[songid=' + song.id + ']').attr('upvotes');
		if (displayedUpvotes != psong.upvotes){
			$('#waitingSongsList li[songid=' + song.id + ']').remove();
			appendToSongsList(song, psong, "waitingSongsList");
		}
	}
	else{
		if (song.id == 5)
			console.log("not in waiting list");
		//check if in queued instead
		if ($('#queuedSongsList li[songid=' + song.id + ']').length > 0){
			//if in queued, remove
			if (song.id == 5)
				console.log("removing from queued list");
			$('#queuedSongsList li[songid=' + song.id + ']').remove();
		}
		if (song.id == 5)
				console.log("adding to waiting list");
		//add to waiting b/c it currently isn't there
		appendToSongsList(song, psong, "waitingSongsList");
	}
}

function appendToSongsList(song, psong, listId){
	$('#' + listId).append(
					'<li upvotes=' + psong.upvotes + ' songid=' + song.id + '>' + song.title + ': ' + psong.upvotes + '</ul>');
}

