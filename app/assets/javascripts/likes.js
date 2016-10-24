// function clickHeart(isLiked) {
// 	console.log(isLiked);
// 	console.log(isLiked == true);
// 	if (isLiked) {
// 		$("#heart").attr("src","/assets/redheart.png");
// 	}
// 	else {
// 		$("#heart").attr("src","/assets/clearheart.png");
// 	}
// }

function clickHeart(id) {
	$.get( "/playlists/" + id + "/like", function(data) {
		console.log(data)
	  $("#heart").attr("src", data["url"]);
	  $('#nlikes').html(data["n_likes"] + " likes");
	}, "json");
}