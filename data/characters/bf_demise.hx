// BF Demise running-rig, ported from Mario's Madness
// assets/preload/data/characters/bf_demise.lua.
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
	baseX = x;
	baseY = y;

	legs = new FunkinSprite(0, 0);
	legs.frames = Paths.getSparrowAtlas("characters/Demise_BF_Assets");
	legs.animation.addByPrefix("exist", "Bottom", 40, true);
	legs.animation.play("exist");
	legs.offset.set(33, -230);
	legs.scale.set(scale.x, scale.y);

	arm = new FunkinSprite(0, 0);
	arm.frames = Paths.getSparrowAtlas("characters/Demise_BF_Assets");
	arm.animation.addByPrefix("exist2", "BF Right Arm", 40, true);
	arm.animation.play("exist2");
	arm.offset.set(-13, -155);
	arm.scale.set(scale.x, scale.y);

	var i = PlayState.instance.members.indexOf(this);
	PlayState.instance.insert(i, arm);
	PlayState.instance.insert(i, legs);
}

// ---------------------------------------------------------------------------
// child space vs this engine's node space
// ---------------------------------------------------------------------------
// The source's rig writes are *child-space*: Psych bakes a character's own
// `position` into its x/y when it is added to the group (`startCharacterPos`),
// so `whoisbf.y = defaultBoyfriendY + 270` is the sprite's absolute y and the
// leg/arm sprites - which live outside the group - are parked straight on
// `whoisbf.x` / `whoisbf.y` (bf_demise.lua's `setProperty('bflegs.x',
// getProperty(whoisbf .. '.x'))`).
//
// This engine keeps that position in `Character.globalOffset` and applies it at
// *draw*: `Character.playAnim` ends in
//     offset.set(globalOffset.x * (isPlayer != playerOffsets ? 1 : -1),
//                -globalOffset.y)
// so the sprite renders at `x - k * globalOffset.x` / `y + globalOffset.y`,
// k = (isPlayer != playerOffsets) ? 1 : -1 - what the source calls
// `whoisbf.y` is `y + globalOffset.y` here, and a script writing the character's
// y (this rig does) writes the *node*. Putting the source's child-space value
// there moved the body `globalOffset.y` px away from the legs it sits on
// (bf_demise's own `y`="230").
//
// So the two plain sprites are parked on the child pair and the body's writes go
// through mmNodeY. pico_run.hx carries the full derivation; allfinal.hx's
// mmPlaceWorld / promoshow.hx's helpers are the same rule.
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
	if (legs == null || arm == null) return;

	var show = isON && alpha != 0;
	arm.visible = show;
	legs.visible = show;
	if (!show) return;

	// A swap-in is built at (0,0), so the source's `defaultBoyfriendY` anchor
	// comes from the placed sprite on the first frame the rig runs.
	if (!baseCaptured) {
		baseCaptured = true;
		baseX = x;
		baseY = y;
	}

	// The pair the source is copying onto the legs and arm - the character's own
	// child-space x/y (`mmChildX()` / `y + globalOffset.y`) - this frame's write
	// to the body still to come, so it is the previous frame's pair exactly as in
	// the lua.
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
	}
}

function onEvent(event) {
	if (event.event.name != "Change Character") return;
	if (Std.string(event.event.params[0]) != "0") return;

	var to = Std.string(event.event.params[1]);
	isON = (to != "bf_demiseUG");
	arm.visible = isON;
	legs.visible = isON;
}
