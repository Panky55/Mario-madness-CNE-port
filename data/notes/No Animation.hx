// 'No Animation' note type - the character does not play a sing animation.
// Ported from Mario's Madness (source/Note.hx: noAnimation = true).
function onNoteHit(event) {
	if (event.noteType == "No Animation")
		event.preventAnim();
}
