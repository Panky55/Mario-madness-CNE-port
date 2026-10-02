// 'Alt Animation' note type - the character sings the "-alt" variant of its
// sing animation. Ported from Mario's Madness (source/PlayState.hx: daAlt = '-alt').
function onNoteHit(event) {
	if (event.noteType == "Alt Animation")
		event.animSuffix = "-alt";
}
