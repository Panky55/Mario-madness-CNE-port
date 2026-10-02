// Pico running-rig, ported from Mario's Madness
// assets/preload/data/characters/pico_run.lua.
// The rig is only created once the song triggers the "fuckoff" event; after
// that the body is bobbed/rotated to match the leg animation frames and the
// torso's own frame is driven off the legs'.
//
// The per-frame half of the source lives in `onUpdatePost`, which this engine
// never dispatches to a *character* script - only to PlayState/state scripts
// (v1.0.1 `Character.update` calls `scripts.call("update")` and nothing else).
// The rig therefore runs from `update`, which the engine *does* call on the
// character every frame, after the character's own update.
var legs:FunkinSprite;
var arm:FunkinSprite;
var baseX:Float = 0;
var baseY:Float = 0;
var baseCaptured:Bool = false;
var active = false;

function postCreate() {
	baseX = x;
	baseY = y;
}

function onEvent(event) {
	if (event.event.name != "fuckoff" || active) return;
	active = true;

	arm = new FunkinSprite(0, 0);
	arm.frames = Paths.getSparrowAtlas("characters/Too_Late_Pico_FINALSEQUENCE_assets");
	arm.animation.addByPrefix("singLEFT", "TopLeftBack", 24, false);
	arm.animation.addByPrefix("singUP", "TopUpBack", 24, false);
	arm.animation.addByPrefix("singRIGHT", "TopRightBack", 24, false);
	arm.visible = false;
	arm.origin.set(170, 160);

	legs = new FunkinSprite(0, 0);
	legs.frames = Paths.getSparrowAtlas("characters/Too_Late_Pico_FINALSEQUENCE_assets");
	legs.animation.addByPrefix("exist", "Legs", 32, true);
	legs.animation.play("exist");
	legs.offset.set(35, -275);

	var i = PlayState.instance.members.indexOf(this);
	PlayState.instance.insert(i, arm);
	PlayState.instance.insert(i, legs);

	origin.set(235, 315);
}

function onNoteHit(event) {
	if (!active || arm == null) return;
	var anim = getAnimName();
	if (anim != "singDOWN" && anim != null)
		arm.animation.play(anim, true);
}

// The source's per-anim arm offsets (`onUpdatePost` reads picoarm's own anim).
function mmArmOffset(name:String) {
	if (arm == null) return;
	if (name == "singUP") arm.offset.set(-273, -180);
	else if (name == "singRIGHT") arm.offset.set(-50, -200);
	else if (name == "singLEFT") arm.offset.set(-222, -207);
}

function update(elapsed:Float) {
	if (!active || legs == null || arm == null) return;

	// The source anchors the body to `defaultBoyfriendY` (the stage's BF_Y).  A
	// character script only sees its own sprite, and the constructor's postCreate
	// runs at the bare 0,0 the swap creates - but the stage places this character
	// at its BF_Y right after firing 'fuckoff', so the first frame the rig runs is
	// the one that carries that anchor.
	if (!baseCaptured) {
		baseCaptured = true;
		baseY = y;
	}

	var anim = getAnimName();
	var f = legs.animation.frameIndex;

	if (anim != null && anim != "idle" && anim != "dialog1") {
		arm.visible = (anim != "singDOWN");
		if (arm.visible) {
			var a = arm.animation.curAnim;
			mmArmOffset((a != null) ? a.name : null);
		}
		// Body bob / rotation per leg frame.  The source only writes on even leg
		// frames, so odd frames keep the previous value - the switch mirrors that
		// (no default case).
		switch (f) {
			case 0:  y = baseY + 500;        angle = -0.4;
			case 2:  y = baseY + 500 - 3.75; angle = 0.8;
			case 4:  y = baseY + 500 + 2.4;  angle = 1.8;
			case 6:  y = baseY + 500 + 6;    angle = 0.3;
			case 8:  y = baseY + 500 + 1.1;  angle = -0.7;
			case 10: y = baseY + 500 - 6.4;  angle = 1.2;
			case 12: y = baseY + 500 - 4.4;  angle = 2.2;
			case 14: y = baseY + 500 + 2.15; angle = 1.5;
		}
	} else {
		// `boyfriend.animation.frameIndex = picolegs.animation.frameIndex + 89`:
		// the idle torso sheet's frames start 89 into the shared atlas, so this
		// keeps the top lined up with the running legs (skipped for `dialog1`).
		if (anim != "dialog1" && animation != null)
			animation.frameIndex = f + 89;
		arm.visible = false;
		angle = 0;
		y = baseY + 500;
	}

	legs.x = x; legs.y = y;
	arm.x = x; arm.y = y;
	arm.angle = angle;
}
