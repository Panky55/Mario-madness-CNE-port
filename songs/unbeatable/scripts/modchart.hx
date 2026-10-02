// ═══════════════════════════════════════════════════════════════════════════════
// Unbeatable - the note field modchart
// ═══════════════════════════════════════════════════════════════════════════════
//
// `case 'unbeatable'` of `Mario-Madness/source/modchart/Modcharts.hx` (442-528):
// the longest of the ten and the only one that reaches past the swap/alpha
// language Day Out speaks.  Five acts, in the source's own order:
//
//   hardstyle       dad's field fades out at 1344-1352 (quadInOut) while the
//                   two fields meet in the middle (opponentSwap 0.5,
//                   cubeInOut, player 0) and everything snaps home at 1696.
//   duck hunt       the pair meet again from 2896, home at 3152.
//   bowser          the same two moves at 3968-3992, home at 4736, and the
//                   fields meet once more at 4815.
//   the bump        at 5776+ the whole field bumps (`transformZ`, nine
//                   staggered steps - see below); at 5582-5586 the fields meet
//                   (bounceOut) with dad's field coming back to alpha 1.
//   GF's finale     from 5712 to 5840 dad's field is thrown: `tipsy 1` (a 45px
//                   cosine y sway per lane), `flip -1` (his lanes fan out by
//                   three quarters of the flip distance), `transform1X/2X`
//                   -230 / 230 (the two inner lanes peeled apart),
//                   `alpha 0.5`, `sudden 2` and `stealth 0.5`.  Then every 4
//                   steps from 5840 to 6096 a `flip -0.125` snap eases back
//                   to 0 - on BF's field until 5961, on dad's from there - and
//                   at 5964-5968 the fields swap those roles with bounceOut.
//                   6096-6104 unwinds the finale (alpha, stealth, sudden, beat).
//   the last word   at 6228 BF's field collapses: `mini -0.625` (one and five
//                   eighths up), the field going `centered 1` + `split 1` (every
//                   lane's receptor pulled to the middle of the screen, with
//                   lanes 2-3 scrolling the other way - the two halves part),
//                   `flip 0`, `transform1X/2X 0` and `alpha{i} 1` (all four
//                   lanes hidden) with `alpha 0` on top.  Lanes 0 and 2 then
//                   blink: visible at 6248-6254, back off at 6272-6280.
//
// `transformZ` is the one thing here that no renderer can show: the fork's
// `PlayState.update()` only ever reads `pos.x` and `pos.y` back off the
// modifier system, and the two modifiers that do read `z` (Rotate with an
// origin, Perspective) are not active anywhere in this case - the bump's nine
// staggered steps are invisible in the fork too.  The values are kept so the
// timeline reads like the source's.
//
// The two lines the source has commented out inside this case
// (`queueSet(5586, "transformY", 400, 1)` and the matching `transformY 0` at
// 5712-5840) are not ported - they are dead code in the fork as well.
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
	// ── hardstyle ────────────────────────────────────────────────────────────
	qe(1344, 1352, 'alpha', 1, 'quadInOut', 1);
	qe(1360, 1376, 'opponentSwap', 0.5, 'cubeInOut', 0);
	qs(1696, 'opponentSwap', 0, -1);
	qs(1696, 'alpha', 0, -1);

	// ── duck hunt ────────────────────────────────────────────────────────────
	qs(2896, 'opponentSwap', 0.5, -1);
	qs(2896, 'alpha', 1, 1);
	qs(3152, 'opponentSwap', 0, -1);
	qs(3152, 'alpha', 0, -1);

	// ── bowser ───────────────────────────────────────────────────────────────
	qe(3968, 3984, 'alpha', 1, 'quadInOut', 1);
	qe(3976, 3992, 'opponentSwap', 0.5, 'cubeInOut', 0);
	qs(4736, 'opponentSwap', 0, -1);
	qs(4736, 'alpha', 0, -1);
	qs(4815, 'opponentSwap', 0.5, -1);
	qs(4815, 'alpha', 1, 1);

	// ── the bump: nine staggered transformZ hits (invisible, see the header) ─
	var bumpSteps = [5776, 5792, 5808, 5816, 5824, 5832, 5834, 5836, 5838];
	qe(5582, 5586, 'opponentSwap', 0.5, 'bounceOut', -1);
	qe(5582, 5586, 'alpha', 1, 'bounceOut', 1);
	for (bstep in bumpSteps) {
		qs(bstep, 'transformZ', 0.125, -1);
		qe(bstep, bstep + 8, 'transformZ', 0, 'quadOut', -1);
	}

	// ── GF's finale ──────────────────────────────────────────────────────────
	qe(5712, 5840, 'tipsy', 1, 'quadInOut', -1);
	qe(5712, 5840, 'flip', -1, 'quadInOut', 1);
	qe(5712, 5840, 'transform1X', (-342) + 112, 'quadInOut', 1);
	qe(5712, 5840, 'transform2X', 342 - 112, 'quadInOut', 1);
	qe(5712, 5840, 'alpha', 0.5, 'quadInOut', 1);
	qe(5712, 5840, 'sudden', 2, 'quadInOut', 1);
	qe(5712, 5840, 'stealth', 0.5, 'quadInOut', 1);

	qe(5840, 5844, 'tipsy', 0.25, 'quadInOut', -1);
	qe(5840, 5844, 'beat', 0.5, 'quadInOut', -1);

	// 5840-6096: a flip snap every 4 steps, eased back with quartOut.  On BF's
	// field until step 5961, on dad's from there - the source's `strum` switch,
	// kept as it is.
	var strum = 0;
	var step = 5840;
	while (step < 6096) {
		if (step >= 5961) strum = 1;
		qs(step, 'flip', -0.125, strum);
		qe(step, step + 4, 'flip', 0, 'quartOut', strum);
		step += 4;
	}

	qe(5964, 5968, 'transform1X', 0, 'bounceOut', 1);
	qe(5964, 5968, 'transform2X', 0, 'bounceOut', 1);
	qe(5964, 5968, 'transform1X', (-342) + 112, 'bounceOut', 0);
	qe(5964, 5968, 'transform2X', 342 - 112, 'bounceOut', 0);
	qe(5964, 5968, 'flip', -1, 'bounceOut', 0);
	qe(5964, 5968, 'flip', 0, 'bounceOut', 1);

	qe(6096, 6104, 'alpha', 1, 'quadOut', 0);
	qe(6096, 6104, 'alpha', 0, 'quadOut', 1);
	qe(6096, 6104, 'stealth', 0, 'quadOut', 1);
	qe(6096, 6104, 'sudden', 0, 'quadOut', 1);
	qe(6096, 6104, 'beat', 0, 'quadOut', -1);

	// ── the last word ────────────────────────────────────────────────────────
	qe(6224, 6228, 'alpha', 1, 'quadOut', 1);

	qs(6228, 'mini', -0.625, 0);
	qs(6228, 'tipsy', 0, -1);
	qs(6228, 'alpha', 0, 0);
	for (i in 0...4) qs(6228, 'alpha' + i, 1, 0);
	qs(6228, 'transform1X', 0, 0);
	qs(6228, 'transform2X', 0, 0);
	qs(6228, 'flip', 0, 0);
	qs(6228, 'centered', 1, 0);
	qs(6228, 'split', 1, 0);

	qe(6248, 6254, 'alpha0', 0, 'quadOut', -1);
	qe(6248, 6254, 'alpha2', 0, 'quadOut', -1);
	qe(6272, 6280, 'alpha0', 1, 'quadOut', -1);
	qe(6272, 6280, 'alpha2', 1, 'quadOut', -1);

	mmPublish('unbeatable');
}
