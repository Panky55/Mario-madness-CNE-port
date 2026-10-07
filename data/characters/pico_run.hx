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
	// Psych only calls the lua's `goodNoteHit` for the *player's* own presses;
	// this engine's `onNoteHit` reaches every character script for both sides'
	// notes, so the gate has to be explicit.
	if (!event.player) return;
	var anim:String = mmArmAnim(event.direction, (event.animSuffix == null) ? "" : event.animSuffix);
	if (anim != null) arm.animation.play(anim, true);
}

// The arm's pose for a note, by its own direction. The source reads it off the
// body (`boyfriend.animation.curAnim.name`), which works there because Psych
// runs the lua's `goodNoteHit` *after* it played the sing pose - here
// `onNoteHit` is dispatched above that loop (`PlayState.goodNoteHit`:
// `gameAndCharsEvent` comes before its `playSingAnim` calls), so `getAnimName()`
// still names the *previous* animation, `idle` between notes. That played
// nothing at all (the arm registers three poses) and logged a Flixel warning on
// every note: `No animation called "idle"`. The direction is the same anim the
// body is about to play. `singDOWN` has no back pose (`mmArmOffset`'s three are
// it, and the source hides the arm for it), so that lookup simply fails.
function mmArmAnim(dir:Int, suffix:String):String {
	var base:String = switch (dir) {
		case 0: "singLEFT";
		case 1: "singDOWN";
		case 2: "singUP";
		case 3: "singRIGHT";
		default: null;
	}
	if (base == null) return null;
	if (suffix != "" && arm.animation.exists(base + suffix)) return base + suffix;
	return arm.animation.exists(base) ? base : null;
}

// ---------------------------------------------------------------------------
// child space vs this engine's node space
// ---------------------------------------------------------------------------
// The source's rig writes are *child-space*: Psych bakes a character's own
// `position` into its x/y when it is added to the group (`startCharacterPos`,
// PlayState.hx: `char.y += char.positionArray[1]`), so `boyfriend.y =
// defaultBoyfriendY + 500` is the sprite's absolute y and the leg/arm sprites -
// which live outside the group - are parked straight on `boyfriend.x` /
// `boyfriend.y`.
//
// This engine keeps that position in `Character.globalOffset` and applies it at
// *draw* instead: `Character.playAnim` ends in
//     offset.set(globalOffset.x * (isPlayer != playerOffsets ? 1 : -1),
//                -globalOffset.y)
// so the sprite renders at `x - k * globalOffset.x` / `y + globalOffset.y`,
// k = (isPlayer != playerOffsets) ? 1 : -1.  A script writing the character's y
// (as this rig does) writes the *node*: what the source's `boyfriend.y` holds is
// `y + globalOffset.y`, and putting a child-space value there rendered the body
// `globalOffset.y` px away from the legs it sits on top of - pico_run's own
// `y`="230", i.e. the torso sat 230px lower than the source puts it, right on
// the running legs.
//
// So: `boyfriend.y` is `y + globalOffset.y` here - `childY` in update, and the
// pair the two plain sprites are parked on (`mmChildX` / `childY`) - while the
// body itself is written back through `mmNodeY`.
function mmSideK():Float {
	return (isPlayer != playerOffsets) ? 1 : -1;
}

function mmChildX():Float {
	return x - mmSideK() * globalOffset.x;
}

function mmNodeY(childY:Float):Float {
	return childY - globalOffset.y;
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
	// The y the source is writing to `boyfriend.y` (`y + globalOffset.y` here) -
	// its running branch is `defaultBoyfriendY + 500` plus the leg-frame bob, a
	// *child-space* y, and the idle branch the same without the bob.
	var childY:Float = baseY + 500;

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
			case 0:  childY = baseY + 500;        angle = -0.4;
			case 2:  childY = baseY + 500 - 3.75; angle = 0.8;
			case 4:  childY = baseY + 500 + 2.4;  angle = 1.8;
			case 6:  childY = baseY + 500 + 6;    angle = 0.3;
			case 8:  childY = baseY + 500 + 1.1;  angle = -0.7;
			case 10: childY = baseY + 500 - 6.4;  angle = 1.2;
			case 12: childY = baseY + 500 - 4.4;  angle = 2.2;
			case 14: childY = baseY + 500 + 2.15; angle = 1.5;
		}
	} else {
		// `boyfriend.animation.frameIndex = picolegs.animation.frameIndex + 89`:
		// the idle torso sheet's frames start 89 into the shared atlas, so this
		// keeps the top lined up with the running legs (skipped for `dialog1`).
		if (anim != "dialog1" && animation != null)
			animation.frameIndex = f + 89;
		arm.visible = false;
		angle = 0;
	}

	y = mmNodeY(childY);
	var cx:Float = mmChildX();
	legs.x = cx; legs.y = childY;
	arm.x = cx; arm.y = childY;
	arm.angle = angle;
}
