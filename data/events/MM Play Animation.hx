// Ported from PlayState.hx:9226 (case 'Play Animation').
//
// The source uses Psych's param order [animation, character] and can target
// dad / boyfriend / girlfriend (by name or by number). Codename's own built-in
// 'Play Animation' instead takes [strumline index, animation, forced] and can
// only target strumlines (never GF), so the chart conversion routes these events
// through this custom event rather than the built-in. The numeric target forms
// ('1' boyfriend, '2' girlfriend) are here because the source accepts them
// (9238-9244) - even though the 191 chart uses are all name forms.
//
// The source's last line, `char.specialAnim = true` (9245-9246), makes the
// character *hold* the animation instead of dropping back to its idle dance.
// Codename has no `specialAnim`, but it models the same thing through a
// playAnim *context*: this call uses the default one, and the engine only dances
// through `Character.tryDance()`, which holds a non-`DANCE` animation until it
// finishes (`tryDance`'s `default:` branch - `Character.update` and `beatHit`
// both call it, never `dance()`). So the hold works out the same here. The one
// thing that *does* cut such an animation short is a script calling `dance()`
// directly, which bypasses that check - `tryDance()` is the call to use (see
// `stage_triggers/luigiout.hx`'s `stepHit` for a case where it mattered).
function onEvent(event) {
	if (event.event.name != "MM Play Animation") return;

	var anim = (event.event.params.length > 0) ? Std.string(event.event.params[0]) : "";
	if (anim == "" || anim == "null") return;

	var who = (event.event.params.length > 1) ? StringTools.trim(Std.string(event.event.params[1]).toLowerCase()) : "dad";

	var target = switch (who) {
		case "bf" | "boyfriend": boyfriend;
		case "gf" | "girlfriend": gf;
		case "1": boyfriend;
		case "2": gf;
		default: dad;
	};
	if (target == null) return;

	target.playAnim(anim, true);
}
