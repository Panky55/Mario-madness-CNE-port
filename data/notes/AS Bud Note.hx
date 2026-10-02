// 'AS Bud Note' - both the stage character and the girlfriend sing the note.
// Ported from Mario's Madness (source/PlayState.hx: gf.playAnim + dad.playAnim).
function singName(dir:Int):String {
	switch (dir) {
		case 0: return "singLEFT";
		case 1: return "singDOWN";
		case 2: return "singUP";
		default: return "singRIGHT";
	}
}

function onNoteHit(event) {
	if (event.noteType != "AS Bud Note") return;
	event.preventAnim();
	var anim = singName(event.direction);
	// The source sets `holdTimer = 0`; Codename's Character has no such field.
	// Its equivalent is `lastHit` + `holdTime` (`tryDance()` holds the sing anim
	// while `lastHit + stepCrochet * holdTime >= songPosition`). Resetting the
	// timer starts a fresh hold, represented by SING context and the current time.
	if (gf != null) {
		gf.playSingAnim(event.direction, "");
		gf.lastHit = Conductor.songPosition;
	}
	if (event.character != null) {
		event.character.playSingAnim(event.direction, "");
		event.character.lastHit = Conductor.songPosition;
	}
	if (Reflect.hasField(PlayState.instance, "onYoshiNote"))
		Reflect.callMethod(PlayState.instance, Reflect.field(PlayState.instance, "onYoshiNote"), [event.direction]);
}
