// 'Write DS' - displays the "Death Screen" message. Ported from Mario's Madness
// (source/PlayState.hx: value1 = time in beats, value2 = message; defaults to
// "sorry"). The original writes onto the No-Party canvas (`backing`/`canvas`/
// `writeText`); this port shows the message as centred text on the HUD.
//
// The source builds *two* texts up front and 'Write DS' picks one of them:
// `thetext` (grey) for every message, `thetextC` (red, "criminal") when value2
// is literally 'criminal'. `Triggers No Party` 6 then blinks between the two
// (`thetextC.visible = !thetextC.visible; thetext.visible = !thetextC.visible;`,
// 10558-10560 - the chart fires it twelve times half a second apart), which is
// why that toggle lives here rather than in data/stages/piracy.hx: the two
// sprites are this event's own.
import flixel.text.FlxTextBorderStyle;

var dsText:FunkinText;      // the normal message (source: thetext)
var dsTextC:FunkinText;     // the 'criminal' copy (source: thetextC)
var dsShown:Bool = false;   // a Write DS has put one of the two up
var dsCriminal:Bool = false;

function create() {
	var y:Float = FlxG.height - 220;

	dsText = new FunkinText(0, y, FlxG.width, "", 32);
	dsText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, "center", FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
	dsText.borderSize = 2;
	dsText.camera = camHUD;
	dsText.alpha = 0;
	add(dsText);

	// 4248-4254: the second text, in the fork's own red (0xFFE58F8F).
	dsTextC = new FunkinText(0, y, FlxG.width, "", 32);
	dsTextC.setFormat(Paths.font("vcr.ttf"), 32, 0xFFE58F8F, "center", FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
	dsTextC.borderSize = 2;
	dsTextC.camera = camHUD;
	dsTextC.alpha = 0;
	add(dsTextC);
}

// Puts one of the two texts up and takes the other one down.
function dsSelect(criminal:Bool, fade:Float) {
	dsCriminal = criminal;
	var on = criminal ? dsTextC : dsText;
	var off = criminal ? dsText : dsTextC;
	if (fade > 0) {
		FlxTween.tween(on, {alpha: 1}, fade, {ease: FlxEase.quadOut});
		FlxTween.tween(off, {alpha: 0}, fade, {ease: FlxEase.quadOut});
	} else {
		on.alpha = 1;
		off.alpha = 0;
	}
}

function onEvent(event) {
	if (event.event.name == "Write DS") {
		var text = Std.string(event.event.params[1]);
		if (text == "" || text == "null") text = "sorry";
		dsText.text = text;
		dsTextC.text = text;
		dsShown = true;
		// 14242-14250: 'criminal' is the message that uses the red copy.
		if (text == "criminal") dsSelect(true, 0.25);
		else dsSelect(false, 0.25);
		return;
	}

	// 'Triggers No Party' 6 (132.48s-138.24s): the DS message blinks. The chart
	// sends the group as 'Triggers Universal' (the source re-dispatches it), and
	// the blink only ever runs on the piracy stage - No Party is its only user.
	if (event.event.name != "Triggers No Party" && event.event.name != "Triggers Universal") return;
	if (curStage != "piracy") return;
	var trigger = Std.parseInt(event.event.params[0]);
	if ((trigger == null || Math.isNaN(trigger)) || trigger != 6) return;
	if (!dsShown) return;
	dsSelect(!dsCriminal, 0);
}
