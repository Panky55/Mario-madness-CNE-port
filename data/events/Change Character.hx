// 'Change Character' - swaps one of the characters for another. Ported from
// Mario's Madness (source/PlayState.hx: value1 = 0 boyfriend / 1 opponent /
// 2 girlfriend, value2 = character name).
//
// The source reads value1 in two places and both are reproduced here: the name
// form (`eventPushed`, 6808-6819 - 'gf'/'girlfriend' -> 2, 'dad'/'opponent' ->
// 1) and the number form (`case 'Change Character'`, 9311-9313, where
// `Std.parseInt` of anything that is not a number is NaN and NaN counts as 0,
// i.e. the boyfriend). The charts use both: '1' 28 times, '0' 8, '2' once, and
// 'BF' - the number form's non-numeric way of saying 0 - three times, all of
// them on Overdue.
//
// (`Std.parseInt('BF')` is null, and on cpp `Math.isNaN(null)` is *false*, so
// the source's own `if (Math.isNaN(charType)) charType = 0;` guard has to be
// written as a null check here. Without it 'BF' stayed null and fell through to
// the `default` branch - the opponent - so Overdue's 21.47s/42.95s/170.64s
// 'BF' -> 'picodiag' events swapped *Luigi* onto Pico's dialogue sprite
// instead of Pico onto it.)
// The source moves the health icon with the character: `case 0` ends with
// `iconP1.changeIcon(boyfriend.healthIcon)` (9331) and `case 1` with
// `iconP2.changeIcon(dad.healthIcon)` (9376); `case 2` (gf) touches no icon.
// This engine build has no `changeIcon` on HealthIcon (its symbols are in
// `strings CodenameEngine`), it has `setIcon`, and the name it wants is
// `Character.getIcon()` - the XML's `icon` attribute, falling back to the
// character's own name, which is what PlayState seeds `new
// HealthIcon(boyfriend.getIcon(), ...)` with. Both lookups are Reflect-guarded:
// an engine without them leaves the icon alone instead of dropping the swap.
//
// The swap-in also has to keep the *group's* position, the way the source's
// does: 'Change Character' never repositions anything (6081-6122 builds each
// dadMap/boyfriendMap/gfMap entry as `new Character(0, 0, name)` +
// `startCharacterPos()` while already inside the group, so it sits at
// `group + its own position`), and the source's group keeps moving all its
// children afterwards. applyCharStuff parks the swap-in at the bare stage node,
// which is only the group's position while the group still sits at its default
// - Dark Forest's case 1 moves the dad 3750px down to the treehouse
// (`dadGroup.y += -3750`, 13412) *before* the chart's own 92.8s-94.6s scream
// swaps, and those swaps then dropped Peach back to the empty first-part stage
// (she only came back in act 3, where case 2 resets the node). The recovery is
// the one data/stages/allfinal.hx documents: Character.playAnim ends in
//     offset.set((isPlayer != playerOffsets) ? globalOffset.x : -globalOffset.x,
//                -globalOffset.y);
// so the sprite renders at `stored.x - k * globalOffset.x` / `stored.y +
// globalOffset.y` with k = (isPlayer != playerOffsets) ? 1 : -1, while the
// source renders it at `group + position`, i.e.
//     stored.x = groupX + (k + 1) * globalOffset.x
//     stored.y = groupY                     (y carries no k)
function mmSwapIcon(index:Int, c) {
	var ic = (index == 0) ? iconP1 : ((index == 1) ? iconP2 : null);
	if (ic == null || c == null) return;
	// `Reflect.hasField` answers *false* for every member of a class instance on
	// the cpp build - the guard was written against --interp's answer, so in the
	// shipped game no swap ever moved the icon (iconP2 kept `luigi-fake`'s
	// 'fake-mrl' past Overdue's 24.00s swap to `luigi-toolate`). `Reflect.field`
	// resolves the member on both targets; see PORT_NOTES.md.
	if (Reflect.field(ic, "setIcon") == null || Reflect.field(c, "getIcon") == null) return;
	var n = c.getIcon();
	if (n != null && n != "") ic.setIcon(n);
}

function onEvent(event) {
	if (event.event.name != "Change Character") return;

	var raw:String = StringTools.trim(Std.string(event.event.params[0]));
	var index = Std.parseInt(raw); // null for 'BF', which the source's NaN guard means as 0
	if (index == null) index = 0;
	var low:String = (raw == null) ? "" : raw.toLowerCase();
	if (low == "gf" || low == "girlfriend") index = 2;
	else if (low == "dad" || low == "opponent") index = 1;
	else if (low == "bf" || low == "boyfriend") index = 0;

	var name = Std.string(event.event.params[1]);
	if (name == null || name == "" || name == "null") return;
	if (!Assets.exists(Paths.xml("characters/" + name))) return;

	// In the generated charts the opponent strumline is first, the player
	// strumline is second, and the girlfriend (if any) is third.
	var member = null;
	switch (index) {
		case 0: member = (strumLines.members.length > 1) ? strumLines.members[1] : null;
		case 2: member = (strumLines.members.length > 2) ? strumLines.members[2] : null;
		default: member = strumLines.members[0];
	}
	if (member == null || member.characters.length < 1) return;

	var old = member.characters[0];
	if (old.curCharacter == name) return;

	var isPlayer = old.isPlayer;
	// The group's current position, recovered from the character being replaced
	// (its own k/offset), and the slot the swap-in should keep.
	var oldK:Float = (old.isPlayer != old.playerOffsets) ? 1 : -1;
	var groupX:Float = old.x - (oldK + 1) * old.globalOffset.x;
	var groupY:Float = old.y;
	var oldIndex:Int = members.indexOf(old);

	remove(old);
	member.characters.remove(old);

	var fresh = new Character(0, 0, name, isPlayer);
	stage.applyCharStuff(fresh, member.data.position, 0);
	// ... written back through the fresh character's own k/offset, which may
	// differ from the old one's (see the note at the top).
	var newK:Float = (fresh.isPlayer != fresh.playerOffsets) ? 1 : -1;
	fresh.x = groupX + (newK + 1) * fresh.globalOffset.x;
	fresh.y = groupY;
	// Dark Forest's variants live inside the same tinted dadGroup in the
	// source (5859/13376), including the hidden scream variants. Rebuilding
	// them here otherwise resets Peach to white on every chart swap at
	// 92.8s-94.6s. Keep the live stage tint; forest.hx's own swap does likewise.
	// Other stages retain their existing incoming-character appearance.
	if (curStage == "forest") fresh.color = old.color;
	// The source's group keeps its z-position across a swap, so the swap-in goes
	// back to the outgoing character's draw slot instead of the node's.
	if (oldIndex >= 0) {
		remove(fresh);
		insert(oldIndex, fresh);
	}
	// The source's death character is a global (GameOverSubstate.characterName) and
	// survives a swap; this port keeps it on the character (see songs/MMcamera.hx's
	// game-over table), so the current one has to ride across.
	fresh.gameOverCharacter = old.gameOverCharacter;
	member.characters.insert(0, fresh);
	mmSwapIcon(index, fresh);
}
