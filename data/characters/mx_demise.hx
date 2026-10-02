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

	origin.set(833, 1003);
}

function update(elapsed:Float) {
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

	legs.x = x; legs.y = y;
	arm.x = x; arm.y = y;

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
