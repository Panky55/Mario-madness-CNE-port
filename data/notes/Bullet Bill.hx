// Source `Note.hx:196-209` / `PlayState.hx:14777-14790`: Dictator's two
// projectile types do not play a sing animation, and neither takes the ordinary
// sick splash.  Instead a hit only pays off when a *second* projectile is
// struck within 0.15s - `bulletCounter` hits 2, the splash is spawned on the
// last `Bullet Bill` note (`bulletSub`) and `SHbullethit` plays.
//
// The source keeps one `bulletCounter`/`bulletSub` pair on PlayState, shared by
// both types.  Both `Bullet Bill` and `Bullet2` are listed in Dictator's chart
// `noteTypes`, so this script is loaded for the song and its `onNoteHit` sees
// every projectile hit (the engine dispatches the event to every loaded
// script), which lets the one pair of counters serve both - `data/notes/
// Bullet2.hx` only carries its own `preventAnim` backstop.
var mmBulletCounter:Int = 0;
var mmBulletSub = null;

function onNoteHit(event) {
	if (event.noteType != "Bullet Bill" && event.noteType != "Bullet2") return;
	event.preventAnim();
	// The fork never runs the ordinary sick splash for these two types.
	event.showSplash = false;
	mmBulletCounter += 1;
	if (event.noteType == "Bullet Bill") mmBulletSub = event.note;
	if (mmBulletCounter >= 2) {
		mmBulletCounter = 0;
		var splash = PlayState.instance.splashHandler;
		if (mmBulletSub != null && mmBulletSub.__strum != null && splash != null) {
			splash.showSplash(mmBulletSub.splash, mmBulletSub.__strum);
			mmPlaceBulletSplash(splash, mmBulletSub.__strum);
		}
		FlxG.sound.play(Paths.sound("SHbullethit"), 0.6);
	}
	// 14786-14789: a lone projectile is forgotten after 0.15s, so the pair has
	// to land back-to-back to count.
	new FlxTimer().start(0.15, function(tmr) {
		mmBulletCounter = 0;
	});
}

// `NoteSplash.hx:35-46`: the source places this splash by hand -
// `setPosition(x - 370, y - 340)` upscroll, or `setPosition(x - 370, y - 620)`
// *and* `flipY = true` downscroll - then `offset.set(10, 10)`.  Codename's
// `SplashGroup.showOnStrum` centres the 1017x1192 sheet on its strum instead, so
// the source's own numbers are written back over it here (at the splash's scale
// of 1 the sprite origin cancels in the draw, so the frame lands exactly where
// the source draws it).
// `showSplash` returns nothing and trims old splashes off the *front*, so the
// splash it just added is the group's last member.
function mmPlaceBulletSplash(handler, strum) {
	var members = handler.members;
	if (members == null || members.length == 0) return;
	var splash = members[members.length - 1];
	if (splash == null || splash.strum != strum) return;
	var down = PlayState.instance != null && PlayState.instance.downscroll;
	splash.setPosition(strum.x - 370, strum.y - (down ? 620 : 340));
	splash.offset.set(10, 10);
	splash.flipY = down;
}
