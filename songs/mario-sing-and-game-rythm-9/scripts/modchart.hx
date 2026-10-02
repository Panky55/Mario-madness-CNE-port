// ═══════════════════════════════════════════════════════════════════════════════
// Mario Sing and Game Rythm 9 - the note field modchart
// ═══════════════════════════════════════════════════════════════════════════════
//
// `case 'mario sing and game rythm 9'` of
// `Mario-Madness/source/modchart/Modcharts.hx` (142-153): the whole song runs
// with BF's field 24px to the left and dad's 76px to the right (the handheld
// screen the `somari` stage draws is off-centre, and the fields are nudged to
// match), and with both fields 40px down under downscroll / 10px up otherwise.
//
// The case's last line, `PlayState.songIsModcharted = false`, has no port
// here and needs none.  In the fork it switches the modchart system *off* for
// the rest of the song, which makes two guarded reads live:
//
//   * the PlayState-level flipchar swap (7699), which this song's stage cannot
//     reach anyway - `flipchar` is only set by five stage branches (hatebg,
//     promoshow, luigiout, demiseport and the No Hope case), and `somari` is
//     not one of them;
//   * the middleScroll note-hiding branch (8242).
//
// Codename has neither (the flipchar layout is per stage script, and there is no
// middleScroll), so there is nothing to switch off - writing the field anyway
// would be a `Reflect.setField` on a nonexistent PlayState field, which throws
// on cpp (see the note in `songs/MMcamera.hx`).  The `middleScroll` half of the
// case below is ported the guarded way for the same reason it is in the other
// two songs: it is dead in CNE but follows the engine if it ever exposes one.
//
// The timeline is handed to `songs/MMmodfields.hx`, the port of the fork's
// modifier framework: one array per queued call, `[startStep, endStep, name,
// value, style, player]`, `player = -1` for both fields, `style = null` a
// `queueSet`.  All of these are `setValue`s, so the whole timeline is in effect
// from load.

var _ev = [];

// queueSet(step, mod, value, player) - a snap at `step`
function qs(step, name, value, player) {
	_ev.push([step, step, name, value, null, player]);
}

// queueEase(step, endStep, mod, value, style, player)
function qe(step, endStep, name, value, style, player) {
	_ev.push([step, endStep, name, value, style, player]);
}

// setValue(mod, value, player) - in effect from load, no step
function sv(name, value, player) {
	_ev.push([-1, -1, name, value, null, player]);
}

function mmPublish(songName) {
	var ps = PlayState.instance;
	if (ps != null && ps.scripts != null) ps.scripts.set('mmModField', _ev);
	trace('mmModField: ' + songName + ' ' + _ev.length + ' events');
}

// `ClientPrefs.middleScroll`, read the guarded way the stage triggers read it
// (see starman-slaughter's copy for why the branch is dead in CNE).
function mmMiddleScroll() {
	var ps = PlayState.instance;
	if (ps != null && Reflect.hasField(ps, 'middleScroll'))
		return Reflect.field(ps, 'middleScroll') == true;
	return false;
}

function create() {
	// the two fields' offsets for the whole song
	sv('transformX', -24, 0);
	sv('transformX', 76, 1);

	// both fields sit a little lower (or higher) with the screen
	if (downscroll) sv('transformY', 40, -1);
	else sv('transformY', -10, -1);

	if (mmMiddleScroll()) {
		sv('opponentSwap', 0.45, -1);
		sv('alpha', 1, 1);
	}

	mmPublish('mario sing and game rythm 9');
}
