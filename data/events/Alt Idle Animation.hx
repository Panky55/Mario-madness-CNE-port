// 'Alt Idle Animation' - changes the idle suffix of a character. Ported from
// Mario's Madness (source/PlayState.hx:9265-9288).
//
//   9266-9284  value1 picks the character: 'gf'/'girlfriend', 'boyfriend'/'bf',
//              or a number - 1 is boyfriend, 2 is girlfriend, anything else dad.
//              The name forms are matched on the lower-cased value and the
//              numeric ones on the parsed one, so both orders are live.
//   9285-9286  value2 becomes the character's `idleSuffix` and is handed to
//              `recalculateDanceIdle()`.
//
// The fork then keeps two *PlayState* fields in step (9285/9287-9288):
// `altAnims = value2` and `altdad = char == dad && curStage != 'virtual'` (and
// `altdad = false` when value2 is empty). They exist for the fork's own dad
// dance handler (`else if (altdad) altAnim = altAnims;`, 8400-8401), which
// picks the suffix for dad at the moment it dances; neither field exists in
// Codename (`altdad`/`altAnims` are not in the engine at all), and Codename's
// Character reads its own suffix, so the write below is the whole of the
// behaviour this port can carry. The 16 chart uses are all name forms or 'dad'
// with a suffix, none numeric.
function onEvent(event) {
	if (event.event.name != "Alt Idle Animation") return;

	var who = StringTools.trim(Std.string(event.event.params[0]).toLowerCase());
	var target = null;
	switch (who) {
		case "gf" | "girlfriend": target = gf;
		case "boyfriend" | "bf": target = boyfriend;
		default:
			var num = Std.parseInt(who);
			if (num == 1) target = boyfriend;
			else if (num == 2) target = gf;
			else target = dad;
	}
	if (target == null) return;

	var suffix = (event.event.params.length > 1) ? Std.string(event.event.params[1]) : "";
	Reflect.setProperty(target, "idleSuffix", suffix);
	// `recalculateDanceIdle` is not in the engine (see the header); the guard
	// keeps the call working if a future build adds it.
	if (Reflect.hasField(target, "recalculateDanceIdle"))
		Reflect.callMethod(target, Reflect.field(target, "recalculateDanceIdle"), []);
}
