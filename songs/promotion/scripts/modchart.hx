// ═══════════════════════════════════════════════════════════════════════════════
// Promotion - the note field modchart
// ═══════════════════════════════════════════════════════════════════════════════
//
// `case 'promotion'` of `Mario-Madness/source/modchart/Modcharts.hx` (174-418):
// the MK&E / Nebula_Zorua modchart the source runs on top of every arrow in the
// chart - per-arrow `transform*X/Y` sliding, `confusion*` rotation, `mini*X/Y`
// scaling, the `flip` sway, per-lane `alpha*`/`stealth`, `reverse` and the
// `opponentSwap` field crossover.  That is the "the notes move with the film"
// part of the song; without it the chart sits still.
//
// Two things make it portable as a plain song script:
//
//   * CNE renders every note **relative to its receptor**: `Note.draw()` sets
//     its position to `__strum.x/__strum.y` and replays the difference as a
//     frame offset, and `Strum.updateNotePosition()` copies the receptor's
//     angle into `note.angle` every frame.  So moving / rotating / scaling a
//     receptor moves that whole lane - exactly what the source's `getPos()`
//     plus its modifiers get by rewriting every arrow's position each frame.
//   * the source timeline is keyed on **steps** and its `Conductor.getStep()`
//     is BPM-change aware (`Conductor.hx:105`); CNE's `Conductor.curStepFloat`
//     is the same number and the ported chart carries the same `BPM Change`
//     events (130 -> 150 -> 149 -> 160), so every step value below is copied
//     over verbatim.
//
// Everything else follows `modchart/ModManager.hx`:
//
//   queueSet(step, mod, value, player)                   - snap at `step`
//   queueEase(step, endStep, mod, value, style, player)  - ease over that span
//   setValue(mod, value)                                 - immediately, no step
//
// with `player = -1` meaning both players.  The source's player 0 is
// *playerStrums* (BF) and player 1 *opponentStrums* (dad) - see
// `modManager.receptors = [playerStrums.members, opponentStrums.members]`
// (PlayState.hx:6274) and `note.mustPress ? 0 : 1` in AlphaModifier - so
// `FW_LINE` maps framework player 0 onto this engine's BF line.
//
// Deviations (all of them cosmetic):
//
//   * the source fades arrows through its `ColorSwap` shader (`color *=
//     daAlpha`); the port writes `alpha` on the sprite.  Same result.
//   * reverse rebuilds the receptor baseline from `50 + (height - 200) *
//     reverse` and uses signed scrollSpeed for the fall. TransformY is applied
//     afterward, not blended away by reverse. HudCamera already mirrors y in
//     downscroll; only the source's screen-space transform delta is inverted.
//     Sustain clipping/glow still use CNE rather than Psych's renderer.
//   * mods are applied in `postUpdate` (after the engine's own update).  The x
//     half of them - which is what the opening `opponentSwap 1` is - runs from
//     the very first frame, so the two fields start the song already traded;
//     y waits until the strums' intro tween (`StrumLine.createStrum`: 1s, each
//     lane delayed by `0.5 + 0.2 * lane`) has stopped moving them, so that
//     slide-in isn't cancelled.  A receptor's frame angles / confirm pops are
//     only overwritten while a mod is actually driving them.
//
// The script is Promotion-only: `PlayState.create()` loads every file in
// `songs/<song>/scripts/`, so this one only ever runs for that chart.

// framework player id -> index into `strumLines.members`
// (0 = playerStrums = BF, 1 = opponentStrums = dad)
var FW_LINE = [1, 0];

var _atStep = []; // start step -> the events that begin there (the timeline)
var _live = [];   // events that have started and haven't finished yet
var _lastStep = -1;
var _keys = [];   // "name#player" per id
var _vals = [];   // current value per id
var _base = [];   // [framework player][lane] -> {x, y, sx, sy, ss}
var _dirtyS = []; // receptor scale / angle / alpha / scroll were touched
var _dirtyA = [];
var _dirtyP = [];
var _dirtyR = [];
var _noteDirty = [];
var _started = false;
var _ysettled = false;

// ── timeline plumbing ─────────────────────────────────────────────────────────

// ids are plain indices into `_vals` so the per-frame hot path never hashes a
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
		case 'linear': return FlxEase.linear;
		case 'quadIn': return FlxEase.quadIn;
		case 'quadOut': return FlxEase.quadOut;
		case 'quadInOut': return FlxEase.quadInOut;
		case 'circIn': return FlxEase.circIn;
		case 'circOut': return FlxEase.circOut;
		case 'circInOut': return FlxEase.circInOut;
		case 'expoIn': return FlxEase.expoIn;
		case 'expoOut': return FlxEase.expoOut;
		case 'quartOut': return FlxEase.quartOut;
		case 'backOut': return FlxEase.backOut;
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
	// the events are bucketed under the step they begin on.  `evaluate` only ever
	// walks the buckets the playhead has just reached plus the handful of events
	// still running, because the timeline is a few thousand entries long and
	// scanning all of it every frame is what was eating the framerate.
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

// ── the chart ─────────────────────────────────────────────────────────────────

function create() {
	// `modManager.setValue("opponentSwap", 1)` - Promotion's stage is `flipchar`,
	// so from the first frame the two fields trade sides (the source's PlayState
	// does the same for every non-modcharted flipchar stage, PlayState.hx:7700).
	setValue('opponentSwap', 1);

	// 655-672: the fields fade out and throw themselves off screen, one lane
	// after the other: transformY ramps to 300 + 50 * (4 - lane) while confusion
	// goes to -22.5 * (4 - lane) degrees.
	queueEase(655, 668, 'alpha', 1, 'quadInOut', -1);
	var counter = 0;
	var counter2 = 4;
	for (i in 0...4) {
		queueEase(655 + counter, 672, 'transform' + i + 'Y', 300 + (50 * counter2), 'quadIn', -1);
		queueEase(655 + counter, 672, 'confusion' + i, -22.5 * counter2, 'quadInOut', -1);
		counter += 2;
		counter2 -= 1;
	}

	// 688: parked 600px up/down the screen and spun a full turn.  `opponentSwap`
	// 0.5 is both fields meeting in the middle - they are crossing here.
	for (i in 0...4) {
		queueSet(688, 'transform' + i + 'Y', downscroll ? -600 : 600, -1);
		queueSet(688, 'confusion' + i, 360, -1);
		queueSet(688, 'opponentSwap', 0.5, -1);
	}

	// 704-720: they fly back into place, and the *player's* (player 0) field
	// fades back in.
	for (i in 0...4) {
		queueEase(704 - i, 720, 'transform' + i + 'Y', 0, 'expoIn', -1);
		queueEase(704 - i, 720, 'alpha', 0, 'expoIn', 0);
		queueEase(704 - i, 720, 'confusion' + i, 0, 'expoIn', -1);
	}

	// 721-848 and 865-976: every 16 steps a pair of lanes does the work.  The
	// first half squishes lanes 0 and 2 to -0.75 and rotates them -45 * counter
	// while easing both back out over the next 8 steps; the second half does the
	// same for lanes 1 and 3, and `flip` kicks -0.125 for each of the two 8-step
	// halves (the source runs the identical block twice, one iteration shorter
	// the second time - hence the two loops).
	var step = 721;
	var swing = -1;
	while (step < 848) {
		swing *= -1;
		swayBlock(step, swing);
		step += 16;
	}
	step = 865;
	swing = -1;
	while (step < 976) {
		swing *= -1;
		swayBlock(step, swing);
		step += 16;
	}

	// 977-1216: every 16 steps all four lanes snap to their own angle
	// (-45, -45, 45, 45), ease back to 0 over 8 steps, and at +8 the lane's
	// transformY kicks by (-40, 40, -40, 40) * counter and eases home.
	var fuckMath = [-40, 40, -40, 40];
	var fuckMath2 = [-45, -45, 45, 45];
	var counterB = -1;
	step = 977;
	while (step < 1216) {
		counterB *= -1;
		for (i in 0...4) {
			queueSet(step, 'confusion' + i, fuckMath2[i], 0);
			queueEase(step, step + 8, 'confusion' + i, 0, 'circOut', 0);
			queueSet(step + 8, 'transform' + i + 'Y', fuckMath[i] * counterB, 0);
			queueEase(step + 8, step + 16, 'transform' + i + 'Y', 0, 'quartOut', 0);
		}
		step += 16;
	}

	// 977-1360: the fields keep crossing - 0.75 / 0.25 on alternating 16-step
	// blocks, so the two note fields swap sides over and over.
	var counterC = -1;
	step = 977;
	while (step < 1360) {
		counterC = counterC + 1;
		if (counterC > 1) counterC = 0;
		queueEase(step, step + 16, 'opponentSwap', counterC == 0 ? 0.75 : 0.25, 'quadInOut', -1);
		step += 16;
	}

	// 1216-1232: back to the middle.
	queueEase(1216, 1232, 'opponentSwap', 0.5, 'quadInOut', -1);

	// 1232: the *opponent's* field (player 1) goes half transparent, a quarter
	// stealthy and fully reversed for four steps - he is dragged backwards.
	queueEase(1232, 1236, 'stealth', 0.25, 'quadInOut', 1);
	queueEase(1232, 1236, 'alpha', 0.5, 'quadInOut', 1);
	queueEase(1232, 1236, 'reverse', 1, 'quadInOut', 1);

	queueSet(1376, 'opponentSwap', 0.5, -1);

	// 1360-1376: every lane of *both* fields blinks out (lane 2 one block later
	// than 0, 1 and 3) and only the player's field comes back on at 1376 - the
	// opponent's arrows stay faded for the rest of the song.
	queueEase(1360, 1364, 'alpha0', 1, 'expoOut', -1);
	queueEase(1360, 1364, 'alpha1', 1, 'expoOut', -1);
	queueEase(1360, 1364, 'alpha3', 1, 'expoOut', -1);
	queueEase(1364, 1372, 'alpha2', 1, 'expoIn', -1);
	queueEase(1360, 1364, 'alpha', 1, 'expoOut', 1);
	queueSet(1376, 'alpha0', 0, 0);
	queueSet(1376, 'alpha1', 0, 0);
	queueSet(1376, 'alpha2', 0, 0);
	queueSet(1376, 'alpha3', 0, 0);

	for (i in 0...4) {
		queueEase(1375, 1376, 'confusion' + i, 0, 'linear', -1);
		queueEase(1504, 1512, 'confusion' + i, 360, 'backOut', -1);
	}

	// 1297-1360: a flip wobble on the whole field, every 8 steps.
	step = 1297;
	while (step < 1360) {
		queueSet(step, 'flip', -0.25, -1);
		queueEase(step, step + 8, 'flip', 0, 'quadOut', -1);
		step += 8;
	}

	// 1376-1632: the bouncing lanes - every 2 steps a pair of lanes is thrown:
	// first lanes 1 and 2 (up/down), then lanes 0 and 3 (left/right), and the
	// sign alternates each time round.
	var counter0 = 0;
	var arrows0 = 0;
	var tryed = 1;
	step = 1376;
	while (step < 1632) {
		if (arrows0 == 0) {
			if (counter0 == 0) {
				queueEase(step, step + 2, 'transform1Y', 50 * tryed, 'circOut', -1);
				queueEase(step, step + 2, 'transform2Y', -50 * tryed, 'circOut', -1);
				counter0 = 1;
			} else {
				queueEase(step, step + 2, 'transform1Y', 0, 'circIn', -1);
				queueEase(step, step + 2, 'transform2Y', 0, 'circIn', -1);
				counter0 = 0;
				arrows0 = 1;
			}
		} else {
			if (counter0 == 0) {
				queueEase(step, step + 2, 'transform0X', -50, 'circOut', -1);
				queueEase(step, step + 2, 'transform3X', 50, 'circOut', -1);
				counter0 = 1;
			} else {
				queueEase(step, step + 2, 'transform0X', 0, 'circIn', -1);
				queueEase(step, step + 2, 'transform3X', 0, 'circIn', -1);
				counter0 = 0;
				arrows0 = 0;
				tryed = tryed == 1 ? -1 : 1;
			}
		}
		step += 2;
	}

	// 1504-1632: the crossing keeps going straight through the bounce section.
	var counterD = -1;
	step = 1504;
	while (step < 1632) {
		counterD = counterD + 1;
		if (counterD > 1) counterD = 0;
		queueEase(step, step + 16, 'opponentSwap', counterD == 0 ? 0.75 : 0.25, 'quadInOut', -1);
		step += 16;
	}

	// 1632-1648: the fields settle in the middle and every lane un-rotates.
	queueEase(1632, 1648, 'opponentSwap', 0.5, 'expoOut', -1);
	for (i in 0...4)
		queueEase(1632, 1648, 'confusion' + i, 0, 'expoOut', -1);

	// 1648-1762: five accents.  At each of them the field flips -0.12 for 4
	// steps while every lane's confusion kicks by (-20, -10, 10, 20) and eases
	// back; and at four staggered steps (1754/1756/1758/1760) the lanes peel off
	// one at a time in the order 1, 0, 3, 2: -50 down, then 150 further with a
	// full 360 spin.
	var osteps = [1648, 1664, 1696, 1712, 1728];
	var xdddd = [-20, -10, 10, 20];
	var endsteps = [1754, 1756, 1758, 1760];
	var order = [1, 0, 3, 2];
	step = 1648;
	while (step < 1762) {
		for (k in 0...osteps.length)
			if (step == osteps[k]) {
				queueEase(osteps[k], osteps[k] + 4, 'flip', -0.12, 'circOut', -1);
				queueEase(osteps[k] + 4, osteps[k] + 8, 'flip', 0, 'quadIn', -1);
				for (o in 0...4) {
					queueEase(osteps[k], osteps[k] + 4, 'confusion' + o, xdddd[o], 'circOut', -1);
					queueEase(osteps[k] + 4, osteps[k] + 8, 'confusion' + o, 0, 'expoIn', -1);
				}
			}
		for (idx in 0...endsteps.length)
			if (step == endsteps[idx]) {
				queueEase(endsteps[idx], endsteps[idx] + 2, 'transform' + order[idx] + 'Y', -50, 'expoOut', -1);
				queueEase(endsteps[idx] + 2, endsteps[idx] + 12, 'transform' + order[idx] + 'Y', 150, 'expoIn', -1);
				queueEase(endsteps[idx], endsteps[idx] + 16, 'confusion' + order[idx], 360, 'expoOut', -1);
			}
		step += 2;
	}

	// 1754-1762: the last four lanes blink out, one every 2 steps.
	queueEase(1754, 1762, 'alpha0', 1, 'expoIn', -1);
	queueEase(1756, 1764, 'alpha1', 1, 'expoIn', -1);
	queueEase(1758, 1766, 'alpha3', 1, 'expoIn', -1);
	queueEase(1760, 1768, 'alpha2', 1, 'expoIn', -1);

	prepIds();
}

// one 16-step swing block of the 721/865 sections (see create)
function swayBlock(step, sign) {
	queueSet(step, 'flip', -0.25 / 2, 0);
	queueEase(step, step + 8, 'flip', 0, 'quadOut', 0);
	queueSet(step + 8, 'flip', -0.25 / 2, 0);
	queueEase(step + 8, step + 16, 'flip', 0, 'quadOut', 0);
	squish(step, sign, 0, 2);
	squish(step + 8, sign, 1, 3);
}

// `mini{0,2}` / `mini{1,3}` + their confusion, set then eased back out
function squish(step, sign, a, b) {
	var lanes = [a, b];
	for (lane in lanes) {
		queueSet(step, 'mini' + lane + 'X', -0.75, 0);
		queueSet(step, 'mini' + lane + 'Y', -0.75, 0);
		queueSet(step, 'confusion' + lane, -45 * sign, 0);
		queueEase(step, step + 8, 'mini' + lane + 'X', 0, 'circOut', 0);
		queueEase(step, step + 8, 'mini' + lane + 'Y', 0, 'circOut', 0);
		queueEase(step, step + 8, 'confusion' + lane, 0, 'circOut', 0);
	}
}

// id lookups for the values read every frame
var I_SWAP = [0, 0];
var I_FLIP = [0, 0];
var I_ALPHA = [0, 0];
var I_STEALTH = [0, 0];
var I_REVERSE = [0, 0];
var I_TX = [];
var I_TY = [];
var I_CONF = [];
var I_MNX = [];
var I_MNY = [];
var I_AL = [];
function prepIds() {
	for (fw in 0...2) {
		I_SWAP[fw] = idOf('opponentSwap', fw);
		I_FLIP[fw] = idOf('flip', fw);
		I_ALPHA[fw] = idOf('alpha', fw);
		I_STEALTH[fw] = idOf('stealth', fw);
		I_REVERSE[fw] = idOf('reverse', fw);
		I_TX[fw] = [];
		I_TY[fw] = [];
		I_CONF[fw] = [];
		I_MNX[fw] = [];
		I_MNY[fw] = [];
		I_AL[fw] = [];
		for (lane in 0...4) {
			I_TX[fw][lane] = idOf('transform' + lane + 'X', fw);
			I_TY[fw][lane] = idOf('transform' + lane + 'Y', fw);
			I_CONF[fw][lane] = idOf('confusion' + lane, fw);
			I_MNX[fw][lane] = idOf('mini' + lane + 'X', fw);
			I_MNY[fw][lane] = idOf('mini' + lane + 'Y', fw);
			I_AL[fw][lane] = idOf('alpha' + lane, fw);
		}
	}
}

// ── per-frame: evaluate the timeline, then push the values onto the field ─────

function postUpdate(elapsed) {
	if (strumLines == null || strumLines.members == null) return;
	// x, scale and scrollSpeed are final the moment the strums exist, so they are
	// read on the first frame - that is what makes the opening swap land here
	// rather than a second in
	if (!_started) {
		// don't latch before both fields exist, or the whole thing goes dead
		if (strumLines.members[FW_LINE[0]] == null || strumLines.members[FW_LINE[1]] == null) return;
		_started = true;
		captureBase();
	}
	// the intro tween finishes at `0.5 + 0.2 * 3 + 1` = 2.1s at the latest
	if (!_ysettled && Conductor.songPosition >= 2300) {
		_ysettled = true;
		captureBaseY();
	}
	evaluate(Conductor.curStepFloat);
	apply();
}

function captureBase() {
	for (fw in 0...2) {
		_base[fw] = [];
		_dirtyS[fw] = [];
		_dirtyA[fw] = [];
		_dirtyP[fw] = [];
		_dirtyR[fw] = [];
		_noteDirty[fw] = [];
		var line = strumLines.members[FW_LINE[fw]];
		if (line == null) continue;
		for (lane in 0...line.members.length) {
			var s = line.members[lane];
			_dirtyS[fw][lane] = false;
			_dirtyA[fw][lane] = false;
			_dirtyP[fw][lane] = false;
			_dirtyR[fw][lane] = false;
			_noteDirty[fw][lane] = false;
			if (s == null) continue;
			// y is deliberately left empty here: the intro tween is still moving it
			// (see captureBaseY)
			_base[fw][lane] = {x: s.x, y: null, sx: s.scale.x, sy: s.scale.y, ss: s.scrollSpeed};
			// ...and the arrows keep falling *straight* however far the lane turns.
			// In the source `confusion` never touches a note's position - it only
			// writes the sprite angle (ConfusionModifier.updateNote: `note.angle =
			// ...`), so the lane rotates in place and the notes still come down
			// vertically.  Codename projects a note's scroll offset along its
			// `__noteAngle + 90` (Note.draw), and `__noteAngle` comes from the
			// receptor's own `angle` unless the receptor sets `noteAngle`, which is
			// the engine's documented switch for exactly this (Strum.noteAngle: "If
			// you don't want angle of the strum to interfere with the direction the
			// notes are going, you can set noteAngle to = 0").  The notes still
			// *rotate* with the receptor - updateNotePosition hands them the
			// receptor's `angle` as their sprite rotation - they just don't fall
			// along it any more.
			s.noteAngle = 0;
		}
	}
}

// second half of the capture, once the strums have stopped sliding in
function captureBaseY() {
	for (fw in 0...2) {
		if (_base[fw] == null) continue;
		var line = strumLines.members[FW_LINE[fw]];
		if (line == null) continue;
		for (lane in 0..._base[fw].length) {
			var b = _base[fw][lane];
			if (b == null) continue;
			var s = line.members[lane];
			if (s != null) {
				var fieldScale = line.data.strumScale == null ? 1 : line.data.strumScale;
				b.y = (line.data.strumPos == null ? 50 : line.data.strumPos[1])
					+ Note.swagWidth / 2 * (1 - fieldScale);
			}
		}
	}
}

// walks the timeline in the order the source queued it, which is chronological
// per modifier: a `set` lands instantly, an `ease` captures its starting value
// on its first frame and interpolates until `end`
function evaluate(cur) {
	// pick up everything whose start step the playhead has just passed; the
	// buckets make this O(new events) instead of O(the whole timeline)
	var st = Math.floor(cur);
	while (_lastStep < st) {
		_lastStep++;
		var bucket = _atStep[_lastStep];
		if (bucket == null) continue;
		for (e in bucket) _live.push(e);
	}

	// then walk only what is still running, compacting the finished ones out of
	// `_live` in place so the list stays as short as the busiest section needs
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
		var otherLine = strumLines.members[FW_LINE[1 - fw]];
		var swap = _vals[I_SWAP[fw]];
		var flip = _vals[I_FLIP[fw]];
		var alphaG = 1 - _vals[I_ALPHA[fw]];
		var stealthG = 1 - _vals[I_STEALTH[fw]];
		var rev = _vals[I_REVERSE[fw]];

		// the per-lane multipliers, so the note pass below runs once per field
		var laneA = [];
		var laneMX = [];
		var laneMY = [];
		var anyNotes = false;

		for (lane in 0...line.members.length) {
			var s = line.members[lane];
			var b = _base[fw][lane];
			if (b == null) continue;

			// opponentSwap: slide this lane to the same lane of the other field
			// (`distX * value`, OpponentModifier.getPos)
			var bx = b.x;
			if (swap != 0 && otherLine != null && _base[1 - fw][lane] != null)
				bx += (_base[1 - fw][lane].x - bx) * swap;
			// flip: `swagWidth * (arrows / 2) * (1.5 - lane) * value`
			// (FlipModifier.getPos)
			if (flip != 0)
				bx += Note.swagWidth * (line.members.length / 2) * (1.5 - lane) * flip;

			var a = alphaG * (1 - _vals[I_AL[fw][lane]]);
			var mx = 1 - _vals[I_MNX[fw][lane]];
			var my = 1 - _vals[I_MNY[fw][lane]];

			if (s != null) {
				// only write when the value actually moves, so the long stretches
				// where nothing drives a lane cost the engine nothing at all
				var x = bx + _vals[I_TX[fw][lane]];
				if (s.x != x) s.x = x;
				// no y at all until the intro tween is over (see captureBaseY)
				if (b.y != null) {
					// Reverse supplies the baseline BEFORE transformY. HudCamera
					// already mirrors downscroll, so only the transform delta inverts.
					var ty = _vals[I_TY[fw][lane]] * (downscroll ? -1 : 1);
					var y = (rev == 0 ? b.y : 50 + (FlxG.height - 200) * rev) + ty;
					if (s.y != y) s.y = y;
				}

				var conf = _vals[I_CONF[fw][lane]];
				if (conf != 0 || _dirtyA[fw][lane]) {
					s.angle = conf;
					_dirtyA[fw][lane] = conf != 0;
				}

				if (mx != 1 || my != 1 || _dirtyS[fw][lane]) {
					s.scale.x = b.sx * mx;
					s.scale.y = b.sy * my;
					_dirtyS[fw][lane] = mx != 1 || my != 1;
				}

				if (a != 1 || _dirtyP[fw][lane]) {
					s.alpha = a;
					_dirtyP[fw][lane] = a != 1;
				}

				if (rev != 0 || _dirtyR[fw][lane]) {
					s.scrollSpeed = rev == 0 ? b.ss : (b.ss == null ? scrollSpeed : b.ss) * (1 - 2 * rev);
					_dirtyR[fw][lane] = rev != 0;
				}
			}

			// Stealth affects notes only. With source getAlpha and stealth 0.25,
			// visibility is 0.75 -> opacity 1, not a flat 0.75 multiplier.
			laneA[lane] = a * Math.max(0, Math.min(1, 2 * stealthG));
			laneMX[lane] = mx;
			laneMY[lane] = my;
			if (laneA[lane] != 1 || mx != 1 || my != 1) anyNotes = true;
		}

		if (anyNotes || hasDirtyNotes(fw)) notePass(fw, line, laneA, laneMX, laneMY);
	}
}

function hasDirtyNotes(fw) {
	for (lane in 0..._noteDirty[fw].length)
		if (_noteDirty[fw][lane]) return true;
	return false;
}

// notes are drawn relative to the receptor, so only their own alpha and scale
// have to be written - and only while a mod actually moves them.
//
// `NoteGroup.forEach` and not a walk over `notes.members`: the group is sized
// for the whole chart up front (`preallocate`) and sorted by strumTime
// *descending*, so `forEach` starts at the tail - the oldest notes - and stops
// at the first one further away than the group's `limit`, i.e. it hands over
// only the notes that can still be on screen.  That is the documented way to
// iterate it ("Using `forEach` on this group will only loop through the first
// notes for performance reasons", StrumLine.notes) and it is what the engine's
// own note update uses.  Walking `members` instead poked at every note in the
// chart, every frame, for both fields - that was the framerate.
function notePass(fw, line, laneA, laneMX, laneMY) {
	var now = Conductor.songPosition;
	line.notes.forEach(function(n) {
		if (n == null || !n.exists) return;
		// a note that has scrolled past can't show a mod either
		var dt = n.strumTime - now;
		if (dt < -2000 || dt > 5000) return;
		var lane = n.noteData % line.members.length;
		var a = laneA[lane] == null ? 1 : laneA[lane];
		var mx = laneMX[lane] == null ? 1 : laneMX[lane];
		var my = laneMY[lane] == null ? 1 : laneMY[lane];
		if (a == 1 && mx == 1 && my == 1) {
			// `restoreNote` is a no-op unless this note is still modified, so this
			// peels every arrow of a lane that just went clean - not only the
			// first one the loop happens to meet (the flag stays up until the
			// whole line has been walked)
			restoreNote(n);
			return;
		}
		if (!n.extra.exists('mmModA')) {
			n.extra.set('mmModA', n.alpha);
			n.extra.set('mmModSX', n.scale.x);
			n.extra.set('mmModSY', n.scale.y);
		}
		n.alpha = n.extra.get('mmModA') * a;
		// a sustain's y scale is its own length, the source leaves it alone too
		if (n.isSustainNote) n.scale.x = n.extra.get('mmModSX') * mx;
		else {
			n.scale.x = n.extra.get('mmModSX') * mx;
			n.scale.y = n.extra.get('mmModSY') * my;
		}
		_noteDirty[fw][lane] = true;
	});
	// a lane that is clean now had every one of its notes restored above, so its
	// flag can drop; a lane still under a mod keeps its flag up so the next frame
	// still runs this pass even when `anyNotes` goes back to false
	for (l in 0..._noteDirty[fw].length) {
		var la = laneA[l] == null ? 1 : laneA[l];
		var lx = laneMX[l] == null ? 1 : laneMX[l];
		var ly = laneMY[l] == null ? 1 : laneMY[l];
		if (la == 1 && lx == 1 && ly == 1) _noteDirty[fw][l] = false;
	}
}

function restoreNote(n) {
	if (!n.extra.exists('mmModA')) return;
	n.alpha = n.extra.get('mmModA');
	if (n.isSustainNote) n.scale.x = n.extra.get('mmModSX');
	else {
		n.scale.x = n.extra.get('mmModSX');
		n.scale.y = n.extra.get('mmModSY');
	}
	n.extra.remove('mmModA');
	n.extra.remove('mmModSX');
	n.extra.remove('mmModSY');
}
