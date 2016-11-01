function pollPlaylist(pid, uid){
	$.get("/playlists/json/" + pid, function(playlist){
		//updates title of the playlist
		var songs = playlist.songs;
		var psongs = playlist.psongs;

		//updates the title
		//updates to any other additional general info would go here too (with dynaspan)
		//if (uid == playlist['owner'].toString())
		//	$('#title span').text(playlist['title']);
		//else
		//	$('#title').text(playlist['title']);

		//to replace the dynaspan functionality
		$('#title').text(playlist['title']);

		//updates the songs and how they're displayed
		for (j = 0; j < songs.length; j++){
			//finds the psong corresponding to the song
			var psong;
			for (var i = 0; i < psongs.length; i++){
				if (psongs[i].psong.song_id == songs[j].id){
					psong = psongs[i];
					//add any songs to the queues if they aren't already there
					if (psong.psong.queued)
						handleQueued(songs[j], psong, uid);
					else
						handleWaiting(songs[j], psong, uid);
				}
			}
			

		}
		sortByUpvotes('queuedSongsList');
		sortByUpvotes('waitingSongsList');
	}, "json");

}

function sortByUpvotes(listElementId){
	var list = $('#' + listElementId);
	var orderedList = list.find('tr').sort(function(a,b){ 
		votes_diff = $(b).attr('upvotes') - $(a).attr('upvotes');
		if (votes_diff != 0)
			return votes_diff;
		else{
			if ($(b).attr('psongid') > $(a).attr('psongid'))
				return 1
			else if ($(b).attr('psongid') < $(a).attr('psongid'))
				return -1
			else {
				return 0
			}
		}
	});
	list.find('tr').remove();
	list.append(orderedList);
}

function handleQueued(song, psong, uid){
	//checks if it's in list passed in
	if (inSongsList(psong, "queuedSongsList")){
		//check upvotes and update if upvotes don't match
		displayedUpvotes = $('#queuedSongsList tr[psongid=' + psong.psong.id + ']').attr('upvotes');
		if (displayedUpvotes != psong.psong.upvotes){
			removeFromSongsList(psong, "queuedSongsList");
			appendToSongsList(song, psong, "queuedSongsList", uid);
		}
		else{
			if(songPlayed(psong))
				removeFromSongsList(psong, "queuedSongsList");
		}
	}
	else{
		//check if in waiting instead
		if (inSongsList(psong, "waitingSongsList")){
			//if in waiting, remove
			removeFromSongsList(psong, "waitingSongsList");
		}
		//add to queued b/c it currently isn't there
		appendToSongsList(song, psong, "queuedSongsList", uid);
	}
}

function handleWaiting(song, psong, uid){
	//checks if it's in waiting list
	if (inSongsList(psong, "waitingSongsList")){
		//check upvotes and update if upvotes don't match
		displayedUpvotes = $('#waitingSongsList tr[psongid=' + psong.psong.id + ']').attr('upvotes');
		if (displayedUpvotes != psong.psong.upvotes){
			removeFromSongsList(psong, "waitingSongsList");
			appendToSongsList(song, psong, "waitingSongsList", uid);
		}
		else{
			if(songPlayed(psong))
				removeFromSongsList(psong, "waitingSongsList");
		}
	}
	else{
		//check if in queued instead
		if (inSongsList(psong, "queuedSongsList")){
			//if in queued, remove
			removeFromSongsList(psong, "queuedSongsList");
		}
		//add to waiting b/c it currently isn't there
		appendToSongsList(song, psong, "waitingSongsList", uid);
	}
}

function appendToSongsList(song, psong, listId, uid){
	if (!songPlayed(psong)){
		upvotedString = psong.voted_user_ids.includes(parseInt(uid)) ? "true" : "false"
		$('#' + listId).append(
				'<tr upvotes=' + psong.psong.upvotes + ' psongid=' + psong.psong.id + " upvoted=" + upvotedString + "><td>" + song.name + "</td><td>" + song.artist + "</td><td><button onclick='upvoteClick(this);' class='upvote-icon'><span class='glyphicon glyphicon glyphicon-chevron-up'>" + psong.psong.upvotes + "</span></button></td></tr>");
	}
}

function removeFromSongsList(psong, listId){
	$('#' + listId + ' tr[psongid=' + psong.psong.id + ']').remove();
}

function songPlayed(psong){
	return psong.psong.played;
}

function inSongsList(psong, listId){
	if ($('#' + listId + ' tr[psongid=' + psong.psong.id + ']').length > 0)
		return true;
	else
		return false;
}



