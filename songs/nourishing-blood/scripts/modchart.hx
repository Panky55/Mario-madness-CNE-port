// ═══════════════════════════════════════════════════════════════════════════════
// Nourishing Blood - the note field modchart
// ═══════════════════════════════════════════════════════════════════════════════
//
// `case 'nourishing blood'` of `Mario-Madness/source/modchart/Modcharts.hx`
// (37-96): the busiest of the ten.  Two sections:
//
//   656-912, every 2 steps alternating: all four lanes of *both* fields are
//           squished (`mini{i}X -0.5`, `mini{i}Y 0.5`), thrown 30px down
//           (`transform{i}Y 30`) and eased back out - `transformY` to -30 with
//           quadOut, the mini pair to 0 with circOut - and on the next 2-step
//           block the lanes overshoot the other way (`transformY 0` quadIn,
//           `miniX 0.3` / `miniY -0.3` circIn).  It reads as the field boiling.
//           Over the last 128 steps of that, every 4 steps, all four lanes also
//           get a fresh random `confusion{i}` in [-60, 60] deg (linear) and the
//           two fields trade places and back (`opponentSwap` 0.05 / -0.05,
//           alternating).
//   912    everything snaps back to neutral and the confusion/swap ease home
//          over 4 steps with backOut.
//   944-1168, every 32 steps: a `transform{i}Y` "wave" climbs 10 per lane per
//          half-block (`number`), up to the 40 cap - the player's field first
//          (i 0-3, value `number * -1` expoOut over 2 steps, back to 0 expoIn
//          over the next 2), then the *opponent's* field 16 steps later, one
//          lane every 4 steps.  The `number` bump is inside the i loop, so the
//          cap lands in the same place as the source's: from the second block
//          on every lane runs at the cap (40).
//
// The timeline is handed to `songs/MMmodfields.hx`, the port of the fork's
// modifier framework that every modcharted song feeds - one array per queued
// call, `[startStep, endStep, name, value, style, player]`, with `player = -1`
// meaning both fields (the source's default) and `style = null` a `queueSet`.
// `Conductor.curStepFloat` is the source's `Conductor.getStep()`, so every step
// below is copied over verbatim.
//
// Confusion values use FlxG.random.float, the same RNG as ModManager's
// randomFloat wrapper, and are drawn once when this timeline is created.

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

// the source's `modManager.randomFloat(min, max)` = `FlxG.random.float`
function mmRandom(minV, maxV) {
	return FlxG.random.float(minV, maxV);
}

function create() {
	// ── 656-912: the 2-step squish / overshoot alternation ────────────────────
	var counter = 0;
	var step = 656;
	while (step < 912) {
		if (counter == 0) {
			for (i in 0...4) {
				qs(step, 'mini' + i + 'X', -0.5, -1);
				qs(step, 'mini' + i + 'Y', 0.5, -1);
				qs(step, 'transform' + i + 'Y', 30, -1);
				qe(step, step + 2, 'transform' + i + 'Y', -30, 'quadOut', -1);
				qe(step, step + 2, 'mini' + i + 'X', 0, 'circOut', -1);
				qe(step, step + 2, 'mini' + i + 'Y', 0, 'circOut', -1);
			}
			counter = 1;
		} else {
			for (i in 0...4) {
				qe(step, step + 2, 'transform' + i + 'Y', 0, 'quadIn', -1);
				qe(step, step + 2, 'mini' + i + 'X', 0.3, 'circIn', -1);
				qe(step, step + 2, 'mini' + i + 'Y', -0.3, 'circIn', -1);
			}
			counter = 0;
		}
		step += 2;
	}

	// ── 784-912: every 4 steps a new random confusion per lane, and the two
	// fields see-saw across each other (0.05 / -0.05)
	var counter2 = 0;
	step = 784;
	while (step < 912) {
		for (i in 0...4)
			qe(step, step + 4, 'confusion' + i, mmRandom(-60, 60), 'linear', -1);
		if (counter2 == 0) {
			qe(step, step + 4, 'opponentSwap', 0.05, 'linear', -1);
			counter2 = 1;
		} else {
			qe(step, step + 4, 'opponentSwap', -0.05, 'linear', -1);
			counter2 = 0;
		}
		step += 4;
	}

	// ── 912-916: neutral again. Keep all four source opponentSwap eases:
	// each captures its start after the previous event updates that modifier.
	for (i in 0...4) {
		qs(912, 'mini' + i + 'X', 0, -1);
		qs(912, 'mini' + i + 'Y', 0, -1);
		qs(912, 'transform' + i + 'Y', 0, -1);
		qe(912, 916, 'confusion' + i, 0, 'backOut', -1);
		qe(912, 916, 'opponentSwap', 0, 'backOut', -1);
	}

	// ── 944-1168: the transformY wave.  `number` climbs by 10 inside the lane
	// loop, capped at 40, so from the second 32-step block on every lane runs
	// at the cap - the source's own arithmetic, kept as it is.
	var number = 0;
	step = 944;
	while (step < 1168) {
		for (i in 0...8) {
			if (number > 40) number = 40;
			if (i < 4) {
				qe(step + (i * 4), step + (i * 4) + 2, 'transform' + i + 'Y', number * -1, 'expoOut', 1);
				qe(step + (i * 4) + 2, step + (i * 4) + 4, 'transform' + i + 'Y', 0, 'expoIn', 1);
			} else {
				qe(step + (i * 4), step + (i * 4) + 2, 'transform' + (i - 4) + 'Y', number * -1, 'expoOut', 0);
				qe(step + (i * 4) + 2, step + (i * 4) + 4, 'transform' + (i - 4) + 'Y', 0, 'expoIn', 0);
			}
			number += 10;
		}
		step += 32;
	}

	mmPublish('nourishing blood');
}
