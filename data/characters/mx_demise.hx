// MX Demise running-rig, ported from Mario's Madness
// assets/preload/data/characters/mx_demise.lua.
// A pair of separate leg/arm sprites are drawn behind the body and the body is
// bobbed/rotated to match the leg animation frames.
//
// The source's `onUpdatePost` is run from `update`: this engine only dispatches
// `postUpdate` to PlayState/state scripts, never to a *character* script
// (v1.0.1 `Character.update` calls `scripts.call("update")` alone).
var legs:FunkinSprite;
var arm:FunkinSprite;
var baseX:Float = 0;
var baseY:Float = 0;
var baseCaptured:Bool = false;
var isON = true;

function postCreate() {
	mmBuildRig();
}

// postCreate is not dispatched to a *character* script on this engine version
// (only `update` is), so a rig built only there never spawns - no legs, no arm,
// and the opening run-in plays with neither. The build therefore runs lazily
// from `update` too; the guard keeps it to one build either way.
function mmBuildRig() {
	if (legs != null) return;
	// The pair the previous instance of this side left behind goes first (see
	// the note below).
	mmDropPrevRig();
	baseX = x;
	baseY = y;

	legs = new FunkinSprite(0, 0);
	legs.frames = Paths.getSparrowAtlas("characters/MX_Demise_Assets");
	legs.animation.addByPrefix("exist", "MX Running Legs", 35, true);
	legs.animation.play("exist");
	legs.offset.set(-3, -461);
	legs.scale.set(scale.x, scale.y);

	arm = new FunkinSprite(0, 0);
	arm.frames = Paths.getSparrowAtlas("characters/MX_Demise_Assets");
	arm.animation.addByPrefix("exist2", "MX Running Right Arm", 35, true);
	arm.animation.play("exist2");
	arm.offset.set(57, -321);
	arm.scale.set(scale.x, scale.y);

	var i = PlayState.instance.members.indexOf(this);
	PlayState.instance.insert(i, arm);
	PlayState.instance.insert(i, legs);
	// Publish the pair, so the next instance of this side can drop it.
	mmRegisterRig();

	origin.set(833, 1003);
}

// ---------------------------------------------------------------------------
// The rig the previous instance of this side left behind
// ---------------------------------------------------------------------------
// This engine keeps a script per *character instance* and a swap builds a fresh
// one, so every `Change Character` that puts this character back builds a fresh
// pair of leg/arm sprites - while the pair its predecessor made stays in the
// draw list with its animation still running and nothing left to hide it: the
// swap only `remove`s the outgoing character (data/events/Change Character.hx
// and the stages' own mmChangeChar both do), and the one place this engine
// dispatches a script's `destroy` hook is `Character.destroy` (v1.0.1
// Character.hx:324-326), which a swap never reaches. The fork has neither
// problem - its lua is loaded once per character *type* for the whole song and
// the rig lives in it, so its own `onEvent` only flips `isON` on the one pair
// (mx_demise.lua:128-145, and its `onUpdatePost` head hides the pair whenever
// `dad.alpha == 0`, which is what the cutscene sets).
// Demise swaps the surface pair to the underground one and back (cases 1/2), so
// by the second half the leftovers were visible twice over: the dead instances'
// legs kept running in place through the cutscene (where the live pairs *are*
// hidden, but a dead instance's pair is checked by nobody), and once the
// surface character came back its pair doubled up with the fresh one - the
// reported "duplicated legs" when hitting notes.
// The pair is published per *side* in `PlayState.instance.scripts` - the pack
// this port already shares through (songs/MMcamera.hx's mmDodge API) - and each
// build drops whatever its own side is about to replace, so at most one rig per
// side exists and it always belongs to the live character. Only this stage's
// four rigs do this: pico_run.lua has no such toggle (its rig is meant to
// survive a swap and keep following the boyfriend), so its own pair is left
// alone.
function mmRigSlot():String {
	return isPlayer ? "mmRigPlayer" : "mmRigOpponent";
}

function mmRigPack() {
	var st = PlayState.instance;
	if (st == null) return null;
	return st.scripts;
}

function mmDropPrevRig() {
	var pack = mmRigPack();
	if (pack == null) return;
	var prev = pack.get(mmRigSlot());
	if (prev == null) return;
	var st = PlayState.instance;
	var pl = prev.legs;
	var pa = prev.arm;
	if (pl != null) { st.remove(pl, true); pl.destroy(); }
	if (pa != null) { st.remove(pa, true); pa.destroy(); }
	pack.set(mmRigSlot(), null);
}

function mmRegisterRig() {
	var pack = mmRigPack();
	if (pack == null) return;
	pack.set(mmRigSlot(), {legs: legs, arm: arm});
}

// ---------------------------------------------------------------------------
// child space vs this engine's node space
// ---------------------------------------------------------------------------
// The source's leg/arm sprites are parked on `whoismx.x` / `whoismx.y`, i.e. the
// character's *child-space* pair - Psych bakes its own `position` into that x/y
// when it joins the group (`startCharacterPos`), while this engine keeps the
// position in `Character.globalOffset` and applies it at draw (`Character.
// playAnim` leaves `offset` = `globalOffset` mirrored by
// `isPlayer != playerOffsets`), so the pair here is `x - k * globalOffset.x` /
// `y + globalOffset.y`. mx_demise's own position is (-930, -870), so parking the
// legs on the raw node put them 930px aside (pico_run.hx/bf_demise.hx carry the
// derivation).
// The body's own writes need no conversion: the lua spells them
// `defaultOpponentX - 930` / `defaultOpponentY - 870`, and -930/-870 is exactly
// that position, so they are the *group*'s pair - which is what `x`'s and `y`'s
// node value already is.
// The constructor-time build runs before the character joins the draw list,
// so its `members.indexOf(this)` is -1 - and flixel's insert at -1 writes the
// pair outside the drawn members, permanently invisible (the null guard above
// would then keep them there forever). So the first placed frame pulls the
// pair out of wherever that build left them and seats them next to the body.
function mmSeatRig() {
	var st = PlayState.instance;
	if (st == null || legs == null || arm == null) return;
	var bi:Int = st.members.indexOf(this);
	if (bi < 0) return;
	if (bi >= 2 && st.members[bi - 2] == legs && st.members[bi - 1] == arm) return;
	st.remove(legs, true);
	st.remove(arm, true);
	var at:Int = st.members.indexOf(this);
	if (at < 0) return;
	st.insert(at, arm);
	st.insert(at, legs);
}

function mmSideK():Float {
	return (isPlayer != playerOffsets) ? 1 : -1;
}

function mmChildX():Float {
	return x - mmSideK() * globalOffset.x;
}

function update(elapsed:Float) {
	if (legs == null || arm == null) mmBuildRig();
	mmSeatRig();
	if (legs == null || arm == null) return;

	var show = isON && alpha != 0;
	arm.visible = show;
	legs.visible = show;
	if (!show) return;

	// A swap-in is built at (0,0), so the source's anchor comes from the placed
	// sprite on the first frame the rig runs.
	if (!baseCaptured) {
		baseCaptured = true;
		baseX = x;
		baseY = y;
	}

	// The child-space pair the legs and arm take from the body - this frame's
	// body write still to come, so it is the previous frame's pair, as in the lua.
	var cx:Float = mmChildX();
	var cy:Float = y + globalOffset.y;
	legs.x = cx; legs.y = cy;
	arm.x = cx; arm.y = cy;

	var anim = getAnimName();
	var f = legs.animation.frameIndex;

	if (anim != null && anim != "idle") {
		arm.visible = false;
		switch (f) {
			case 0 | 8:
				angle = 0; x = baseX; y = baseY;
			case 2 | 10:
				angle = -2.7; x = baseX - 13.4; y = baseY - 72.75;
			case 4 | 12:
				angle = -3.7; x = baseX - 18.05; y = baseY - 94.8;
			case 6 | 14:
				angle = -2.2; x = baseX - 10.8; y = baseY - 26.5;
		}
	} else {
		angle = 0;
		x = baseX;
		y = baseY;
		arm.visible = true;
		// The lua's torso sync: the body's frozen `idle` (`MX Running Upper
		// Body`, fps 0) is driven by hand off the legs' own frame. Both are
		// global atlas frames, so the legs' 0..15 plus 32 is the torso's 32..47
		// - without this the torso sits on its first frame while the legs run.
		var lf:Dynamic = (legs.animation != null) ? legs.animation.frameIndex : null;
		if (lf != null) animation.frameIndex = lf + 32;
	}
}

function onEvent(event) {
	if (event.event.name != "Change Character") return;
	if (Std.string(event.event.params[0]) != "1") return;

	var to = Std.string(event.event.params[1]);
	isON = (to == "mx_demise");
	arm.visible = isON;
	legs.visible = isON;
}
