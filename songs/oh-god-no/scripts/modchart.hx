// ═══════════════════════════════════════════════════════════════════════════════
// Oh God No - the note field modchart
// ═══════════════════════════════════════════════════════════════════════════════
//
// `case 'oh god no'` of `Mario-Madness/source/modchart/Modcharts.hx` (104-123).
// The song runs on the shared `hatebg` stage, which the source's create()
// branches on for this one song alone (1540: `if (PlayState.SONG.song == 'Oh
// God No') flipchar = true`, on top of the two camera overrides MMcamera
// carries), and the field opens in the same swapped state:
//
//   from load  dad's field is hidden (`alpha 1`), both fields have traded sides
//              (`opponentSwap 1`), BF's field is 320px off to the right
//              (`transformX 320`) and dad's sits 120px low (`transformY 120`).
//   92-104     all four unwind with an expoOut / elasticOut flourish.
//   672-680    both fields dim to `alpha 0.3` (linear), 800-808 back off to 0.
//
// The `middleScroll` branch around the unwinds has no Codename counterpart (see
// the helper below), so the port always takes the non-middleScroll half - which
// is the layout the stage's own camera work is built around.
//
// The timeline is handed to `songs/MMmodfields.hx`, the port of the fork's
// modifier framework: one array per queued call, `[startStep, endStep, name,
// value, style, player]`, `player = -1` for both fields, `style = null` a
// `queueSet`.  Step values are the source's.

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
	// the opening state (the fork applies these while the song is created)
	sv('alpha', 1, 1);
	sv('opponentSwap', 1, -1);
	sv('transformX', 320, 0);
	sv('transformY', 120, 1);

	// 92-104: the trade unwinds in place (this one is already at its target)
	qe(92, 104, 'opponentSwap', 1, 'expoOut', -1);

	if (!mmMiddleScroll()) {
		qe(92, 104, 'transformY', 0, 'elasticOut', 1);
		qe(92, 104, 'transformX', 0, 'expoOut', 0);
		qe(92, 104, 'alpha', 0, 'elasticOut', 1);
		qe(800, 808, 'alpha', 0, 'linear', 1);
		qe(672, 680, 'alpha', 0.3, 'linear', 1);
	}

	// the player's field dims at 672-680 and comes back at 800-808, the same
	// beat dad's does above
	qe(672, 680, 'alpha', 0.3, 'linear', 0);
	qe(800, 808, 'alpha', 0, 'linear', 0);

	mmPublish('oh god no');
}
