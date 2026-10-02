// 'Show Song' - the song's title card, ported from Mario's Madness.
//
// Source: PlayState.hx 5314-5418 (the per-song author switch, the 'Old' songs'
// '(Legacy)' rename, the window title), 5450-5484 (the card: title text, author
// text and the two underline bars) and 14211-14296 (the event handler itself:
// value1 = 0 show / 1 hide). Until now this port only drew the song name, so
// every title card showed a blank author line and no bars.
//
// All-Stars is the one song whose card changes while the song plays: its chart
// shows this card once per act (3.2s, 107.2s, 240.0s and 361.9s, 'Show Song'
// 0/1 twice each) and the fork swaps the two texts at every act change from
// its 'Triggers All-Stars' handler (9831-9832 act 2 'Sandi ft. Kenny L',
// 9979-9980 act 3 'Scrumbo_ ft. FriedFrick', 10083-10084 act 4 'FriedFrick'
// and a second line ' ft. theWAHbox and RedTV53'). onEvent keeps those texts
// in step and
// mmCardShow re-lays the card out on each show, which the multi-show needs: the
// source resets `titleText.y` to 304.5 every time, so a bare `y: t.y + 30`
// tween would otherwise walk the card 30px further down per act.
//
// Details of the source's card that are deliberately not reproduced:
//   * the warp zone's question-mark window title (5433-5445) - this port has no
//     warp zone mode, so `isWarp` is never true;
//   * the per-stage HUD hiding that follows the card on somari/endstage/
//     warioworld (5486-5510), which belongs to those stages' own port;
//   * Unbeatable's move of the whole card onto `camOther` (14261-14271, above
//     every HUD layer) - the layer below is the camEst half of the source's
//     camera work; lifting the card above camHUD for that one song is not
//     reproduced.
//
// Camera: the source does not draw this card on camHUD. `titleText`/`autorText`
// are moved to Psych's `camEst` at 5625-5626 and the two bars are built on it
// (5476/5481); Psych's cameras are camGame (826), camEst (827), camHUD (828)
// and camOther (829), so the card sits *between* the world and the HUD. That is
// not cosmetic: a stage that hides or fades camHUD takes everything drawn on it
// along, and All-Stars does both (`camHUD.visible = false` at load, 4019 - back
// on at 9781 - and `camHUD.alpha = 0` at 9837). On camHUD the act 1 card (3.2s)
// and the act 4 card (361.9s) never appeared at all - only acts 2 and 3 did.
// Codename has only camGame and camHUD, so this script adds a camera of its own
// - camHUD's rectangle, zoom 1, `defaultDraw = false` - and slides it into
// camHUD's slot in `FlxG.cameras.list`, which is camEst's position: the same
// thing data/stages/exeport.hx and promoshow.hx do for their camEst layers.
//
// The per-stage *card* is delegated as well: on somari the source plays its own
// `titleNES` NES strip, on endstage it shows its own `linefount` sprite and on
// piracy it slides `djStart` in, each instead of the title/author text - so this
// script stands down on all three and data/stages/somari.hx /
// data/stages/endstage.hx / data/stages/piracy.hx show them (see onEvent).
//
// The source's author table keys off SONG.song ('Its a me'); this port keys off
// the display name, normalised by mmKey() so 'Its A Me', 'All Stars' and
// 'Mario Sing And Game Rythm 9' match 'Its a me', 'All-Stars' and
// 'MARIO SING AND GAME RYTHM 9'.
import flixel.text.FlxTextBorderStyle;

var mmTitle:FunkinText = null;
var mmAuthor:FunkinText = null;
var mmLine1:FlxSprite = null;
var mmLine2:FlxSprite = null;
// The two texts the card currently shows, kept apart from the sprites because
// All-Stars swaps them mid-song (see mmCardShow / onEvent).
var mmLiveName:String = "";
var mmTitleText:String = "";
var mmAuthorText:String = "";

// --------------------------------------------------------------------------
// The card's own layer (source: Psych's `camEst`)
// --------------------------------------------------------------------------
var mmCardCam:FlxCamera = null;
var mmCardCamPlaced:Bool = false;
var mmCardCamWarned:Bool = false;

// `Reflect.field` rather than `FlxG.cameras.list` directly, the way
// exeport.hx/promoshow.hx read it: a lookup that comes back empty has to leave
// the camera where it is rather than take the script down with it.
function mmCamList() {
	return Reflect.field(FlxG.cameras, "list");
}

function mmCardW():Float {
	return (camHUD != null) ? camHUD.width : FlxG.width;
}

function mmCardH():Float {
	return (camHUD != null) ? camHUD.height : FlxG.height;
}

function mmCardCamGet():FlxCamera {
	if (mmCardCam == null) {
		mmCardCam = new FlxCamera(0, 0, mmCardW(), mmCardH());
		mmCardCam.bgColor = FlxColor.TRANSPARENT;
		mmCardCam.zoom = 1;
		FlxG.cameras.add(mmCardCam, false); // defaultDraw=false -> world not redrawn
		mmCardBelowHud();
	}
	return mmCardCam;
}

// The camera is added normally (which puts it *above* camHUD) and then moved in
// front of camHUD in the list, i.e. into camEst's slot. Called again from
// postUpdate so a camera that was not in the list yet still lands there.
function mmCardBelowHud() {
	if (mmCardCam == null || mmCardCamPlaced) return;
	var list = mmCamList();
	if (list == null) {
		if (!mmCardCamWarned) {
			mmCardCamWarned = true;
			trace("[MM Show Song] card camera: no FlxG.cameras.list - the card stays above camHUD");
		}
		return;
	}
	list.remove(mmCardCam); // no-op when it is not in the list yet
	var at:Int = (camHUD != null) ? list.indexOf(camHUD) : -1;
	if (at < 0) {
		list.push(mmCardCam); // no camHUD yet: stay on top and try again next frame
		return;
	}
	list.insert(at, mmCardCam);
	mmCardCamPlaced = true;
}

// The source's camEst is the HUD's own rectangle, so if the engine ever resizes
// camHUD the layer follows it instead of keeping a stale viewport.
function mmCardSize() {
	if (mmCardCam == null) return;
	var w = mmCardW();
	var h = mmCardH();
	if (mmCardCam.width != w) mmCardCam.width = w;
	if (mmCardCam.height != h) mmCardCam.height = h;
}

function postUpdate(elapsed:Float) {
	mmCardBelowHud();
	mmCardSize();
}

// Lower case, letters and digits only: 'All-Stars' -> 'allstars',
// 'Mario Sing And Game Rythm 9' -> 'mariosingandgamerythm9'.
function mmKey(s:String):String {
	if (s == null) return "";
	var allowed = "abcdefghijklmnopqrstuvwxyz0123456789";
	var out = "";
	for (i in 0...s.length) {
		var c = s.substr(i, 1).toLowerCase();
		if (allowed.indexOf(c) >= 0) out = out + c;
	}
	return out;
}

// Source 5406-5428: an old song loses its ' Old' and gains ' (Legacy)', except
// Demise Old, which the fork renames to 'Time Out (Demise Original)'. All-Stars
// is shown as 'All-Stars (Act 1)' (the source's own title for it, and the name
// its window title uses).
function mmCardName(display:String):String {
	if (display == null) return "";
	if (StringTools.endsWith(display, "Old")) {
		if (display == "Demise Old") return "Time Out (Demise Original)";
		return StringTools.replace(display, " Old", "") + " (Legacy)";
	}
	if (mmKey(display) == "allstars") return "All-Stars (Act 1)";
	return display;
}

// Source 5314-5415, song by song.
function mmCardAuthor(key:String):String {
	switch (key) {
		// story songs
		case "itsame": return "TheWAHbox\n ft. Sandi and Comodo_";
		case "starmanslaughter": return "Sandi ft. RedTV53\n FriedFrick and theWAHbox";
		case "goldenland": return "FriedFrick";
		case "allstars": return "Kenny L";
		// warp zone songs
		case "ohgodno": return "Kenny L";
		case "ihateyou": return "Kenny L";
		case "powerdown": return "Kenny L ft. TaeSkull";
		case "demise": return "Kenny L";
		case "alone": return "RedTV53";
		case "apparition": return "FriedFrick";
		// extra songs
		case "racetraitors": return "Kenny L";
		case "darkforest": return "Kenny L";
		case "badday": return "RedTV53";
		case "socool": return "FriedFrick ft. TheWAHBox";
		case "nourishingblood": return "Kenny L";
		case "unbeatable": return "RedTV53\n ft. theWAHbox and scrumbo_";
		case "paranoia": return "Sandi ft. Kenny L";
		case "dayout": return "TheWAHBox";
		case "thalassophobia": return "Hazy ft. TaeSkull";
		case "promotion": return "Sandi";
		case "dictator": return "Kenny L";
		case "lastcourse": return "FriedFrick ft. Sandi";
		case "nohope": return "FriedFrick";
		case "theend": return "Kenny L";
		case "mariosingandgamerythm9": return "TaeSkull";
		case "overdue": return "FriedFrick ft. Sandi";
		case "abandoned": return "TheWAHBox ft. FriedFrick";
		case "noparty": return "Kenny L";
		// old songs
		case "forbiddenstar": return "KINGF0X";
		case "itsameold": return "KINGF0X";
		case "goldenlandold": return "Kenny L";
		case "ihateyouold": return "Kenny L";
		case "apparitionold": return "Kenny L";
		case "aloneold": return "KINGF0X";
		case "powerdownold": return "Kenny L";
		case "racetraitorsold": return "Kenny L";
		case "overdueold": return "Hazy";
		case "nopartyold": return "Joey Perleoni ft. RedTV53";
		case "allstarsold": return "Kenny L";
		case "demiseold": return "Kenny L";
		case "dictatorold": return "Kenny L";
	}
	return "";
}

// Source 4809-4833: the card's red, grey on the NES stage (landstage uses the
// grey 'GBhealthBarNEW' bar) and green on the source's botplay.
function mmCardColor():Int {
	if (curStage == "landstage") return 0xFFADADAD;
	return 0xFFF42626;
}

// The width the two bars under the title have to cover: the wider of the two
// texts (5458-5466), with the text field's own measurements as a fallback for
// the frame in which the sprite has not laid its text out yet.
function mmCardWidth():Float {
	var a:Float = (mmTitle != null) ? mmTitle.width : 0;
	var b:Float = (mmAuthor != null) ? mmAuthor.width : 0;
	if (a < 20 && mmTitle != null) a = mmTitle.textField.textWidth + 8;
	if (b < 20 && mmAuthor != null) b = mmAuthor.textField.textWidth + 8;
	return (a > b) ? a : b;
}

// The bars are built on the first show rather than at load: their length is the
// title's measured width, which is only reliable once the text has been
// rendered (the source builds them at creation and gets away with a stale
// width; a 0-length bar would simply never appear here).
function mmGetLines() {
	var colour:Int = mmCardColor();
	if (mmLine2 == null) {
		mmLine2 = new FlxSprite(0, mmTitle.y + 57);
		mmLine2.makeGraphic(Std.int(mmCardWidth()), 5, FlxColor.BLACK);
		mmLine2.screenCenter(FlxAxes.X);
		mmLine2.cameras = [mmCardCamGet()];
		mmLine2.alpha = 0;
		add(mmLine2);
	}
	if (mmLine1 == null) {
		mmLine1 = new FlxSprite(mmLine2.x - 5, mmLine2.y - 2);
		mmLine1.makeGraphic(Std.int(mmCardWidth()) + 10, 8, colour);
		mmLine1.cameras = [mmCardCamGet()];
		mmLine1.alpha = 0;
		add(mmLine1);
	}
}

function create() {
	var display:String = "";
	if (PlayState.SONG != null && PlayState.SONG.meta != null) display = PlayState.SONG.meta.displayName;
	var name:String = mmCardName(display);
	var author:String = mmCardAuthor(mmKey(display));
	var colour:Int = mmCardColor();
	mmLiveName = display;
	mmTitleText = name;
	mmAuthorText = author;

	// 5450-5473: FlxText with a 0 field width (so its own width is the text) and
	// the mod's own font, black text in a red outline.
	mmTitle = new FunkinText(0, 304, 0, name, 42);
	mmTitle.setFormat(Paths.font("mariones.ttf"), 42, FlxColor.BLACK, "center", FlxTextBorderStyle.OUTLINE, colour);
	mmTitle.borderSize = 3;
	mmTitle.screenCenter(FlxAxes.X);
	mmTitle.cameras = [mmCardCamGet()];
	mmTitle.alpha = 0;
	add(mmTitle);

	mmAuthor = new FunkinText(0, mmTitle.y + 70, 0, author, 35);
	mmAuthor.setFormat(Paths.font("mariones.ttf"), 35, FlxColor.BLACK, "center", FlxTextBorderStyle.OUTLINE, colour);
	mmAuthor.borderSize = 2;
	mmAuthor.screenCenter(FlxAxes.X);
	mmAuthor.cameras = [mmCardCamGet()];
	mmAuthor.alpha = 0;
	add(mmAuthor);

	// 5421/5426: the fork renames the window to the song and its author. The
	// card's own name is used, so an old song reads '(Legacy)' in the title bar
	// as well.
	if (name != "") window.title = "Friday Night Funkin': Mario's Madness | " + name + " | " + author;
}

// 14236-14254: one show of the card. The source re-lays it out every time -
// `titleText.y = 304.5`, both texts re-centred, the two bars put back on that
// row - and then slides all four 30px down. That reset is not cosmetic here:
// All-Stars shows this card *four* times (3.2s, 107.2s, 240.0s, 361.9s), and a
// plain `y: t.y + 30` would have walked the card 30px further down per act.
function mmCardShow() {
	mmTitle.text = mmTitleText;
	mmAuthor.text = mmAuthorText;
	mmTitle.visible = true;
	mmAuthor.visible = true;
	mmTitle.y = 304.5;
	mmAuthor.y = mmTitle.y + 70;
	mmGetLines();
	if (mmLine2 != null) {
		mmLine2.y = mmTitle.y + 57;
		mmLine2.visible = true;
	}
	if (mmLine1 != null) {
		mmLine1.y = mmLine2.y - 2;
		mmLine1.visible = true;
	}
	// The bars keep the width they were built with, as in the source (they are
	// created once, from the first text's width, and never re-measured).
	mmTitle.screenCenter(FlxAxes.X);
	mmAuthor.screenCenter(FlxAxes.X);

	for (t in [mmTitle, mmAuthor])
		FlxTween.tween(t, {alpha: 1, y: t.y + 30}, 0.5, {ease: FlxEase.cubeOut});
	for (t in [mmLine1, mmLine2])
		if (t != null) FlxTween.tween(t, {alpha: 1, y: t.y + 30}, 0.5, {ease: FlxEase.cubeOut});

	// 14250-14253: All-Stars also repoints the window title at the act it is
	// showing (its name and its author are the two texts on the card).
	if (mmKey(mmLiveName) == "allstars" && window != null)
		window.title = "Friday Night Funkin': Mario's Madness | " + mmTitleText + " | " + mmAuthorText;
}

function onEvent(event) {
	// All-Stars swaps the card's two texts at every act change, from the same
	// 'Triggers All-Stars' case the stage script mirrors - trigger 2/3/4 with
	// value2 0 (PlayState.hx 9831-9832 act 2, 9979-9980 act 3, 10083-10084 act
	// 4). The chart re-shows the card afterwards with its own 'Show Song' 0, so
	// writing the text here is enough. Gated on the *song*: All-Stars Old shares
	// the `allfinal` stage.
	if (mmKey(mmLiveName) == "allstars" && (event.event.name == "Triggers Universal" || event.event.name == "Triggers All-Stars")) {
		var act = Std.parseInt(event.event.params[0]);
		var sub = (event.event.params.length > 1) ? Std.parseInt(StringTools.trim(Std.string(event.event.params[1]))) : 0;
		if (act == null || Math.isNaN(act)) act = 0;
		if (sub == null || Math.isNaN(sub)) sub = 0;
		if (sub == 0) {
			if (act == 2) {
				mmTitleText = "All-Stars (Act 2)";
				mmAuthorText = "Sandi ft. Kenny L";
			} else if (act == 3) {
				mmTitleText = "All-Stars (Act 3)";
				mmAuthorText = "Scrumbo_ ft. FriedFrick";
			} else if (act == 4) {
				mmTitleText = "All-Stars (Act 4)";
				mmAuthorText = "FriedFrick\n ft. theWAHbox and RedTV53";
			}
		}
	}

	if (event.event.name != "Show Song") return;

	// 14211-14228: the card is per-stage - somari plays `titleNES` (a 4-frame NES
	// strip that animates in on 0 and back out on 1), endstage shows its own
	// `linefount` ('mario/costume/endtext') and piracy slides `djStart` in, each
	// *instead of* the regular title/author text. Those sprites belong to their
	// stages, so the stage script handles them and the card stands down there:
	// data/stages/somari.hx builds `titleNES`, data/stages/endstage.hx builds
	// `linefount`, data/stages/piracy.hx slides `djStart` in.
	if (curStage == "somari" || curStage == "endstage" || curStage == "piracy") return;

	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;

	if (trigger == 0) {
		mmCardShow();
	} else {
		// 14284-14296: fade out, then hide (the source hides them 0.5s later;
		// alpha 0 is already invisible, so nothing else is needed here).
		for (t in [mmTitle, mmAuthor, mmLine1, mmLine2])
			if (t != null) FlxTween.tween(t, {alpha: 0}, 0.5, {ease: FlxEase.cubeOut});
	}
}
