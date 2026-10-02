// ═══════════════════════════════════════════════════════════════════════════════
// The Mario's Madness note-field modchart framework
// ═══════════════════════════════════════════════════════════════════════════════
//
// `Mario-Madness/source/modchart/` is a Schmovin'/Andromeda-style modifier
// framework.  `Modcharts.loadModchart(modManager, songName)` fills its
// `EventTimeline` from a per-song `case`, and `PlayState.update()` then runs
// `modManager.getPos(...)`+`updateObject(...)` over every receptor and every
// note, every frame (PlayState.hx:8218-8295).  A mod is a value in `[0..1]`
// (a "percent" is the same number times 100) that gets *added* to the note
// field's position/scale/angle/alpha; an `EaseEvent` walks one from its old
// value to a new one between two steps.
//
// This script is that framework, ported, and it is shared by the songs whose
// `Modcharts.hx` case the port carries (`songs/<song>/scripts/modchart.hx`).
// It is one script for the same reason `songs/MMcamera.hx` is: the fork's field
// model has no Codename equivalent to hang a per-song copy off.
//
// WHY IT CAN BE SHARED
// --------------------
// The song's script does not call this one; it *publishes its timeline* into the
// engine's ScriptPack (`PlayState.instance.scripts.set('mmModField', [...])`,
// the same cross-script channel `MMcamera` uses for its api), and this script
// reads it back on its first frame and drives the field from then on.  So the
// per-song file stays exactly what the source's `case` is - a list of
// `queueSet`/`queueEase`/`setValue` calls in the source's own order - and the
// framework and its math live in one place.  `mods/*/songs/` scripts load for
// every song (PlayState.hx:753-763), so for a song with no timeline this costs
// one `scripts.get` on its first frame and then nothing.
//
// The published array is one entry per queued call:
//
//     [startStep, endStep, name, value, style, player]
//
// `startStep < 0` is the source's `setValue` (applied at load, no ease),
// `style == null` is a `queueSet` (a snap at `startStep`), `player == -1` means
// both fields - the source's default.  The per-song files spell `-1` out.
//
// WHAT IT PORTED
// --------------
// Only the modifiers the eleven modcharted songs actually drive, out of the
// framework's full set (RotateModifier, LocalRotateModifier, PerspectiveModifier,
// InfinitePathModifier, InvertModifier, BumpyEffect and the `-a` "add" variants
// of a submod are not among them and are not ported):
//
//   opponentSwap  pos.x += (other field's base x - own base x) * value
//   flip          pos.x += swagWidth * (lanes/2) * (1.5 - lane) * value
//   transformX/Y  pos.x/y += value, plus the per-lane `transform{i}X/Y`
//   mini          scale *= 1 - value, plus `mini{i}X` / `mini{i}Y`
//   confusion     angle = value + `confusion{i}`
//   alpha         the `stealth` modifier's submod: receptor and note alpha both
//                 multiply by `(1 - alpha) * (1 - alpha{i})`
//   stealth       the same modifier's *base* value - the source's `getVisibility`
//                 curve, which fades a *note* by how far down the screen it is
//   sudden        the visibility band of `getVisibility` (`hidden` is the other
//                 half of the pair and is implemented beside it)
//   reverse       pos.y = shift + visualDiff * mult, with the `split`,
//                 `alternate`, `cross`, `centered` and per-lane `reverse{i}`
//                 submods that feed it. CNE's HudCamera mirrors y under
//                 downscroll already, so the raw reverse fraction belongs in
//                 logical camera coordinates; complementing it here would
//                 apply downscroll twice.
//   drunk         pos.x += value * cos(t + lane*0.2 + visualDiff*10/height) * 56
//   tipsy         pos.y += value * cos(t*1.2 + lane*1.8) * 44.8
//   beat          pos.x += value * 40 * amount * sin(visualDiff/30 + PI/2)
//
// `transformZ` is *evaluated* (it is a value like any other) but has no effect:
// Codename's field is 2D, and the per-lane z offsets the source's bump section
// runs on are invisible in its own renderer too (its z only matters to the
// Rotate/Perspective modifiers, which this port does not carry).
//
// HOW A VALUE REACHES THE FIELD
// -----------------------------
// Codename draws every note **relative to its receptor** - `Note.draw()` adds
// `__strum.x/y` to the note's own scroll offset, and `Strum.updateNotePosition`
// hands the note the receptor's angle (`Note.hx` / `Strum.hx`).  Moving, scaling
// or spinning a receptor therefore moves that whole lane, which is exactly what
// the source's `getPos`+`updateObject` do by rewriting every arrow's own
// position.  So:
//
//   * x, angle, scale, alpha and scrollSpeed are written on the receptors;
//   * y is rebuilt from the final strum baseline, like the source. An intro
//     tween writes an absolute y, so subtracting last frame's mod delta from
//     it loses the transform and can leave the field displaced permanently.
//   * `reverse`/`centered` are the one exception: they put the receptor at an
//     *absolute* y (`shift`), which is what the source does with `pos.y = ...`.
//   * the mods that depend on a note's own scroll offset (`drunk`, `beat` and
//     the `sudden` visibility band) are written onto the note itself in the note
//     pass - absolute note x for the first two, `n.alpha` for the last.
//     Note.draw and Flixel cancel offset.x, so offset is not a position mod.
//
// `confusion` therefore rotates a lane without steering its notes: the port
// sets `noteAngle = 0` on the receptors (the engine's documented switch for
// "use the angle of the strum without affecting the direction of the notes";
// `Strum.noteAngle`), because in the source `ConfusionModifier` only writes the
// sprite angle and the arrows keep falling straight.
//
// One more mapping detail: the source fades a note through its `ColorSwap`
// shader (`colorSwap.daAlpha`), which has no counterpart here, so both alphas
// are written on the sprites.  Same result, one less shader.
//
// FIELD ORDER
// -----------
// `FW_LINE` maps the framework's player ids onto `strumLines.members`: the
// source's player 0 is `playerStrums` (BF) and player 1 `opponentStrums` (dad)
// (`Modifier.hx`: "player is 0 for bf, 1 for dad"; `AlphaModifier.updateNote`:
// `note.mustPress ? 0 : 1`), while the ported charts put the opponent line
// first (`PlayState.hx:6274` builds the same pair in the same order in the
// fork).  So framework 0 -> members[1] (BF) and framework 1 -> members[0] (dad).

var FW_LINE = [1, 0];

// ── timeline ─────────────────────────────────────────────────────────────────
var _keys = [];      // "name#player" per id
var _vals = [];      // current value per id
var _atStep = [];    // start step -> the events that begin there
var _live = [];      // events that have started and have not finished
var _lastStep = -1;
var _loaded = false; // the song's timeline has been read
var _off = false;    // ... and there was none - stop looking
var _started = false;

// ── per-field / per-lane state ───────────────────────────────────────────────
var _base = [];        // [fw][lane] -> {x, y, sx, sy, ss}
var _dirtyAng = [];    // the receptor's angle / scale / alpha / scroll were
var _dirtyScale = [];  // touched last frame, so they have to be written back
var _dirtyAlpha = [];  // to the engine's own values even once the mod is 0
var _dirtySS = [];
var _noteDirty = [];   // a lane whose arrows still carry a mod

// ── note-pass scratch (see _notePass) ────────────────────────────────────────
var _pA = [];          // per lane: the note's alpha multiplier
var _pFX = [];         // per lane: the note's scale multipliers
var _pFY = [];
var _pCos = [];        // per lane: the receptor's own cos() term (drunk)
var _pVisibilityY = []; // position without reverse, as AlphaModifier requests
var _pScroll = 1.0;
var _pDrunk = 0;
var _pBeat = 0;
var _pBeatAmt = 0;
var _pStealth = 0;
var _pHidden = 0;
var _pSudden = 0;
var _pHiddenStart = 0;
var _pHiddenEnd = 0;
var _pSudStart = 0;
var _pSudEnd = 0;
var _pTime = 0;

// ── ids for the values read every frame ──────────────────────────────────────
// plain indices into `_vals`, so the hot path never hashes a string
var I_SWAP = [0, 0];
var I_FLIP = [0, 0];
var I_TX = [0, 0];
var I_TY = [0, 0];
var I_TZ = [0, 0];
var I_MINI = [0, 0];
var I_CONF = [0, 0];
var I_ALPHA = [0, 0];
var I_STEALTH = [0, 0];
var I_DRUNK = [0, 0];
var I_TIPSY = [0, 0];
var I_BEAT = [0, 0];
var I_SUDDEN = [0, 0];
var I_HIDDEN = [0, 0];
var I_REV = [0, 0];
var I_CENTER = [0, 0];
var I_SPLIT = [0, 0];
var I_ALT = [0, 0];
var I_CROSS = [0, 0];
var I_TXi = [];
var I_TYi = [];
var I_TZi = [];
var I_MNXi = [];
var I_MNYi = [];
var I_CONFi = [];
var I_ALPHAi = [];
var I_REVi = [];

// ── tiny math helpers (the source's CoolUtil.scale, spelled out) ─────────────

// CoolUtil.scale(value, min, max, newMin, newMax)
function _scale(v, mn, mx, nMn, nMx) {
	return nMn + (v - mn) * (nMx - nMn) / (mx - mn);
}

function _clamp(v, lo, hi) {
	if (v < lo) return lo;
	if (v > hi) return hi;
	return v;
}

// Conductor.songPosition in seconds (the source's `time` in the drunk/tipsy
// math).  Seconds, not ms: the fork divides by 1000 every frame.
function _timeSec() {
	return Conductor.songPosition / 1000;
}

// ── timeline plumbing ────────────────────────────────────────────────────────

function _idOf(name, player) {
	var key = name + '#' + player;
	for (i in 0..._keys.length)
		if (_keys[i] == key) return i;
	_keys.push(key);
	_vals.push(0.0);
	return _keys.length - 1;
}

// `ModManager.queueEase` resolves its style through
// `Reflect.getProperty(FlxEase, style)` inside a try/catch and keeps
// `FlxEase.linear` when that comes back null, which is also what a missing or
// unknown style does here.
function _easeOf(style) {
	switch (style) {
		case 'quadIn': return FlxEase.quadIn;
		case 'quadOut': return FlxEase.quadOut;
		case 'quadInOut': return FlxEase.quadInOut;
		case 'quartOut': return FlxEase.quartOut;
		case 'circIn': return FlxEase.circIn;
		case 'circOut': return FlxEase.circOut;
		case 'circInOut': return FlxEase.circInOut;
		case 'expoIn': return FlxEase.expoIn;
		case 'expoOut': return FlxEase.expoOut;
		case 'cubeOut': return FlxEase.cubeOut;
		case 'cubeInOut': return FlxEase.cubeInOut;
		case 'backOut': return FlxEase.backOut;
		case 'backInOut': return FlxEase.backInOut;
		case 'bounceOut': return FlxEase.bounceOut;
		case 'elasticOut': return FlxEase.elasticOut;
	}
	return FlxEase.linear;
}

function _pushOne(start, end, name, value, style, player) {
	var e = {
		id: _idOf(name, player),
		start: start,
		end: end,
		to: value,
		ease: style == null ? null : _easeOf(style),
		from: null,
		done: false
	};
	var st = Math.floor(start);
	if (_atStep[st] == null) _atStep[st] = [];
	_atStep[st].push(e);
}

// the source's queue functions: player -1 runs the call for both players
function _push(start, end, name, value, style, player) {
	if (player == -1) {
		_pushOne(start, end, name, value, style, 0);
		_pushOne(start, end, name, value, style, 1);
	} else
		_pushOne(start, end, name, value, style, player);
}

// `ModManager.setValue(mod, val, player)` - no step, in effect from load
function _setNow(name, value, player) {
	if (player == -1) {
		_vals[_idOf(name, 0)] = value;
		_vals[_idOf(name, 1)] = value;
	} else
		_vals[_idOf(name, player)] = value;
}

// The timeline the song's script published: one array per queued call, in the
// source's own order (see the header).
function _loadEvents(raw) {
	for (e in raw) {
		if (e == null || e.length < 4) continue;
		var start = e[0];
		var end = e[1];
		var name = e[2];
		var value = e[3];
		var style = e.length > 4 ? e[4] : null;
		var player = e.length > 5 ? e[5] : -1;
		if (start < 0) _setNow(name, value, player);
		else _push(start, end, name, value, style, player);
	}
}

// id lookups for the values the per-frame path reads
function _prepIds() {
	for (fw in 0...2) {
		I_SWAP[fw] = _idOf('opponentSwap', fw);
		I_FLIP[fw] = _idOf('flip', fw);
		I_TX[fw] = _idOf('transformX', fw);
		I_TY[fw] = _idOf('transformY', fw);
		I_TZ[fw] = _idOf('transformZ', fw);
		I_MINI[fw] = _idOf('mini', fw);
		I_CONF[fw] = _idOf('confusion', fw);
		I_ALPHA[fw] = _idOf('alpha', fw);
		I_STEALTH[fw] = _idOf('stealth', fw);
		I_DRUNK[fw] = _idOf('drunk', fw);
		I_TIPSY[fw] = _idOf('tipsy', fw);
		I_BEAT[fw] = _idOf('beat', fw);
		I_SUDDEN[fw] = _idOf('sudden', fw);
		I_HIDDEN[fw] = _idOf('hidden', fw);
		I_REV[fw] = _idOf('reverse', fw);
		I_CENTER[fw] = _idOf('centered', fw);
		I_SPLIT[fw] = _idOf('split', fw);
		I_ALT[fw] = _idOf('alternate', fw);
		I_CROSS[fw] = _idOf('cross', fw);
		I_TXi[fw] = [];
		I_TYi[fw] = [];
		I_TZi[fw] = [];
		I_MNXi[fw] = [];
		I_MNYi[fw] = [];
		I_CONFi[fw] = [];
		I_ALPHAi[fw] = [];
		I_REVi[fw] = [];
		for (lane in 0...4) {
			I_TXi[fw][lane] = _idOf('transform' + lane + 'X', fw);
			I_TYi[fw][lane] = _idOf('transform' + lane + 'Y', fw);
			I_TZi[fw][lane] = _idOf('transform' + lane + 'Z', fw);
			I_MNXi[fw][lane] = _idOf('mini' + lane + 'X', fw);
			I_MNYi[fw][lane] = _idOf('mini' + lane + 'Y', fw);
			I_CONFi[fw][lane] = _idOf('confusion' + lane, fw);
			I_ALPHAi[fw][lane] = _idOf('alpha' + lane, fw);
			I_REVi[fw][lane] = _idOf('reverse' + lane, fw);
		}
	}
}

// ── per-frame ────────────────────────────────────────────────────────────────

function postUpdate(elapsed) {
	var ps = PlayState.instance;
	if (ps == null) return;
	if (!_loaded && !_off) {
		var raw = (ps.scripts == null) ? null : ps.scripts.get('mmModField');
		if (raw == null && PlayState.SONG.stage == 'demiseport') {
			// PlayState.hx:3042 + 7699-7700: Demise has flipchar but no song
			// timeline, so the default branch swaps both fields, including Old.
			raw = [[-1, -1, 'opponentSwap', 1, null, -1]];
		}
		if (raw == null) {
			_off = true;
			return;
		}
		_loadEvents(raw);
		_loaded = true;
	}
	if (!_loaded) return;
	if (!_started) {
		// the strums exist before the first frame (`generateStrums` runs inside
		// PlayState.create), but a script can be updated before they are there
		if (!_captureBase()) return;
		_prepIds();
		_started = true;
	}
	_evaluate(Conductor.curStepFloat);
	_apply();
}

// Capture x/scale/speed when strums exist; derive the settled y from chart data,
// never from a moving intro tween or a previously applied modifier.
function _captureBase() {
	for (fw in 0...2) {
		var line = strumLines.members[FW_LINE[fw]];
		if (line == null || line.members == null) return false;
		if (line.members.length == 0) return false;
	}
	for (fw in 0...2) {
		var line = strumLines.members[FW_LINE[fw]];
		_base[fw] = [];
		_dirtyAng[fw] = [];
		_dirtyScale[fw] = [];
		_dirtyAlpha[fw] = [];
		_dirtySS[fw] = [];
		_noteDirty[fw] = [];
		for (lane in 0...line.members.length) {
			var s = line.members[lane];
			_dirtyAng[fw][lane] = false;
			_dirtyScale[fw][lane] = false;
			_dirtyAlpha[fw][lane] = false;
			_dirtySS[fw][lane] = false;
			_noteDirty[fw][lane] = false;
			if (s == null) {
				_base[fw][lane] = null;
				continue;
			}
			var baseline = line.data.strumPos == null ? 50 : line.data.strumPos[1];
			var fieldScale = line.data.strumScale == null ? 1 : line.data.strumScale;
			baseline += Note.swagWidth * 0.5 * (1 - fieldScale);
			_base[fw][lane] = {x: s.x, y: baseline, sx: s.scale.x, sy: s.scale.y, ss: s.scrollSpeed};
			// ...and the arrows keep falling *straight* however far a lane
			// turns: the source's ConfusionModifier only writes the sprite
			// angle, so the lanes rotate in place and the notes still come
			// down vertically (see the header).
			s.noteAngle = 0;
		}
	}
	return true;
}

// walks the timeline in the order the source queued it, which is chronological
// per modifier: a `set` lands instantly, an `ease` captures its starting value
// on its first frame and interpolates until `end`
function _evaluate(cur) {
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

// BeatModifier's beat window.  `time`/`amount` are functions of curBeat only -
// the source's `beat = curBeat + accelTime` with Psych's integer `curBeat` puts
// the window at its top edge (0.3 of 0..0.7) on every single beat, so the ramp
// is flat and the pulse is `40 * amount` px of field-wide x, sign-flipped on
// every other beat's parity.  Copied over as-is rather than simplified: a
// fractional `curBeat` (which the fork does not have) would ramp again.
function _beatAmount() {
	var beat = curBeat + 0.3;
	if (beat < 0) return 0;
	var even = (beat % 2) != 0;
	var b = beat - Math.floor(beat);
	b += 1;
	b -= Math.floor(b);
	var amount = 0.0;
	if (b >= 0.7) amount = 0;
	else if (b < 0.3) {
		amount = _scale(b, 0, 0.3, 0, 1);
		amount *= amount;
	} else {
		var a2 = _scale(b, 0.3, 0.7, 1, 0);
		amount = 1 - (1 - a2) * (1 - a2);
	}
	if (even) amount *= -1;
	return amount;
}

function _hasDirtyNotes(fw) {
	for (lane in 0..._noteDirty[fw].length)
		if (_noteDirty[fw][lane]) return true;
	return false;
}

// `getVisibility`'s band term (`AlphaModifier.getVisibility`): the `sudden` /
// `hidden` pair fades a note by where it is on screen rather than by a flat
// value.  `_scale` of a y between the band's start and end, clamped to [-1, 0].
function _bandAdjust(yPos, start, end) {
	return _clamp(_scale(yPos, start, end, 0, -1), -1, 0);
}

function _apply() {
	var time = _timeSec();
	var beatAmt = _beatAmount();
	var h = FlxG.height;
	var swag = Note.swagWidth;

	for (fw in 0...2) {
		if (_base[fw] == null) continue;
		var line = strumLines.members[FW_LINE[fw]];
		if (line == null) continue;
		var nLanes = line.members.length;
		var other = _base[1 - fw];

		var swap = _vals[I_SWAP[fw]];
		var flip = _vals[I_FLIP[fw]];
		var txG = _vals[I_TX[fw]];
		var tyG = _vals[I_TY[fw]];
		var miniG = _vals[I_MINI[fw]];
		var confG = _vals[I_CONF[fw]];
		var alphaG = 1 - _vals[I_ALPHA[fw]];
		var stealth = _vals[I_STEALTH[fw]];
		var drunk = _vals[I_DRUNK[fw]];
		var tipsy = _vals[I_TIPSY[fw]];
		var beatV = _vals[I_BEAT[fw]];
		var sudden = _vals[I_SUDDEN[fw]];
		var hidden = _vals[I_HIDDEN[fw]];
		var revG = _vals[I_REV[fw]];
		var centered = _vals[I_CENTER[fw]];
		var splitV = _vals[I_SPLIT[fw]];
		var altV = _vals[I_ALT[fw]];
		var crossV = _vals[I_CROSS[fw]];

		// the visibility bands of `hidden` + `sudden`
		// (`AlphaModifier.getHiddenStart` etc., with both offsets at their 0)
		var hs = hidden * sudden;
		_pHiddenStart = (h / 2) + 120 * _scale(hs, 0, 1, 0, -0.25);
		_pHiddenEnd = (h / 2) + 120 * _scale(hs, 0, 1, -1, -1.25);
		_pSudStart = (h / 2) + 120 * _scale(hs, 0, 1, 0, 0.25);
		_pSudEnd = (h / 2) + 120 * _scale(hs, 0, 1, 1, 1.25);
		_pStealth = stealth;
		_pHidden = hidden;
		_pSudden = sudden;
		_pDrunk = drunk;
		_pBeat = beatV;
		_pBeatAmt = beatAmt;
		_pTime = time;
		_pScroll = line.data.scrollSpeed == null ? scrollSpeed : line.data.scrollSpeed;

		var anyNotes = false;
		for (lane in 0...nLanes) {
			_pA[lane] = 1.0;
			_pFX[lane] = 1.0;
			_pFY[lane] = 1.0;
			_pCos[lane] = 0.0;
		}

		for (lane in 0...nLanes) {
			var s = line.members[lane];
			var b = _base[fw][lane];
			if (b == null || s == null) continue;

			// ── x ────────────────────────────────────────────────────────────
			// opponentSwap: slide this lane onto the other field's same lane
			// (`pos.x += (their base x - our base x) * value`)
			var x = b.x;
			if (swap != 0 && other != null && other[lane] != null)
				x += (other[lane].x - b.x) * swap;
			// flip: `swagWidth * (lanes / 2) * (1.5 - lane) * value`
			if (flip != 0)
				x += swag * (nLanes / 2) * (1.5 - lane) * flip;
			// transform: the modifier's own value, then the lane's
			x += txG + _vals[I_TXi[fw][lane]];
			// drunk: the receptor's angle has no visual difference term
			if (drunk != 0) {
				_pCos[lane] = Math.cos(time + lane * 0.2);
				x += drunk * _pCos[lane] * swag * 0.5;
			}
			// beat: the receptor's visual difference is 0, so its own term is
			// `40 * amount` - the beat's jolt; the per-note half of the same
			// modifier lives in the note pass
			if (beatV != 0) x += beatV * 40 * beatAmt;
			if (s.x != x) s.x = x;

			// ── y ────────────────────────────────────────────────────────────
			var ny = tyG + _vals[I_TYi[fw][lane]];
			// tipsy: one sine per lane, no per-note term (the source's angle
			// carries no visual difference either - the whole lane breathes)
			if (tipsy != 0)
				ny += tipsy * (Math.cos(time * 1.2 + lane * 1.8) * swag * 0.4);

			// reverse: `pos.y = shift + visualDiff * mult`, where shift comes
			// out of the reverse value (and its `centered` blend) and mult is
			// that value's complement - a negative scrollSpeed gives CNE the
			// same mirrored fall.  The source's downscroll complement is not
			// applied here (see the header).
			var rev = revG + _vals[I_REVi[fw][lane]];
			if (lane >= nLanes / 2) rev += splitV;
			if (lane % 2 == 1) rev += altV;
			var first = nLanes / 4;
			if (lane >= first && lane <= nLanes - 1 - first) rev += crossV;
			rev = rev % 2;
			if (rev > 1) rev = 2 - rev;

			// AlphaModifier explicitly excludes reverse from its position query.
			_pVisibilityY[lane] = 50 + ny;
			// Source transforms are screen-space deltas; HudCamera mirrors its
			// logical y, so invert only the delta to preserve the visible motion.
			if (downscroll) ny = -ny;
			var want = b.y + ny;
			if (rev != 0 || centered != 0) {
				var shift = 50 + (h - 200) * rev;
				if (centered != 0) shift = shift + centered * (((h / 2) - 56) - shift);
				want = shift + ny;
			}
			if (s.y != want) s.y = want;

			if (rev != 0 || _dirtySS[fw][lane]) {
				s.scrollSpeed = rev == 0 ? b.ss : ((b.ss == null ? scrollSpeed : b.ss) * (1 - 2 * rev));
				_dirtySS[fw][lane] = rev != 0;
			}

			// ── angle ────────────────────────────────────────────────────────
			var conf = confG + _vals[I_CONFi[fw][lane]];
			if (conf != 0 || _dirtyAng[fw][lane]) {
				s.angle = conf;
				_dirtyAng[fw][lane] = conf != 0;
			}

			// ── scale ────────────────────────────────────────────────────────
			var fx = (1 - miniG) * (1 - _vals[I_MNXi[fw][lane]]);
			var fy = (1 - miniG) * (1 - _vals[I_MNYi[fw][lane]]);
			if (fx != 1 || fy != 1 || _dirtyScale[fw][lane]) {
				// Direct fields avoid depending on inline FlxPoint helpers in HScript.
				s.scale.x = b.sx * fx;
				s.scale.y = b.sy * fy;
				_dirtyScale[fw][lane] = (fx != 1 || fy != 1);
			}

			// ── alpha ────────────────────────────────────────────────────────
			// the receptor's half of `AlphaModifier.updateReceptor`; `stealth`
			// itself is *not* part of it (it only fades notes, through
			// getVisibility - see the note pass)
			var a = alphaG * (1 - _vals[I_ALPHAi[fw][lane]]);
			if (a != 1 || _dirtyAlpha[fw][lane]) {
				s.alpha = a;
				_dirtyAlpha[fw][lane] = a != 1;
			}

			_pA[lane] = a;
			_pFX[lane] = fx;
			_pFY[lane] = fy;
			if (a != 1 || fx != 1 || fy != 1 || drunk != 0 || beatV != 0
				|| stealth != 0 || sudden != 0 || hidden != 0) anyNotes = true;
		}

		if (anyNotes || _hasDirtyNotes(fw)) _notePass(fw, line, nLanes);
	}
}

// `NoteGroup.forEach` and not a walk over `notes.members`: the group is sized
// for the whole chart up front and sorted by strumTime, and `forEach` is the
// documented way to iterate only the notes that can still be on screen
// (StrumLine.notes) - it starts at the tail, the oldest notes, and stops at the
// first one further away than the group's limit.
function _notePass(fw, line, nLanes) {
	var now = Conductor.songPosition;
	var h = FlxG.height;
	var swag = Note.swagWidth;
	line.notes.forEach(function(n) {
		if (n == null || !n.exists) return;
		var dt = n.strumTime - now;
		if (dt < -2000 || dt > 5000) return;
		var lane = n.noteData % nLanes;
		var a = _pA[lane] == null ? 1 : _pA[lane];
		var fx = _pFX[lane] == null ? 1 : _pFX[lane];
		var fy = _pFY[lane] == null ? 1 : _pFY[lane];

		// the note's own scroll offset, in the same pixels the source's
		// `visualDiff` is in (both are `(strumTime - songPos) * 0.45 * speed`)
		var dx = 0.0;
		var visualDiff = dt * 0.45 * _pScroll;
		if (_pDrunk != 0 && _pCos[lane] != null)
			dx += _pDrunk * (Math.cos(_pTime + lane * 0.2 + visualDiff * 10 / h) - _pCos[lane]) * swag * 0.5;
		if (_pBeat != 0)
			dx += _pBeat * 40 * _pBeatAmt * (Math.sin(visualDiff / 30 + Math.PI / 2) - 1);

		// `getVisibility` + `getAlpha`: a note fades out once its sprite y is
		// past the middle of the screen, over the sudden/hidden band
		var vis = 1.0;
		if (_pStealth != 0 || _pSudden != 0 || _pHidden != 0) {
			var yPos = _pVisibilityY[lane] + visualDiff;
			vis = 1 - _pStealth;
			if (_pHidden != 0) vis += _pHidden * _bandAdjust(yPos, _pHiddenStart, _pHiddenEnd);
			if (_pSudden != 0) vis += _pSudden * _bandAdjust(yPos, _pSudStart, _pSudEnd);
			if (yPos < 0) vis = 1; // `stealthPastReceptors` off: above the screen is safe
			vis = _clamp(2 * _clamp(vis, 0, 1), 0, 1);
		}
		var total = a * vis;

		if (total == 1 && fx == 1 && fy == 1 && dx == 0) {
			_restoreNote(n);
			return;
		}
		if (!n.extra.exists('mmMA')) {
			n.extra.set('mmMA', n.alpha);
			n.extra.set('mmMSX', n.scale.x);
			n.extra.set('mmMSY', n.scale.y);
			n.extra.set('mmMRP', n.strumRelativePos);
		}
		n.alpha = n.extra.get('mmMA') * total;
		// a sustain's y scale is its own length, the source leaves it alone too
		if (n.isSustainNote) n.scale.x = n.extra.get('mmMSX') * fx;
		else {
			n.scale.x = n.extra.get('mmMSX') * fx;
			n.scale.y = n.extra.get('mmMSY') * fy;
		}
		// Absolute positioning is needed: relative Note.draw ignores note.x and
		// cancels offset.x. Rebuild from the current strum before adding the bend.
		if (dx != 0 || n.strumRelativePos != n.extra.get('mmMRP')) {
			n.strumRelativePos = dx == 0 ? n.extra.get('mmMRP') : false;
			line.members[lane].updateNotePosition(n);
			if (dx != 0) n.x += dx;
		}
		_noteDirty[fw][lane] = true;
	});
	// a lane that is clean now had all of its notes restored above, so its flag
	// can drop; a lane still under a mod keeps its flag up so the next frame
	// still runs this pass even when nothing else needs it
	for (i in 0..._noteDirty[fw].length) {
		var la = _pA[i] == null ? 1 : _pA[i];
		var lx = _pFX[i] == null ? 1 : _pFX[i];
		var ly = _pFY[i] == null ? 1 : _pFY[i];
		if (la == 1 && lx == 1 && ly == 1 && _pDrunk == 0 && _pBeat == 0
			&& _pStealth == 0 && _pSudden == 0 && _pHidden == 0) _noteDirty[fw][i] = false;
	}
}

function _restoreNote(n) {
	if (!n.extra.exists('mmMA')) return;
	n.alpha = n.extra.get('mmMA');
	if (n.isSustainNote) n.scale.x = n.extra.get('mmMSX');
	else {
		n.scale.x = n.extra.get('mmMSX');
		n.scale.y = n.extra.get('mmMSY');
	}
	var relative = n.extra.get('mmMRP');
	if (n.strumRelativePos != relative) {
		n.strumRelativePos = relative;
		var strum = n.strumLine.members[n.noteData % n.strumLine.members.length];
		if (strum != null) strum.updateNotePosition(n);
	}
	n.extra.remove('mmMA');
	n.extra.remove('mmMSX');
	n.extra.remove('mmMSY');
	n.extra.remove('mmMRP');
}
