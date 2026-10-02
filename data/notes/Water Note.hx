// 'Water Note' - hitting it raises the flood/stage water. Ported from
// Mario's Madness (source/PlayState.hx: flood.y += 60, 'waterswitch' sound).
// The flood sprite itself belongs to the stage script; we expose a small
// helper API on PlayState via the stage script (see the stage's .hx).
function onPlayerHit(event) {
	if (event.noteType != "Water Note") return;
	FlxG.sound.play(Paths.sound("waterswitch"));
	if (Reflect.hasField(PlayState.instance, "onWaterNote"))
		Reflect.callMethod(PlayState.instance, Reflect.field(PlayState.instance, "onWaterNote"), []);
}
