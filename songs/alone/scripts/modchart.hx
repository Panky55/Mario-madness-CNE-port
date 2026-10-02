// ═══════════════════════════════════════════════════════════════════════════════
// Alone - the note field modchart
// ═══════════════════════════════════════════════════════════════════════════════
//
// `case 'alone'` of `Mario-Madness/source/modchart/Modcharts.hx` (167-173).
// The song's gimmick is the drunken, half-visible player field:
//
//   from load  BF's field is hidden (`alpha 1` on player 0), dad's is at
//              `alpha 0.3`, and BF's lane drifts with `drunk 0.5` - a 56px
//              cosine sway per lane, phase-shifted by the lane index, plus the
//              source's per-note phase term on top (the arrows swing wider than
//              the receptors; both terms are in `songs/MMmodfields.hx`).
//   160-184    both fields fade to `alpha 0` (linear).
//   192-208    both fields fade to `alpha 0.2` (linear).
//   1660-1704  both fields fade to `alpha 1` for the outro (linear).
//
// All three source queueEase calls have FIVE arguments. The fifth is style,
// not player; player retains its default -1 (both fields). Numeric styles do
// not resolve to a FlxEase member and fall back to linear. Preserve what the
// source executes rather than guessing the author's intended player.
//
// `Alone Old` is deliberately not covered: the source's case matches
// `songName.toLowerCase()` exactly, and `'alone old'` is not `'alone'`, so the
// legacy chart has no timeline in the fork either (unlike `no party`/`no party
// old`, which are one case).
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
	// the opening state: BF's field hidden and drunk, dad's just shy of visible
	sv('alpha', 1, 0);
	sv('alpha', 0.3, 1);
	sv('drunk', 0.5, 0);

	// Numeric style arguments fall back to linear; all three target both fields.
	qe(192, 208, 'alpha', 0.2, 'linear', -1);
	qe(160, 184, 'alpha', 0, 'linear', -1);
	qe(1660, 1704, 'alpha', 1, 'linear', -1);

	mmPublish('alone');
}
