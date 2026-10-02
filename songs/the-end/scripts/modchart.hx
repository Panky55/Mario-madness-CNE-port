// ═══════════════════════════════════════════════════════════════════════════════
// The End - the note field modchart
// ═══════════════════════════════════════════════════════════════════════════════
//
// `case 'the end'` of `Mario-Madness/source/modchart/Modcharts.hx` (124-127):
// three snaps at step 1184 - `296 * 4`, i.e. the same step the stage's own
// `Triggers The End` 9 lands on (296 beats at the chart's BPM), which is where
// the source's dad swap and the curtain are.  The two fields meet in the middle
// (`opponentSwap 0.5`), dad's field is hidden (`alpha 1` on player 1) and both
// fields pinch inwards by a quarter of the flip distance (`flip -0.25`).
//
// All three are `player = -1` in the source (no player argument), i.e. both
// fields - including the `flip`, which is what makes the two fields' outer
// lanes swing in.
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
	// 1184 (296 * 4): the fields meet, dad's goes dark, and both pinch by a
	// quarter flip
	qs(296 * 4, 'opponentSwap', 0.5, -1);
	qs(296 * 4, 'alpha', 1, 1);
	qs(296 * 4, 'flip', -0.25, -1);

	mmPublish('the end');
}
