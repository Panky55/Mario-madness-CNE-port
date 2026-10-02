// ═══════════════════════════════════════════════════════════════════════════════
// Bad Day - the note field modchart
// ═══════════════════════════════════════════════════════════════════════════════
//
// `case 'bad day'` of `Mario-Madness/source/modchart/Modcharts.hx` (128-141):
// the step-560 thud.  Every lane's `transformY` is zeroed at load and then the
// four lanes are thrown 70px in lane order 3, 2, 1, 0, one every 4 steps with
// cubeOut - the field slumping downward lane by lane (upward, and by -70, under
// downscroll, offset by the 2-step span the source's two branches use).
//
// The nudges never return to zero, and that is the point: the field stays
// slumped for the rest of the song.
//
// All of it is player 0 (BF's field) - the source passes the player explicitly
// on every call.
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

function create() {
	if (!downscroll) {
		for (i in 0...4) {
			sv('transform' + i + 'Y', 0, 0);
			qe(560 + (i * 4), 560 + ((i * 4) + 2), 'transform' + (3 - i) + 'Y', 70, 'cubeOut', 0);
		}
	} else {
		for (i in 0...4) {
			sv('transform' + i + 'Y', 0, 0);
			qe(560 + ((i * 4) + 2), 560 + ((i * 4) + 4), 'transform' + (3 - i) + 'Y', -70, 'cubeOut', 0);
		}
	}

	mmPublish('bad day');
}
