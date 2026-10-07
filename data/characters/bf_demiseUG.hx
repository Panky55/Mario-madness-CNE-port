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
