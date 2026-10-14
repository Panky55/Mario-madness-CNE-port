// BF Demise (Underground) running-rig, ported from Mario's Madness
// assets/preload/data/characters/bf_demiseUG.lua.
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
// and the underground run-in plays with neither. The build therefore runs
// lazily from `update` too; the guard keeps it to one build either way.
function mmBuildRig() {
	if (legs != null) return;
	// The pair the previous instance of this side left behind goes first (see
	// the note below).
	mmDropPrevRig();
	baseX = x;
	baseY = y;

	legs = new FunkinSprite(0, 0);
	legs.frames = Paths.getSparrowAtlas("characters/Demise_BF_Assets_Underground");
	legs.animation.addByPrefix("exist", "Bottom", 40, true);
	legs.animation.play("exist");
	legs.offset.set(33, -236);
	legs.scale.set(scale.x, scale.y);

	arm = new FunkinSprite(0, 0);
	arm.frames = Paths.getSparrowAtlas("characters/Demise_BF_Assets_Underground");
	arm.animation.addByPrefix("exist2", "BF Right Arm", 40, true);
	arm.animation.play("exist2");
	arm.offset.set(-13, -155);
	arm.scale.set(scale.x, scale.y);

	var i = PlayState.instance.members.indexOf(this);
	PlayState.instance.insert(i, arm);
	PlayState.instance.insert(i, legs);
	// Publish the pair, so the next instance of this side can drop it.
	mmRegisterRig();
}

// ---------------------------------------------------------------------------
// The rig the previous instance of this side left behind
// ---------------------------------------------------------------------------
// This engine keeps a script per *character instance* and a swap builds a fresh
// one, so the `Change Character` that puts the underground pair on builds a
// fresh pair of leg/arm sprites - while the pair the surface instance made stays
// in the draw list with its animation still running and nothing left to hide it:
// the swap only `remove`s the outgoing character (data/events/Change
// Character.hx and the stages' own mmChangeChar both do), and the one place this
// engine dispatches a script's `destroy` hook is `Character.destroy` (v1.0.1
// Character.hx:324-326), which a swap never reaches. The fork has neither
// problem - its lua is loaded once per character *type* for the whole song, so
// bf_demise.lua's pair and this one both exist from the start and a swap only
// flips `isON` on each (bf_demiseUG.lua:139-152), i.e. exactly one pair per side
// is ever visible.
// Demise swaps this pair to the underground and back (cases 1/2), so the dead
// instances' legs kept running in place through the cutscene (where the live
// pairs *are* hidden, but a dead instance's pair is checked by nobody) and then
// doubled up with the fresh surface pair - the reported "duplicated legs" when
// hitting notes.
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
// The source's rig writes are *child-space* - Psych bakes the character's own
// `position` into its x/y when it joins the group (`startCharacterPos`), so
// `whoisbf.y = defaultBoyfriendY + 270` is the sprite's absolute y, and the
// leg/arm sprites are parked straight on `whoisbf.x` / `whoisbf.y`. This engine
// keeps that position in `Character.globalOffset` and applies it at draw
// (`Character.playAnim` leaves `offset` = `globalOffset` mirrored by
// `isPlayer != playerOffsets`), so the sprite renders at `x - k * globalOffset.x`
// / `y + globalOffset.y`: the legs and arm have to be parked on that pair and
// the body's writes written back through it. pico_run.hx carries the full
// derivation (bf_demiseUG's own `y`="250" is the size of the error).
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

function mmNodeY(childY:Float):Float {
	return childY - globalOffset.y;
}

function update(elapsed:Float) {
	if (legs == null || arm == null) mmBuildRig();
	mmSeatRig();
	if (legs == null || arm == null) return;

	var show = isON && alpha != 0;
	arm.visible = show;
	legs.visible = show;
	if (!show) return;

	if (!baseCaptured) {
		baseCaptured = true;
		baseX = x;
		baseY = y;
	}

	legs.color = color;
	arm.color = color;
	// The pair the source copies onto the legs and arm (child space).
	var cx:Float = mmChildX();
	var cy:Float = y + globalOffset.y;
	legs.x = cx; legs.y = cy;
	arm.x = cx; arm.y = cy;

	var anim = getAnimName();
	var f = legs.animation.frameIndex;

	if (anim != null && anim != "idle") {
		arm.visible = false;
		switch (f) {
			case 31: y = mmNodeY(baseY + 270);
			case 33: y = mmNodeY(baseY + 270 + 3.675);
			case 35: y = mmNodeY(baseY + 270 + 7.35);
			case 37: y = mmNodeY(baseY + 270 + 1.125);
			case 39: y = mmNodeY(baseY + 270 + 2.525);
			case 41: y = mmNodeY(baseY + 270 + 4.6);
			case 43: y = mmNodeY(baseY + 270 + 6.3);
			case 45: y = mmNodeY(baseY + 270 + 1.575);
		}
	} else {
		angle = 0;
		y = mmNodeY(baseY + 230);
		arm.visible = true;
		// The lua's torso sync (bf_demiseUG.lua:100): the body's frozen `idle`
		// is driven by hand off the legs' own global frame, minus 16.
		var lf:Dynamic = (legs.animation != null) ? legs.animation.frameIndex : null;
		if (lf != null) animation.frameIndex = lf - 16;
	}
}

function onEvent(event) {
	if (event.event.name != "Change Character") return;
	if (Std.string(event.event.params[0]) != "0") return;

	var to = Std.string(event.event.params[1]);
	isON = (to == "bf_demiseUG");
	arm.visible = isON;
	legs.visible = isON;
}
