// 'Cambiar Zoom Default' - tweens the default camera zoom. Ported from Mario's
// Madness (source/PlayState.hx:9406-9411: tweens FlxG.camera.zoom over 0.5s).
//
// 9408-9409 is the interesting half: an unparsable value does not *skip* the
// event, it tweens back to `defaultCamZoom`:
//
//     if (Math.isNaN(camaraActual)) camaraActual = defaultCamZoom;
//
// Nine charts use this event and one of them passes an empty value, so the
// no-op the port used to return left the camera wherever the last event had
// put it. `defaultCamZoom` is a PlayState field (the same one allfinal.hx
// writes through Reflect), so it can be read from here.
function onEvent(event) {
	if (event.event.name != "Cambiar Zoom Default") return;
	var zoom = Std.parseFloat(event.event.params[0]);
	if (zoom == null || Math.isNaN(zoom)) {
		var ps = PlayState.instance;
		var def = (ps != null) ? Reflect.field(ps, "defaultCamZoom") : null;
		if (def == null) return;
		zoom = Std.parseFloat(Std.string(def));
		if (zoom == null || Math.isNaN(zoom)) return;
	}
	FlxTween.tween(camGame, {zoom: zoom}, 0.5, {ease: FlxEase.quadInOut});
}
