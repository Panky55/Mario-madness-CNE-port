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
	legs.x = x; legs.y = y;
	arm.x = x; arm.y = y;

	var anim = getAnimName();
	var f = legs.animation.frameIndex;

	if (anim != null && anim != "idle") {
		arm.visible = false;
		switch (f) {
			case 31: y = baseY + 270;
			case 33: y = baseY + 270 + 3.675;
			case 35: y = baseY + 270 + 7.35;
			case 37: y = baseY + 270 + 1.125;
			case 39: y = baseY + 270 + 2.525;
			case 41: y = baseY + 270 + 4.6;
			case 43: y = baseY + 270 + 6.3;
			case 45: y = baseY + 270 + 1.575;
		}
	} else {
		angle = 0;
		y = baseY + 230;
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
