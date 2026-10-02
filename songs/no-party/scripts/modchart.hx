// ═══════════════════════════════════════════════════════════════════════════════
// No Party / No Party Old - the note field modchart
// ═══════════════════════════════════════════════════════════════════════════════
//
// `case 'no party' | 'no party old'` of
// `Mario-Madness/source/modchart/Modcharts.hx` (154-166), i.e. **both** songs
// carry this same timeline - `no-party-old/scripts/modchart.hx` is the copy for
// the legacy chart.  (`alone`, `all-stars` and the rest have separate cases for
// their `... Old` charts only where the source has one; this is the one shared
// case among the ten.)
//
// The whole song runs with the player's field parked off to the left:
// `transform0X..3X` are set to -983 plus 169.6/3.5, 339.3/3.5 and 509/3.5, a
// 48.46px lane spread on top of the -983px shove (so the four lanes fan out as
// they leave), and `transformY` puts the field 136px up under downscroll or
// 100px up otherwise.  Dad's field is hidden from the start (`alpha 1` on
// player 1) - his arrows are not drawn for the song.
//
// `thex` and the two `x / 3.5` terms are kept as the source writes them, so the
// lane offsets read the same as the case does.
//
// The timeline is handed to `songs/MMmodfields.hx`, the port of the fork's
// modifier framework: one array per queued call, `[startStep, endStep, name,
// value, style, player]`, `player = -1` for both fields, `style = null` a
// `queueSet`.  These are all `setValue`s, so the whole timeline is in effect
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

function create() {
	var thex = -983;
	sv('alpha', 1, 1);
	sv('transform0X', thex, 0);
	sv('transform1X', thex + 169.6 / 3.5, 0);
	sv('transform2X', thex + 339.3 / 3.5, 0);
	sv('transform3X', thex + 509 / 3.5, 0);
	if (downscroll) sv('transformY', -136, 0);
	else sv('transformY', -100, 0);

	mmPublish('no party');
}
