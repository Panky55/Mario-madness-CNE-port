// ═══════════════════════════════════════════════════════════════════════════════
// Day Out - the note field modchart
// ═══════════════════════════════════════════════════════════════════════════════
//
// `case 'day out'` of `Mario-Madness/source/modchart/Modcharts.hx` (419-440): the
// MK&E / Nebula_Zorua modchart the source runs on top of the chart, and the
// reason Day Out's note field is not laid out the way the chart's own data
// suggests. It drives two of that system's modifiers:
//
//   opponentSwap  (modchart/modifiers/OpponentModifier.hx) - slides a field's
//                 lanes onto *the other field's* lanes: `pos.x += (that lane's
//                 base x - this lane's base x) * value`, so 1 is a full trade
//                 and 0 is home. Day Out starts at 1 for both fields - the two
//                 note fields open traded - and then slides the player's field
//                 back and forth on the steps the dialogue and camera cues land
//                 on.
//   alpha         (modchart/modifiers/AlphaModifier.hx, a *submod* of the
//                 modifier it calls `'stealth'`) - `1 - value` is the field's
//                 own opacity, for its receptors *and* for its notes
//                 (`updateReceptor` and `updateNote` both multiply by
//                 `1 - getSubmodValue('alpha', player)`), i.e. value 1 hides the
//                 field outright.
//
// This is *not* the fork's PlayState-level `flipchar` write. That one - the
// per-frame `modManager.setValue("opponentSwap", 1)` at PlayState.hx:7700 - is
// guarded by `curStage != 'meatworld' && !songIsModcharted && ...`, and
// `PlayState.songIsModcharted` is set by `Modcharts.loadModchart`, which
// create() calls for **every** song (6278) while only the `default:` branch
// clears it again (Modcharts.hx:28 sets it, :529 clears it). So a song with a
// case of its own, like this one, stays modcharted and its `opponentSwap` comes
// from here instead.
//
// Ported the way `songs/promotion/scripts/modchart.hx` ports Promotion's case,
// and for the same two reasons: CNE draws every note **relative to its
// receptor** (`Note.draw()` takes `__strum.x/__strum.y`), so moving a receptor
// moves its whole lane, and the source timeline is keyed on **steps**, which is
// `Conductor.curStepFloat` here. Day Out has no `BPM Change` events (114 BPM
// throughout), so every step value below is copied over verbatim.
//
// Everything follows `modchart/ModManager.hx`:
//
//   queueSet(step, mod, value, player)                   - snap at `step`
//   queueEase(step, endStep, mod, value, style, player)  - ease over that span
//   setValue(mod, value)                                 - immediately, no step
//
// with `player = -1` meaning both, which the source lets itself write by leaving
// the argument off (`queueSet(step, mod, value)`), spelled out here because the
// port's checker holds every call to the declared arity. Player 0 is BF
// (`playerStrums`) and player 1 is dad (`opponentStrums`) - `Modifier.hx`:
// "player is 0 for bf, 1 for dad", and `AlphaModifier.updateNote`:
// `note.mustPress ? 0 : 1` - which in CNE are `strumLines.members[1]` and `[0]`,
// i.e. `FW_LINE` below.
//
// One deviation, and it is only a missing *style*: the 462 alpha ease is spelled
// `'backInOutOut'`, which is not a `FlxEase` member. `ModManager.queueEase`
// resolves the name through `Reflect.getProperty(FlxEase, style)` and keeps
// `FlxEase.linear` when that comes back null, so the source runs that one
// linear; `easeOf` spells it out rather than quietly mapping it to `backInOut`.
//
// Faithfully kept, and worth knowing when watching: dad's field is faded out at
// step 462-467 (60.8s) and the case never fades it back in, so the opponent's
// own arrows are invisible for the rest of the song. That is also what keeps it
// out of the player's field's way in the stretches where both would land on the
// same slot - dad sits at swap 1 until step 780 while BF's goes home and back.
// BF's field is hidden for the three stretches the case fades it (518-528,
// 752-788, and 1312 onward - the last one is the 172.7s walk-off).

var FW_LINE = [1, 0]; // framework player id -> index into `strumLines.members`

var _atStep = []; // start step -> the events that begin there (the timeline)
var _live = [];   // events that have started and haven't finished yet
var _lastStep = -1;
var _keys = [];   // "name#player" per id
var _vals = [];   // current value per id
var _base = [];   // [field][lane] -> {x}
var _dirtyP = [false, false]; // this field's alpha is (or just stopped) hiding it
var _started = false;

// id lookups for the values read every frame
var I_SWAP = [0, 0];
var I_ALPHA = [0, 0];

// ids are plain indices into `_vals`, so the per-frame path never hashes a
// string (hscript has no Map shortcut that is worth it here)
function idOf(name, player) {
	var key = name + '#' + player;
	for (i in 0..._keys.length)
		if (_keys[i] == key) return i;
	_keys.push(key);
	_vals.push(0.0);
	return _keys.length - 1;
}

function easeOf(style) {
	switch (style) {
		case 'quadInOut': return FlxEase.quadInOut;
		case 'backInOut': return FlxEase.backInOut;
		// not a FlxEase member - the source's own fallback (see the header)
		case 'backInOutOut': return FlxEase.linear;
	}
	return FlxEase.linear;
}

function pushEvent(step, endStep, name, value, style, player) {
	var e = {
		id: idOf(name, player),
		start: step,
		end: endStep,
		to: value,
		ease: style == null ? null : easeOf(style),
		from: null,
		done: false
	};
	// events are bucketed under the step they begin on; `evaluate` only ever
	// walks the buckets the playhead has just reached plus the handful of events
	// still running, because the timeline is scanned every frame
	var st = Math.floor(step);
	if (_atStep[st] == null) _atStep[st] = [];
	_atStep[st].push(e);
}

// the source's queue functions: player -1 runs the call for both players
function queueSet(step, name, value, player) {
	if (player == -1) {
		pushEvent(step, step, name, value, null, 0);
		pushEvent(step, step, name, value, null, 1);
	} else
		pushEvent(step, step, name, value, null, player);
}

function queueEase(step, endStep, name, value, style, player) {
	if (player == -1) {
		pushEvent(step, endStep, name, value, style, 0);
		pushEvent(step, endStep, name, value, style, 1);
	} else
		pushEvent(step, endStep, name, value, style, player);
}

function setValue(name, value) {
	_vals[idOf(name, 0)] = value;
	_vals[idOf(name, 1)] = value;
}

// ── the chart: Modcharts.hx 419-440, in the source's own order ───────────────

function create() {
	// both fields open traded
	setValue('opponentSwap', 1);

	// 60.8-61.5s (step 460-467): BF's field slides home again while dad's field
	// fades out.
	queueEase(460, 467, 'opponentSwap', 0, 'backInOut', 0);
	queueEase(462, 467, 'alpha', 1, 'backInOutOut', 1);

	// 68.2s (518-528): BF's field fades out, the two fields trade over, and it
	// fades back in on the other side.
	queueEase(518, 520, 'alpha', 1, 'quadInOut', 0);
	queueSet(521, 'opponentSwap', 1, -1);
	queueEase(524, 528, 'alpha', 0, 'quadInOut', 0);

	// 87.9-97.1s (668-738): home, across, and home again.
	queueEase(668, 675, 'opponentSwap', 0, 'backInOut', 0);
	queueEase(700, 706, 'opponentSwap', 1, 'backInOut', 0);
	queueEase(732, 738, 'opponentSwap', 0, 'backInOut', 0);

	// 98.95s (752-788): BF's field blinks out, both fields go home at 102.6s
	// while it is still hidden, and it comes back at 103.2s, home.
	queueEase(752, 756, 'alpha', 1, 'quadInOut', 0);
	queueSet(780, 'opponentSwap', 0, -1);
	queueEase(784, 788, 'alpha', 0, 'quadInOut', 0);

	// 119.5s across, 161.6s home.
	queueEase(908, 914, 'opponentSwap', 1, 'backInOut', 0);
	queueEase(1228, 1234, 'opponentSwap', 0, 'backInOut', 0);

	// 172.7s: the field goes away for the walk-off.
	queueEase(1312, 1316, 'alpha', 1, 'quadInOut', 0);

	prepIds();
}

function prepIds() {
	for (fw in 0...2) {
		I_SWAP[fw] = idOf('opponentSwap', fw);
		I_ALPHA[fw] = idOf('alpha', fw);
	}
}

// ── per-frame: evaluate the timeline, then push the values onto the field ────

function postUpdate(elapsed) {
	if (strumLines == null || strumLines.members == null) return;
	// the strums are generated inside PlayState.create() (`generateStrums`, which
	// runs before the first frame), so the first frame that finds them is the
	// frame the opening trade lands on - x is final the moment they exist
	if (!_started) {
		var a = strumLines.members[FW_LINE[0]];
		var b = strumLines.members[FW_LINE[1]];
		if (a == null || b == null || a.members.length == 0 || b.members.length == 0) return;
		_started = true;
		captureBase();
	}
	evaluate(Conductor.curStepFloat);
	apply();
}

function captureBase() {
	for (fw in 0...2) {
		_base[fw] = [];
		var line = strumLines.members[FW_LINE[fw]];
		if (line == null) continue;
		for (lane in 0...line.members.length) {
			var s = line.members[lane];
			if (s == null) continue;
			_base[fw][lane] = {x: s.x};
		}
	}
}

// walks the timeline in the order the source queued it, which is chronological
// per modifier: a `set` lands instantly, an `ease` captures its starting value
// on its first frame and interpolates until `end`
function evaluate(cur) {
	var st = Math.floor(cur);
	while (_lastStep < st) {
		_lastStep++;
		var bucket = _atStep[_lastStep];
		if (bucket == null) continue;
		for (e in bucket) _live.push(e);
	}

	// then walk only what is still running, compacting the finished ones out of
	// `_live` in place
	var keep = 0;
	for (i in 0..._live.length) {
		var e = _live[i];
		if (e.done) continue;
		_live[keep] = e;
		keep++;
		var v = _vals[e.id];
		if (e.from == null) e.from = v;
		if (e.end <= cur) {
			_vals[e.id] = e.to;
			e.done = true;
			continue;
		}
		var t = e.end == e.start ? 1 : (cur - e.start) / (e.end - e.start);
		if (e.ease != null) t = e.ease(t);
		_vals[e.id] = e.from + (e.to - e.from) * t;
	}
	while (_live.length > keep) _live.pop();
}

function apply() {
	for (fw in 0...2) {
		if (_base[fw] == null) continue;
		var line = strumLines.members[FW_LINE[fw]];
		if (line == null) continue;
		var other = _base[1 - fw];
		var swap = _vals[I_SWAP[fw]];
		var a = 1 - _vals[I_ALPHA[fw]]; // `alpha` is 1 - opacity

		for (lane in 0...line.members.length) {
			var s = line.members[lane];
			if (s == null) continue;
			var b = _base[fw][lane];
			if (b == null) continue;

			// OpponentModifier.getPos: `pos.x += (other base x - own base x) * val`
			var x = b.x;
			if (swap != 0 && other != null && other[lane] != null)
				x += (other[lane].x - x) * swap;
			if (s.x != x) s.x = x;

			if (a != 1 || _dirtyP[fw]) s.alpha = a;
		}

		// a note is not part of its receptor's alpha, so the field's fade has to
		// be walked onto the arrows too - and one more time after it is back at
		// 1, which is what `_dirtyP` holds the pass open for
		if (a != 1 || _dirtyP[fw]) {
			notePass(line, a);
			_dirtyP[fw] = a != 1;
		}
	}
}

// `NoteGroup.forEach` and not a walk over `notes.members`: the group is sized for
// the whole chart up front and sorted by strumTime, and `forEach` is the
// documented way to iterate only the notes that can still be on screen
// (StrumLine.notes).
function notePass(line, a) {
	var now = Conductor.songPosition;
	line.notes.forEach(function(n) {
		if (n == null || !n.exists) return;
		var dt = n.strumTime - now;
		if (dt < -2000 || dt > 5000) return;
		if (a == 1) {
			restoreNote(n);
			return;
		}
		if (!n.extra.exists('mmAlpha0')) n.extra.set('mmAlpha0', n.alpha);
		n.alpha = n.extra.get('mmAlpha0') * a;
	});
}

function restoreNote(n) {
	if (!n.extra.exists('mmAlpha0')) return;
	n.alpha = n.extra.get('mmAlpha0');
	n.extra.remove('mmAlpha0');
}
