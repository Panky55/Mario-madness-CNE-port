// 'Char Attack' - the character performs its stage attack. Ported from
// Mario's Madness (source/PlayState.hx: exeport -> MX salto,
// turmoilsweep -> Turmoil Attack, castlestar -> Power Attack). The individual
// attacks live in the corresponding song/stage scripts and are reached through
// the shared `onTrigger` hook, which those stages register with CnE's own
// cross-script channel: `PlayState.instance.scripts.set("onTrigger", ...)` here
// read back with `scripts.get`. (It used to be a
// `Reflect.setProperty(PlayState.instance, "onTrigger", ...)` field, which on
// cpp logs `Invalid field:onTrigger` and throws - PlayState has no such field -
// so the hook was never registered and this event did nothing.)
function onEvent(event) {
	if (event.event.name != "Char Attack") return;

	var attack = null;
	switch (curStage) {
		case "exeport": attack = "MX salto";
		case "turmoilsweep": attack = "Turmoil Attack";
		case "castlestar": attack = "Power Attack";
	}
	if (attack == null) return;

	var hook:Dynamic = (PlayState.instance != null && PlayState.instance.scripts != null)
		? PlayState.instance.scripts.get("onTrigger") : null;
	if (hook == null) {
		trace("[MM Char Attack] no 'onTrigger' hook registered for this stage - '" + attack + "' dropped");
		return;
	}
	Reflect.callMethod(null, hook, [attack, "", ""]);
}
