// 'Add Subtitle' - shows subtitle text at the bottom of the screen. Ported from
// Mario's Madness (source/PlayState.hx: value1 = text, value2 = colour name or
// 0xFF...... hex).
//
// Creation, source 5255-5268: the text sits at y 560.8 in the vcr font at 30
// (mariones.ttf on the exeport stage), white with a thin 1.25px black outline,
// on its own scrollFactor(0,0) layer. All four of those used to differ here -
// the port drew it 40px lower, at 28px with a 2px border, in `Mario2.ttf`,
// which is not the name of any file in fonts/ (the deploy is `mario2.ttf`), so
// on a case-sensitive filesystem the whole subtitle row fell back to the
// engine's default font. The 112 subtitles of All-Stars Act 4 are the visible
// consequence.
//
// Not reproduced: `subTitle.visible = !ClientPrefs.hideHud` (ClientPrefs is not
// script-readable - same limitation as data/stages/virtual.hx).
//
// Camera: 5267 puts the row on `camOther`, the layer *above* camHUD (Psych's
// camera order is camGame 826, camEst 827, camHUD 828, camOther 829). It is on
// camHUD here for a reason that no longer holds - the earlier version of this
// script could not add a camera - and that choice is what hid All-Stars Act 4's
// 112 subtitles: its stage takes camHUD to `alpha = 0` for the last two acts
// (PlayState.hx 9837, 10271), which an overlay on camHUD inherits. Codename has
// only camGame and camHUD, so the row gets a camera of its own instead. Added
// without a default draw target, so the world is not redrawn on it, and appended
// last in `FlxG.cameras.list`, which is camOther's slot: above the HUD.
import flixel.text.FlxText.FlxTextBorderStyle;

var mmSubtitle:FunkinText;
var mmSubCam:FlxCamera = null;

function mmSubCamGet():FlxCamera {
	if (mmSubCam == null) {
		var w = (camHUD != null) ? camHUD.width : FlxG.width;
		var h = (camHUD != null) ? camHUD.height : FlxG.height;
		mmSubCam = new FlxCamera(0, 0, w, h);
		mmSubCam.bgColor = FlxColor.TRANSPARENT;
		mmSubCam.zoom = 1;		FlxG.cameras.add(mmSubCam, false); // defaultDraw=false -> world not redrawn
	}
	return mmSubCam;
}

// Keeps the layer at camHUD's size, the way the card does - camOther and camHUD
// are the same rectangle in the source.
function mmSubCamSize() {
	if (mmSubCam == null || camHUD == null) return;
	if (mmSubCam.width != camHUD.width) mmSubCam.width = camHUD.width;
	if (mmSubCam.height != camHUD.height) mmSubCam.height = camHUD.height;
}

function postUpdate(elapsed:Float) {
	mmSubCamSize();
}

function create() {
	mmSubtitle = new FunkinText(0, 560.8, FlxG.width, "", 30);
	// 5256-5263: exeport is the one stage whose subtitle uses the mod's own font.
	var font:String = (curStage == "exeport") ? "mariones.ttf" : "vcr.ttf";
	mmSubtitle.setFormat(Paths.font(font), 30, FlxColor.WHITE, "center", FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
	mmSubtitle.borderSize = 1.25;
	mmSubtitle.scrollFactor.set(0, 0);
	mmSubtitle.cameras = [mmSubCamGet()];
	add(mmSubtitle);
}

function onEvent(event) {
	if (event.event.name != "Add Subtitle") return;
	mmSubtitle.text = Std.string(event.event.params[0]);

	var colour = Std.string(event.event.params[1]);
	var newColour = null;
	if (StringTools.startsWith(colour, "0xFF") || StringTools.startsWith(colour, "0x")) {
		newColour = Std.parseInt(colour);
	} else {
		switch (colour) {
			case "Red": newColour = 0xFFFF1F1F;
			case "Blue": newColour = 0xFF1A4AE8;
			// The fork's own table maps 'Yellow' to red (14188-14189); kept as-is.
			case "Yellow": newColour = 0xFFFF1F1F;
			case "Green": newColour = 0xFF198C0E;
			case "Purple": newColour = 0xFF8B1AE8;
			case "Lime": newColour = 0xFF2BE81A;
		}
	}
	// 14196-14203: an empty value means white. The source assigns whatever the
	// table produced, so an unknown *non-empty* name leaves it parsing "" and
	// ends up white here instead of throwing.
	mmSubtitle.color = (newColour != null) ? newColour : FlxColor.WHITE;
}
