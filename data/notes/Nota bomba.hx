// 'Nota bomba' (bomb note) - a hazard note; hitting it costs a full point of
// health. Ported from Mario's Madness (source/PlayState.hx: health -= 1).
function onPlayerHit(event) {
	if (event.noteType != "Nota bomba") return;
	health -= 1;
	event.cancel();
}
