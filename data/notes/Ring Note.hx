// 'Ring Note' - collects a ring (Sonic-style life ring, used by the Somari
// stage). Ported from Mario's Madness (source/PlayState.hx: ring++,
// 'ringhit' sound). The ring counter lives in the stage script.
function onPlayerHit(event) {
	if (event.noteType != "Ring Note") return;
	FlxG.sound.play(Paths.sound("ringhit"));
	// `Reflect.hasField` is false for every member of a class *instance* on the
	// cpp build, so this guard was dead there (see PORT_NOTES.md).
	if (Reflect.field(PlayState.instance, "onRingNote") != null)
		Reflect.callMethod(PlayState.instance, Reflect.field(PlayState.instance, "onRingNote"), []);
}
