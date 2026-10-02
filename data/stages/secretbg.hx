

// === MM stage triggers (auto) ===
// 'Triggers Dictator' - ported from PlayState.hx:13808-13884, together with the
// stage half of `case 'secretbg'` (3257-3295, 4387-4389, 4673-4679, 7832-7836)
// and the camera half in songs/MMcamera.hx (mmDictatorTrigger).
//
// The group is mostly camera (the intro lunge, the GF-sing zoom climb and the
// ending close-up) plus three stage writes: the explosion (8), the black curtain
// (9) and the Bullet Bill warning (11/12).
//
// Stage-level behaviour that comes with the case:
//   3258-3259  `noCount`/`noHUD` - the READY/SET/GO are dropped (onCountdown
//              cancelled) and camHUD starts at alpha 0 (the chart's own
//              'Ocultar HUD' 2 brings it back at 16.17s).
//   3264-3281  the three background plates are *added* sky -> back trees -> floor
//              (3279-3281), not their declaration order. The XML now keeps
//              all three in that draw order; moving only the floor still
//              left the sky above the back trees.
//   4387-4389  `add(frontTrees); add(explosionBOM);` run in the *foreground*
//              switch, after the character groups - both are in front of the
//              fighters there, so postCreate lifts them out of the world layer.
//   4673-4679  `blackBarThingie` for luigiout/realbg/turmoilsweep/secretbg: a
//              full-screen black on camEst created at alpha **1**. The countdown
//              branch 7832-7836 (shared with luigiout) then fades it out over 0.5s
//              after a one-second delay, which is what onSongStart() does here -
//              the port's stand-in for camEst is a screen-space sprite in front of
//              the draw list (see execlassic.hx).
//   3292-3295  `frontTrees` ('mario/secret/BushesForeground').
//
// The death character/preloads are configured by songs/MMcamera.hx. Missed
// Bullet Bill/Bullet2 notes queue the source's bulletTimer damage below;
// ordinary Bullet notes belong to Overdue's ammunition mechanic instead.

var mmCurtain = null;    // blackBarThingie (4673), world-front, alpha 1 at load
var mmWarning = null;    // secretWarning (3288), camHUD, added at case 12
var mmBulletPending = false;

function mmScreen(spr) {
	spr.scrollFactor.set(0, 0);
	add(spr);
	return spr;
}

function mmGetCurtain() {
	if (mmCurtain == null) {
		mmCurtain = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmCurtain.scale.set(10, 10); // source's setGraphicSize(width * 10)
		mmCurtain.alpha = 1;
		mmScreen(mmCurtain);
	}
	return mmCurtain;
}

// 3288-3293: the warning sign, an atlas on camHUD, `screenCenter()` then
// `x += 200`, and *not* added to the draw list until case 12 - so it is built
// here and only `add()`ed by the trigger.
function mmGetWarning() {
	if (mmWarning == null) {
		mmWarning = new FunkinSprite(0, 0);
		mmWarning.frames = Paths.getSparrowAtlas("mario/secret/BulletBill_Warning");
		mmWarning.animation.addByPrefix("loop", "warning", 24, true);
		mmWarning.animation.addByPrefix("bye", "blow away", 24, false);
		mmWarning.animation.play("loop");
		mmWarning.cameras = [camHUD];
		mmWarning.screenCenter();
		mmWarning.x += 200;
		mmWarning.visible = false;
	}
	return mmWarning;
}

function onCountdown(event) {
	// `noCount = true` (3258): the source never builds its 3-2-1-GO sprites.
	event.cancelled = true;
}

function onSongStart() {
	// 7832-7836 (the branch secretbg shares with luigiout).
	FlxTween.tween(mmGetCurtain(), {alpha: 0}, 0.5, {startDelay: 1, ease: FlxEase.quadInOut});
}

function postCreate() {
	if (camHUD != null) camHUD.alpha = 0; // source noHUD opening
	// 3279-3281: sky -> back trees -> floor is already the XML's draw order.
	// 4387-4389: both are added after the character groups there, i.e. in front
	// of the fighters. Lifted with a splice plus an append - a bare
	// `remove(x); add(x)` would be a no-op, since `remove` only nulls the slot
	// and `add` re-fills the first null slot of the list, which is that same one.
	for (f in [frontTrees, explosionBOM]) {
		if (f == null) continue;
		remove(f, true);
		insert(members.length, f);
	}
	mmGetCurtain();
	mmGetWarning();
}

// PlayState.hx:15296-15298 arms bulletTimer on a MISS, never on a hit.
// At the source's 60fps baseline it expires on the next update. Coalesce
// simultaneous projectile misses, just as assigning bulletTimer = 1 does.
function onPlayerMiss(event) {
	if (!event.ghostMiss && (event.noteType == "Bullet Bill" || event.noteType == "Bullet2"))
		mmBulletPending = true;
}

function update(elapsed) {
	if (!mmBulletPending) return;
	mmBulletPending = false;
	FlxTween.tween(PlayState.instance, {health: health - 1}, 0.2, {ease: FlxEase.quadOut});
	FlxG.sound.play(Paths.sound("SHbulletmiss"), 0.5);
	if (iconP1 == null) return;
	var white = new FlxSprite().makeGraphic(Std.int(iconP1.width / 2), Std.int(iconP1.height / 2), FlxColor.WHITE);
	white.cameras = [camHUD];
	white.x = iconP1.x + 60;
	white.y = iconP1.y + 30;
	add(white);
	new FlxTimer().start(0.05, function(tmr) {
		remove(white, true);
		white.destroy();
		iconP1.color = FlxColor.BLACK;
		new FlxTimer().start(0.05, function(tmr2) { iconP1.color = FlxColor.WHITE; });
	});
}

// ----------------------------------------------------------------------------
// 'Triggers Dictator' 0-12
// ----------------------------------------------------------------------------
// Sent as 'Triggers Universal' by the chart (the source re-dispatches that to
// 'Triggers <song>' at runtime, 9489-9496), so both names are accepted. The
// camera cases (0-8 and the fifteen case 10s) are songs/MMcamera.hx's
// mmDictatorTrigger; what is left here is the three sprite writes.
function onEvent(event) {
	if (event.event.name != "Triggers Dictator" && event.event.name != "Triggers Universal") return;
	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;

	switch (trigger) {
		case 8:
			// 161.74s: the building goes up.
			if (explosionBOM != null) {
				explosionBOM.alpha = 1;
				explosionBOM.animation.play("BOOM");
			}
		case 9:
			// 162.26s: the curtain slams down (the song ends behind it).
			mmGetCurtain().alpha = 1;
		case 11:
			// 22.96s: the sign blows away and slides left.
			var w = mmGetWarning();
			if (w == null) return;
			w.animation.play("bye", true);
			w.x -= 470;
		case 12:
			// 19.30s (before 11 in the chart): the sign drops in from above.
			var w2 = mmGetWarning();
			if (w2 == null) return;
			w2.visible = true;
			w2.y -= 800;
			FlxTween.tween(w2, {y: w2.y + 800}, 1.5, {ease: FlxEase.quadOut});
			add(w2);
	}
}
// === end MM stage triggers ===
