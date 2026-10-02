// 'Ring Note' - collects a ring (Sonic-style life ring, used by the Somari
// stage). Ported from Mario's Madness (source/PlayState.hx: ring++,
// 'ringhit' sound). The ring counter lives in the stage script.
function onPlayerHit(event) {
	if (event.noteType != "Ring Note") return;
	FlxG.sound.play(Paths.sound("ringhit"));
	if (Reflect.hasField(PlayState.instance, "onRingNote"))
		Reflect.callMethod(PlayState.instance, Reflect.field(PlayState.instance, "onRingNote"), []);
}
