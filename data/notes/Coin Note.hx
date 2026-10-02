// 'Coin Note' - restores one of Luigi's lives in the "Land" stages. Ported from
// Mario's Madness (source/PlayState.hx: luigilife++, 'refill' sound). The life
// counter HUD lives in the stage script; we notify it through PlayState.
function onPlayerHit(event) {
	if (event.noteType != "Coin Note") return;
	FlxG.sound.play(Paths.sound("refill"));
	if (Reflect.hasField(PlayState.instance, "onCoinNote"))
		Reflect.callMethod(PlayState.instance, Reflect.field(PlayState.instance, "onCoinNote"), []);
}
