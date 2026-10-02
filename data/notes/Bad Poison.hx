// 'Bad Poison' - a hazard note; hitting it plays the poison scroll sound and
// builds up a purple poison overlay. Ported from Mario's Madness
// (source/PlayState.hx: Bad Poison branch + badPoisonVG sprite).
var poisonVG:FlxSprite;

function create() {
	if (!Assets.exists(Paths.image("mario/BadMario/poisonVG"))) return;
	poisonVG = new FlxSprite(0, 0).loadGraphic(Paths.image("mario/BadMario/poisonVG"));
	poisonVG.cameras = [camHUD];
	poisonVG.alpha = 0;
	add(poisonVG);
}

function onPlayerHit(event) {
	if (event.noteType != "Bad Poison") return;
	FlxG.sound.play(Paths.sound("bad-day/smw_scroll"), 0.8);
	if (poisonVG != null)
		FlxTween.tween(poisonVG, {alpha: Math.min(poisonVG.alpha + 0.15, 1)}, 0.1, {ease: FlxEase.quadOut});
}
