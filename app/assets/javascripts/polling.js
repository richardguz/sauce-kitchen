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
				}
			}
			//add any songs to the queues if they aren't already there
			if (psong.psong.queued)
				handleQueued(songs[j], psong, uid);
			else
				handleWaiting(songs[j], psong, uid);

		}
		sortByUpvotes('queuedSongsList');
		sortByUpvotes('waitingSongsList');
	}, "json");

}

function sortByUpvotes(listElementId){
	var list = $('#' + listElementId);
	var orderedList = list.find('li').sort(function(a,b){ 
		votes_diff = $(b).attr('upvotes') - $(a).attr('upvotes');
		if (votes_diff != 0)
			return votes_diff;
		else{
			if ($(b).attr('songid') > $(a).attr('songid'))
				return 1
			else if ($(b).attr('songid') < $(a).attr('songid'))
				return -1
			else {
				console.log($(b).attr('songid'))
				console.log($(a).attr('songid'))
				console.log($(b).text())
				console.log($(a).text())
				return 0
			}
		}
	});
	list.find('li').remove();
	list.append(orderedList);
}

function handleQueued(song, psong, uid){
	//checks if it's in list passed in
	if (inSongsList(song, "queuedSongsList")){
		//check upvotes and update if upvotes don't match
		displayedUpvotes = $('#queuedSongsList li[songid=' + song.id + ']').attr('upvotes');
		if (displayedUpvotes != psong.psong.upvotes){
			removeFromSongsList(song, "queuedSongsList");
			appendToSongsList(song, psong, "queuedSongsList", uid);
		}
		else{
			if(songPlayed(psong))
				removeFromSongsList(song, "queuedSongsList");
		}
	}
	else{
		//check if in waiting instead
		if (inSongsList(song, "waitingSongsList")){
			//if in waiting, remove
			removeFromSongsList(song, "waitingSongsList");
		}
		//add to queued b/c it currently isn't there
		appendToSongsList(song, psong, "queuedSongsList", uid);
	}
}

function handleWaiting(song, psong, uid){
	//checks if it's in waiting list
	if (inSongsList(song, "waitingSongsList")){
		//check upvotes and update if upvotes don't match
		displayedUpvotes = $('#waitingSongsList li[songid=' + song.id + ']').attr('upvotes');
		if (displayedUpvotes != psong.psong.upvotes){
			removeFromSongsList(song, "waitingSongsList");
			appendToSongsList(song, psong, "waitingSongsList", uid);
		}
		else{
			if(songPlayed(psong))
				removeFromSongsList(song, "waitingSongsList");
		}
	}
	else{
		//check if in queued instead
		if (inSongsList(song, "queuedSongsList")){
			//if in queued, remove
			removeFromSongsList(song, "queuedSongsList");
		}
		//add to waiting b/c it currently isn't there
		appendToSongsList(song, psong, "waitingSongsList", uid);
	}
}

function appendToSongsList(song, psong, listId, uid){
	console.log("user id =" + uid);
	if (!songPlayed(psong)){
		upvotedString = psong.voted_user_ids.includes(parseInt(uid)) ? "true" : "false"
		$('#' + listId).append(
				'<li upvotes=' + psong.psong.upvotes + ' songid=' + song.id + " upvoted=" + upvotedString + ">" + song.name + " <button onclick='upvoteClick(this);' class='upvote-icon'><span class='glyphicon glyphicon glyphicon-chevron-up'>" + psong.psong.upvotes + "</span></button>");
	}
}

function removeFromSongsList(song, listId){
	$('#' + listId + ' li[songid=' + song.id + ']').remove();
}

function songPlayed(psong){
	return psong.psong.played;
}

function inSongsList(song, listId){
	if ($('#' + listId + ' li[songid=' + song.id + ']').length > 0)
		return true;
	else
		return false;
}



