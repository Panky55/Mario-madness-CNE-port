// 'setProperty' - a generic property setter used by the source's scripted
// events. value1 = "object.property.path" (relative to PlayState),
// value2 = the value to set.
//
// A handful of the fields the charts write are the *source's* own PlayState
// fields and have no Codename counterpart. `cameraTilt` - promoshow's beat tilt,
// written at 82.27s / 94.28s / 95.78s / 140.85-142.27s / 143.77s / 167.77s /
// 179.77s - is the one this mod uses, and that stage's script reads the event
// itself. Those have to be skipped here: `Reflect.setProperty` on a field the
// target does not define logs "Invalid field:<name>" and throws out of the
// handler, and a CnE script cannot wrap that in a try/catch (see the note in
// allfinal.hx).
var SETPROP_SOURCE_ONLY = ["cameraTilt"];

function onEvent(event) {
	if (event.event.name != "setProperty") return;

	var path = Std.string(event.event.params[0]).split(".");
	if (path.length < 1) return;

	var obj:Dynamic = PlayState.instance;
	for (i in 0...path.length - 1)
		obj = Reflect.field(obj, path[i]);

	if (obj == null) return;

	var field = path[path.length - 1];
	// Only the bare PlayState path is filtered - these charts never write
	// `cameraTilt` on anything else.
	if (obj == PlayState.instance && SETPROP_SOURCE_ONLY.indexOf(field) >= 0) return;
	Reflect.setProperty(obj, field, event.event.params[1]);
}
