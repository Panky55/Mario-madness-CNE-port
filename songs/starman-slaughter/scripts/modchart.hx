// ═══════════════════════════════════════════════════════════════════════════════
// Starman Slaughter - the note field modchart
// ═══════════════════════════════════════════════════════════════════════════════
//
// `case 'starman slaughter'` of `Mario-Madness/source/modchart/Modcharts.hx`
// (97-103).  The whole case is the middleScroll layout:
//
//   middleScroll   both fields slide to the middle (`opponentSwap 0.5`, which
//                  is each lane sitting halfway to the *other* field's lane)
//                  and dad's field is hidden (`alpha 1` on player 1).
//   otherwise      BOTH fields fade out at step 2048-2052.
//
// `queueEase(2048, 2052, "alpha", 1, 1)` has five arguments: the numeric
// fifth argument is style, while player keeps its default -1 (both fields).
// The style falls back to linear. Keep the executed source behaviour, not a
// guessed correction to the author's argument order.
//
// The timeline is handed to `songs/MMmodfields.hx`, the port of the fork's
// modifier framework: one array per queued call, `[startStep, endStep, name,
// value, style, player]`, `player = -1` for both fields, `style = null` a
// `queueSet`.  Step values are the source's, the two engines count the same.

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

// `ClientPrefs.middleScroll` - a Psych option with no Codename counterpart, so
// the branch below is dead here unless the engine ever exposes the field.  Read
// off the state the guarded way the stage triggers read it
// (`port_templates/stage_triggers/realbg.hx`), so it follows along if it does.
function mmMiddleScroll() {
	var ps = PlayState.instance;
	if (ps != null && Reflect.field(ps, 'middleScroll') != null)
		return Reflect.field(ps, 'middleScroll') == true;
	return false;
}

function create() {
	if (mmMiddleScroll()) {
		// both fields to the middle, dad's field hidden
		sv('opponentSwap', 0.5, -1);
		sv('alpha', 1, 1);
	} else {
		// 2048-2052: both fields fade out, with the source's style fallback.
		qe(2048, 2052, 'alpha', 1, 'linear', -1);
	}

	mmPublish('starman slaughter');
}
