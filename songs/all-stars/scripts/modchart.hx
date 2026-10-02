// ═══════════════════════════════════════════════════════════════════════════════
// All-Stars - the note field modchart
// ═══════════════════════════════════════════════════════════════════════════════
//
// `case 'all-stars'` of `Mario-Madness/source/modchart/Modcharts.hx` (30-36):
// the act 3/4 transition, four `transformX` writes and nothing else.  BF's
// field is thrown 320px to the left and dad's 1500px off to the right (so his
// own arrows are gone for the act), then both snap home at step 4800.
//
// This is the note-field half of the act swap only.  The stage's own
// `Triggers All-Stars` cases (the icons, the character swaps, the camera) live
// in `data/stages/allfinal.hx` and `songs/MMcamera.hx`; `transformX` moves the
// *receptors*, which moves their lanes and every arrow in them (Codename draws
// notes relative to their receptor, see `songs/MMmodfields.hx`).
//
// `All-Stars Old` is deliberately not covered: the source's case matches
// `songName.toLowerCase()` exactly, and `'all-stars old'` is not `'all-stars'`,
// so the legacy chart has no timeline in the fork either.
//
// The timeline is handed to `songs/MMmodfields.hx`, the port of the fork's
// modifier framework that every modcharted song feeds - one array per queued
// call, `[startStep, endStep, name, value, style, player]`, with `player = -1`
// meaning both fields (the source's default) and `style = null` a `queueSet`.
// `Modcharts.hx` keys its timeline on steps, and `Conductor.curStepFloat` is
// the same number, so every step below is copied over verbatim.

var _ev = [];

// queueSet(step, mod, value, player) - a snap at `step`
function qs(step, name, value, player) {
	_ev.push([step, step, name, value, null, player]);
}

// queueEase(step, endStep, mod, value, style, player)
function qe(step, endStep, name, value, style, player) {
	_ev.push([step, endStep, name, value, style, player]);
}

// setValue(mod, value, player) - in effect from load, no step.  The fork applies
// it while the song is still being created, i.e. over the countdown.
function sv(name, value, player) {
	_ev.push([-1, -1, name, value, null, player]);
}

function mmPublish(songName) {
	var ps = PlayState.instance;
	if (ps != null && ps.scripts != null) ps.scripts.set('mmModField', _ev);
	trace('mmModField: ' + songName + ' ' + _ev.length + ' events');
}

function create() {
	// 4544 (the act swap): the two fields part - BF 320 left, dad 1500 right.
	qs(4544, 'transformX', -320, 0);
	qs(4544, 'transformX', 1500, 1);

	// 4800: both snap back home for the next act.
	qs(4800, 'transformX', 0, 0);
	qs(4800, 'transformX', 0, 1);

	mmPublish('all-stars');
}
