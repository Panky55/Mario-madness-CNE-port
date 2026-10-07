// 'Timebar Gimmick' - the source's time-bar gimmick (source/PlayState.hx
// 12224-12255). It is two things at once:
//
//   12229-12242  *only on the 'Demise' song* it jitters the time bar sprites -
//                a 0.04s x pingpong and a 0.02s y pingpong on `timeBarBG`,
//                `timeBar` and `timeTxt` - and cancels those tweens again
//                `time` seconds later.
//   12232/12252  and on *every* song it tweens `minustime` to 0 over `time`
//                seconds (linear on Demise, quadInOut elsewhere).
//
// `minustime` is the fork's time-bar offset: `create()` sets it for two cases
// (6484-6494, `landstage` and not Golden Land Old -> -97.073, 'Demise' ->
// -20.10) and the per-frame bar math divides by `songLength + minustime * 1000`
// (7938-7940), so the bar starts out showing a total *shorter* than the song and
// this event walks it back to the real one. That half is not reproducible here:
// `minustime`, `songLength` and `songPercent` do not exist in Codename, whose own
// bar is computed from the real song length every frame, so there is no value to
// tween and the port's bar always shows the true time. Two of the three chart
// uses are on the other branch anyway (golden-land and Unbeatable's old chart),
// where this is the event's only effect.
//
// What is left is the Demise jitter, which the port used to run on *every* song
// and never stop: the source gates it on the song and cancels it after `time`.
// Codename exposes `timeBar` but neither `timeBarBG` nor `timeTxt`, so the one
// sprite that exists is the one that is shaken.
var mmTimebarShakes = [];

function mmTimebarSong():String {
	if (PlayState.SONG == null || PlayState.SONG.meta == null) return "";
	return StringTools.trim(Std.string(PlayState.SONG.meta.displayName).toLowerCase());
}

function onEvent(event) {
	if (event.event.name != "Timebar Gimmick") return;

	var time = Std.parseFloat(event.event.params[0]);
	if (time == null || Math.isNaN(time)) time = 3;

	// 12229: the jitter is the Demise branch only. On the other branch the
	// source touches nothing but `minustime`, which does not exist here.
	if (mmTimebarSong() != "demise") return;

	var ps = PlayState.instance;
	if (ps == null) return;
	// `Reflect.hasField` is false for every member of a class *instance* on the
	// cpp build, so this read was dead there (see PORT_NOTES.md); `Reflect.field`
	// resolves it on both targets and is null when the state has no time bar.
	var bar = Reflect.field(ps, "timeBar");
	if (bar == null) return;

	for (t in mmTimebarShakes) t.cancel();
	mmTimebarShakes = [];
	mmTimebarShakes.push(FlxTween.tween(bar, {x: bar.x + 12}, 0.04, {type: FlxTween.PINGPONG}));
	mmTimebarShakes.push(FlxTween.tween(bar, {y: bar.y + 6}, 0.02, {type: FlxTween.PINGPONG}));

	// 12242-12249: the source cancels the jitter `time` seconds in, inside the
	// same timer that would have stopped the minustime tween.
	new FlxTimer().start(time, function(tmr) {
		for (t in mmTimebarShakes) t.cancel();
		mmTimebarShakes = [];
	});
}
