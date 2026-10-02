// 'Hey!' note type - the character plays its "hey" animation and the girlfriend
// cheers. Ported from Mario's Madness (source/PlayState.hx:15612-15635).
//
// On nesbeat the source replaces the girlfriend's cheer with the *starman GF's*
// 'hey' (the `if (curStage != 'nesbeat') { ...cheer... } else
// starmanGF.animation.play('hey', true);` split at 15625-15635) and skips bf's
// `specialAnim`/`heyTimer` there, which this engine does not model anyway. The
// starman GF only exists inside that stage's own script, so the swap lives in
// data/stages/nesbeat.hx's onNoteHit - this file stands down on the stage.
function onNoteHit(event) {
	if (event.noteType != "Hey!") return;

	var c = event.character;
	if (c != null && c.animation.getByName("hey") != null) {
		event.preventAnim();
		c.playAnim("hey", true);
	}
	if (gf != null && gf.animation.getByName("cheer") != null && curStage != "nesbeat")
		gf.playAnim("cheer", true);
}
