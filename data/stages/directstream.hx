import flixel.text.FlxText.FlxTextBorderStyle;

// === MM stage triggers (auto) ===
// 'Triggers So Cool' - ported from PlayState.hx:10358-10377, plus the parts of
// `case 'directstream'` the trigger block needs (2145-2234, 4311-4320,
// 7765-7768, 7893-7897).
//
// The stage runs with `noCount = true; noHUD = true` (2146-2147), so the
// engine's READY/SET/GO are dropped (onCountdown cancelled) and camHUD starts at
// alpha 0 - the chart's own 'Ocultar HUD' 2 brings it back at 16s, which is also
// where the song's first notes are.
//
// Its opening mirrors the hatebg one: `blackBarThingie` - a full-screen black on
// camEst - is created *up*, and startCountdown's own branch (7893-7897) fades it
// out over 4s after a one-second delay, so So Cool opens on black and the stream
// fades in. In the port the curtain is a screen-space sprite appended to the
// draw list, which is camEst's slot here (above the world and the fighters,
// below camHUD - see execlassic.hx for the full note; the HUD is hidden anyway).
//
// The case itself (the chart sends it as 'Triggers Universal' 0-3):
//   0 (7.99s)  - miyamoto starts talking ('talk', offset.y = 2)
//   1 (11.50s) - ...and gestures ('hand')
//   2 (12.00s) - the red backdrop fades out, dad walks on (x -> 580) and
//                miyamoto leaves (x -> -2250), all over 1s quadInOut
//   3 (15.99s) - the name tag fades in while sliding to x = 200 (1s quadOut)
//
// The stream's live chat is ported too (see the section at the bottom): the
// rolling 16-line buffer and the message/username tables of
// source/DirectChat.hx, fed by the chart-independent beat branch
// (`if (FlxG.random.bool(50) && curBeat > 32) triggerEventNote('chat message')`,
// 16396-16399, handled by `case 'chat message'` at 10745). NOT ported:
// `ytUI`/`ytbutton`, which the source creates with alpha 0 and never shows.

var mmBlackBar = null; // the opening black / the stream's curtain (camEst)
var mmCamBG = null;    // the facecam frame ('camBG' in the stage XML)
var mmFaceAnim:String = "";

// A screen-space sprite, appended to the draw list (see the header).
function mmScreen(spr) {
	spr.scrollFactor.set(0, 0);
	add(spr);
	return spr;
}

// The source's `remove(x); add(x)` on one of its own state sprites means "move
// to the very front of the draw list". A stage sprite already lives in this
// state's draw list (`Stage.addSprite`), so it is that same remove + re-add -
// but neither call does what it says on its own: `FlxGroup.remove(basic,
// splice = false)` only nulls the slot (`members[index] = null`) and
// `FlxGroup.add` re-fills the *first* null slot (`getFirstNull()` =
// `members.indexOf(null)`), which is that very slot, so the pair is a no-op and
// the sprite never leaves the world layer. Splice it out and append it past the
// end of the list instead.
function mmToFront(obj) {
	remove(obj, true);
	insert(members.length, obj);
}

function mmGetBlackBar() {
	if (mmBlackBar == null) {
		mmBlackBar = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		mmBlackBar.scale.set(10, 10); // source's setGraphicSize(width * 10)
		mmBlackBar.alpha = 1;         // the stage opens behind it
		mmScreen(mmBlackBar);
	}
	return mmBlackBar;
}

// `noCount = true` (2147): the source never builds its 3-2-1-GO sprites for this
// stage, so the engine's are dropped here (PlayState.hx builds them in the
// cancellable `onCountdown`; same thing hatebg.hx/wetworld.hx do).
function onCountdown(event) {
	event.cancelled = true;
}

// `hasDownScroll` (2210). PlayState.downscroll is a get/set property, so read it
// defensively - the same idiom allfinal.hx/exesequel.hx/hatebg.hx use.
function mmDownScroll():Bool {
	if (PlayState.instance == null || !Reflect.hasField(PlayState.instance, "downscroll")) return false;
	return Reflect.field(PlayState.instance, "downscroll") == true;
}

function postCreate() {
	// 4311-4320: the late add switch puts the play button, the facecam border and
	// the name tag *after* the character groups, i.e. in front of the fighters.
	// Every sprite in a Codename stage XML sits below them, so the two that are
	// ever visible are lifted out of the world layer to the front. (The source's
	// `ytbutton` stays at alpha 0 for the whole song, and its `elfin`
	// - 'mario/Real/chris' - is created and never `add()`ed at all, so neither is
	// built here.)
	if (bordervid != null) mmToFront(bordervid);
	if (nametag != null) mmToFront(nametag);

	// `noHUD = true` (2146). The curtain covers it anyway; this only matters for
	// the frame between the fade finishing and the chart's own 'Ocultar HUD' 2.
	if (camHUD != null) camHUD.alpha = 0;

	// The chat is built first so the opening curtain covers it, as the source's
	// add order does (livechat at 2177, blackBarThingie later).
	mmChatBuild();

	// 7893-7897: the opening fade (see the header). The curtain is created *up*,
	// so this is also what keeps the stage from starting on the world - it has to
	// exist (and be drawn) from the first frame, not when the timer fires.
	mmGetBlackBar();
	new FlxTimer().start(1, function(tmr) {
		FlxTween.tween(mmGetBlackBar(), {alpha: 0}, 4, {ease: FlxEase.quadInOut});
	});

	mmCamBG = camBG;

	// 2207-2213 (`case 'directstream'`): with downscroll on, the source parks the
	// fighters and the facecam frame lower to leave room for the flipped
	// strumline - `boyfriendGroup.y = -255`, `gfGroup.y = -176`, `camBG.y = 50`
	// (the fourth write, `livechat.y = 320`, has no port). The stage XML holds the
	// upscroll arrangement, so these are the downscroll overrides.
	if (mmDownScroll()) {
		if (boyfriend != null) boyfriend.y = -255;
		if (gf != null) gf.y = -176;
		if (camBG != null) camBG.y = 50;
	}

	// 2217: the facecam frame carries its own caption art, so it is mirrored
	// upside down for *upscroll* (`flipY = !hasDownScroll`).
	if (bordervid != null) bordervid.flipY = !mmDownScroll();
}

// 7765-7768 / 15555-15575: the frame around the facecam mirrors the fighter on
// the *player* side (chris pratt is the opponent here) - 'down' while he is
// idle, and the note's own direction while he sings. The source drives it from
// the note hit (`case 0: camBG.animation.play('left')`, ...) and resets it to
// 'down' from update() when BF is idle; reading BF's current animation reaches
// the same frame in one place and needs no note data (this port's stage scripts
// see `event.noteType` but not the note's direction).
function postUpdate(elapsed:Float) {
	if (mmCamBG == null || boyfriend == null) return;
	var a = boyfriend.animation.curAnim;
	if (a == null || a.name == null) return;
	var n:String = a.name;
	var want:String = "down";
	if (n == "singUP" || n == "singUP-alt") want = "up";
	else if (n == "singLEFT" || n == "singLEFT-alt") want = "left";
	else if (n == "singRIGHT" || n == "singRIGHT-alt") want = "right";
	if (want == mmFaceAnim) return;
	mmFaceAnim = want;
	mmCamBG.animation.play(want);
}

// ---------------------------------------------------------------------------
// 'Triggers So Cool' 0-3
// ---------------------------------------------------------------------------
// Sent as 'Triggers Universal' by the chart (the source re-dispatches that to
// 'Triggers <song>' at runtime, 9489-9496), so both names are accepted.
function onEvent(event) {
	if (event.event.name != "Triggers So Cool" && event.event.name != "Triggers Universal") return;

	var trigger = Std.parseInt(event.event.params[0]);
	if (trigger == null || Math.isNaN(trigger)) trigger = 0;

	switch (trigger) {
		case 0:
			if (miyamoto != null) {
				miyamoto.animation.play("talk");
				miyamoto.offset.set(0, 2); // source's `offset.y = 2`
			}

		case 1:
			if (miyamoto != null) miyamoto.animation.play("hand");

		case 2:
			if (bgred != null) FlxTween.tween(bgred, {alpha: 0}, 1, {ease: FlxEase.quadInOut});
			if (dad != null) FlxTween.tween(dad, {x: 580}, 1, {ease: FlxEase.quadInOut});
			if (miyamoto != null) FlxTween.tween(miyamoto, {x: -2250}, 1, {ease: FlxEase.quadInOut});

		case 3:
			if (nametag != null) FlxTween.tween(nametag, {alpha: 1, x: 200}, 1, {ease: FlxEase.quadOut});
	}
}
// ---------------------------------------------------------------------------
// Live chat (source/DirectChat.hx + PlayState.hx:2150-2177, 16396-16399, 10745-10756)
// ---------------------------------------------------------------------------
// So Cool runs a fake YouTube live chat: on every beat after the 32nd the
// source has a 50% chance of pushing a random viewer message into a rolling
// 16-line buffer and redrawing it. The data and the buffer live in
// source/DirectChat.hx; PlayState.hx owns the text (an FlxText on camEst,
// created at 2167-2177) and the render (`case 'chat message'`, 10745).
//
// The source renders one FlxText whose markup colours each line from a random
// one of five formats (`$`/`#`/`%`/`&`/`;`). HScript cannot reach
// `FlxText.applyMarkup`/`FlxTextFormatMarkerPair` reliably, so each of the 16
// lines is its own FlxText here and carries the message's colour directly - the
// same picture (one colour per line) with the source's own five colours.
//
// The block sits on `mmScreen`'s screen-space layer, which is camEst's slot:
// above the world and the fighters, below camHUD.
var mmChatLines = null;          // the 16 FlxText lines
var mmChatArray = null;          // the 16 message strings
var mmChatLineColors = null;     // each line's colour
var mmChatCount:Int = 0;                   // `DirectChat.cantidad`
var mmChatTooLong:Bool = false;            // `DirectChat.tooLong`
var mmChatLong:String = "";                // `DirectChat.chatLong`
var mmChatText:String = "";                // `DirectChat.chatText`
var mmChatColor:Int = 0xFFFFFFFF;
var mmChatBaseY:Float = 30;
var mmChatLineH:Float = 18;

// The five FlxTextFormat colours (PlayState.hx:518-522), by `usercolor` 1-5.
var mmChatColors = [0xFFFF0000, 0xFF4888F0, 0xFF76E657, 0xFFE4F55F, 0xFFF04891];

// 2167-2177: one FlxText, x 860 / width 818, pixel.otf 16 white with a black
// outline. The downscroll half is 2212's `livechat.y = 320`.
function mmChatBuild() {
	mmChatBaseY = mmDownScroll() ? 320 : 30;
	mmChatArray = [];
	mmChatLineColors = [];
	for (i in 0...16) {
		mmChatArray.push("");
		mmChatLineColors.push(0xFFFFFFFF);
	}
	mmChatCount = 0;
	mmChatTooLong = false;
	mmChatLong = "";
	// A single FlxText spaces its lines by the font's own leading; each line is
	// its own text here, so measure one line once.
	var probe = new FlxText(0, 0, 0, "A", 16);
	probe.setFormat(Paths.font("pixel.otf"), 16, FlxColor.WHITE, "left", FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
	mmChatLineH = probe.height;
	probe.destroy();
	if (mmChatLineH <= 0 || Math.isNaN(mmChatLineH)) mmChatLineH = 18;
	mmChatLines = [];
	for (i in 0...16) {
		var t = new FlxText(860, mmChatBaseY + i * mmChatLineH, 818, "", 16);
		t.setFormat(Paths.font("pixel.otf"), 16, FlxColor.WHITE, "left", FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		mmScreen(t);
		mmChatLines.push(t);
	}
	mmChatRender();
}

function mmChatRender() {
	if (mmChatLines == null) return;
	for (i in 0...16) {
		mmChatLines[i].text = mmChatArray[i];
		mmChatLines[i].color = mmChatLineColors[i];
	}
}

// DirectChat.addMessage(): one viewer message, wrapped at 35 characters into the
// rolling 16-line buffer. A wrapped message calls itself again for its tail, as
// the source does.
function mmChatAddMessage() {
	if (!mmChatTooLong) {
		var messages = [
			"what about gd", "mid", "will you play fnaf later?", "yooo mario", "alr",
			"ITS MARIO OMG", "lmao", "LMAOOOO", "what", "l", "w", "no way",
			"can you play oddysey?", "what happened to miyamoto", "is that mario",
			"is the guy from marvel", "is the guy from marvel?", "is the guy from marvel!",
			"are you the guy from fnf?", "salami", "this is great", "oh", "woo banger",
			"this shit straight fire", "BROOO????", "hi boyfriend", "its a me",
			"love this man", "thats cool", "he looks like markiplier", "so cool", "how",
			"Yeaaaa", "hi", "WTF Chris Pratt?", "what about charles",
			"this movie is gonna suck", "ew illumination", "what the fuck",
			"WHAAAAAAAAAT", "no fucking way", "what is nintendo thinking",
			"i wonder who luigi is?", "bruh", "hi", "i was here", "ratio",
			"you fell off", "hi youtube", "is that your gf in the bg?", "bro ur gf is hot",
			"bro ur gf is ugly", "fuck you leaker", "sonic.exe is better",
			"will you rap battle me plz", "someone gift me a sub plz",
			"someone give me money plz", "fight me bro", "i lov pstasa nigh",
			"oh look a free ipad", "ca n I be in the chat....", "the g", "ola causa",
			"there should be an fnf mod of this", "me when fnf", "cry about it",
			"y es todo un tema viste", "ojo", "I love Balloon Boy", "XD", "couch potato",
			"have you ever wanted movies free", "this is the story of a girl",
			"brown bricks", "let me tell you a sad story", "6 piece chicken nuggets",
			"McFlurry", "Sus ojos le sangraban...", "bring on tha thunda",
			"hop on among us cuz", "sussy facecam",
			"los dioses de mi causa me han abandonado",
			"hippopotomonstrosesquippedaliophobia", "deez nuts",
			"bro thinks he's mario", "[message deleted by moderator]",
			"[message deleted by moderator]", "[message deleted by moderator]",
			"this shit STIIIIINKS", "Fue mi pene", "last message", "shithead",
			"hey BF how do you say flan", "He looks like Theodore the Chipmunk",
			"This is like a wario take on remember the alamo", "PISS FAT???",
			"this is so gangster holy shit", "so no smash?", "Can you play GD?",
			"This sucks, next song",
			"Dude, I know this is unrelated, but I need your help right now.",
			"Wanna become famous? Buy followers, at bigfollows.com!", "Gushers",
			"unfortunately, ratio", "Galápagos Tortoise", "gracias a dios que es viernes",
			"Hes so cool...", "This is going to be a disaster",
			"are we getting a Chris Pratt amiibo?", "Can you play fortnite?",
			"They should add chris pratt to fortnite", "PILGRIM SPONGEBOB???",
			"whens twinsanity", "is chris pratt a duende?", "this has to be a joke",
			"reggie would be rolling in his grave rn", "wtf", "aint no way",
			"oh goodness gracious", "mid march?", "shouldve been adam sandler tbh",
			"Its a BAD day for mario", "yeah this is fucked",
			"can you play desert bus next?", "get a load of this guy",
			"MY MARIO?!? THEY TOOK HIM!!!!", "is that christian bale from star wars?",
			"vaya mierda", "want robux? visit FREEROBUX.COM and become a MILLIONARE !",
			"yeah man", "midlicious", "Lol, lmao even", "oh, thats chris pratt",
			"I love these beans", "MOM GET THE PS5", "me rio?"
		];
		var usernames = [
			"Bleakim", "BootMunde", "CatAlone", "Cooledia", "DanceRocker", "Ellacens",
			"EnergyHan", "Giglobus", "GlimmerAut", "Guantonk", "Hacksale", "Jinom",
			"Kavenix", "LastingBorg", "NotesGlory", "Teal", "Sun", "Poolis", "Raptw",
			"Sexylo", "Sistergy", "Sowf", "Specism", "Sticomyl", "StoopFamous",
			"Tallyda", "Terreve", "Thebesten", "Vitexce", "VodForum", "WakeboardBox",
			"Zippoix", "zxppy", "candel", "fnaffreddy", "GP", "Red", "lemonaid2",
			"Magik", "StrawDeutch", "NateTDOM", "theWAHbox", "PepeMago", "Chad",
			"fishlips77", "justbruh", "BestEnd", "sharlet", "Gerardo", "mikhobb",
			"CaptCake", "Colacapn", "lillypad", "Zendraynix", "wyvernGoddess",
			"paradiseEvan", "manmakestick", "blueknight250", "fivein_",
			"CoreCombatant", "shapperoni", "maxinoise", "A_vacuum", "ewademar",
			"buttnugget", "nugass", "lordbossmaster", "artugamerpro99", "byelion",
			"friedfrick", "friedrick", "fredrick", "MXgaming", "kingf0x", "MundMashup",
			"Gadget", "MikeMatei", "sponge", "Super Johnsons", "Smellvin", "Beefrunkle",
			"Faro", "doug", "C0mix_Z0ne", "StingaFlinn", "OpillaBowd",
			"AwesomeHuggyWuggy", "Reki", "PaulFart", "Zeroh", "GamesCage", "Soup",
			"MetalFingers", "MetalFace", "Zeurel", "Lythero", "IheartJustice", "JCJack",
			"Ironik", "Sturm", "ChurgneyGurgney", "Jerma985", "DougDoug", "Chris Snack",
			"Duende", "CasualCaden", "BadArseJones", "marmot", "BeegYoshi", "Sandi",
			"johnsonVMUleaker", "weedeet", "HaroldGlover902", "Griog", "The_Beast",
			"Zebo", "BelowNatural", "FreddyFreaker", "Marquitoswin", "DastardlyDeacon",
			"VibingLeaf", "RedTv53", "VanScotch", "haywireghost", "Persona_Random",
			"tia_Marie",
			// From here down the names carry their own message.
			"Joe_Biden", "Ney", "turmoil", "care", "mx", "saster", "evil mario", "wega",
			"winniethepooh", "moldy mario", "mr.l", "useraqua", "EllisBros", "Dave",
			"JackBlack", "Vania", "scrumbo_", "Linkara", "mark", "Fernanfloo",
			"Vargskelethor", "MrDink", "FatAlbert", "Hermanoquebasto", "Clue_Buddy",
			"anderson043", "Robotnik", "ElRubisOMG", "Walter_White", "Ganon", "Joker",
			"Super Wario Man", "WhiteyDvl", "misterSYS"
		];

		var usercolor:Int = FlxG.random.int(1, 5);
		mmChatColor = mmChatColors[usercolor - 1];
		var msg:String = messages[FlxG.random.int(0, messages.length - 1)];
		var user:String = usernames[FlxG.random.int(0, usernames.length - 1)];

		switch (user) {
			case "saster": msg = "hi guys, i'm saster";
			case "turmoil":
				if (FlxG.random.bool(50)) msg = "i'm hungry";
			case "mx":
				msg = FlxG.random.bool(50) ? "innocence doesn't get you far" : "lucas...";
			case "evil mario": msg = "Mario hates you very much";
			case "moldy mario":
				msg = FlxG.random.bool(50) ? "i am trapped in your sewer" : "help me charlie";
			case "wega": msg = mmChatWega();
			case "winniethepooh":
				msg = FlxG.random.bool(50) ? "oh b(r)other" : "i'm winnie the pooh";
			case "mr.l":
				msg = FlxG.random.bool(50) ? "it's too late" : "L-ater";
			case "JackBlack":
				msg = FlxG.random.bool(50) ? "FUCK YOU! YOU FUCKIN' DICK" : "octagon is an amazing shape that has 8 fantastic sides and 8 awesome angles";
			case "Vania": msg = "sure, why not?";
			case "scrumbo_": msg = "We're Straight Up Evil, FeelMasters";
			case "useraqua":
				msg = FlxG.random.bool(50) ? "holy sweet mother of pibby" : "salvage solos this trash";
			case "EllisBros": msg = "You thought Miyamoto worked alone?";
			case "Dave": msg = "Good fuckin' stream, old sport!";
			case "Ney":
				msg = FlxG.random.bool(50) ? "This isn't the video to get free V-Bucks" : "NO WAY! It's Piss Chratt!";
			case "Linkara":
				msg = FlxG.random.bool(50) ? "If its you or the worms I pick the worms every time" : "I am the light bringer!";
			case "Fernanfloo": msg = "Chorizo";
			case "Vargskelethor": msg = "the jurassic park guy???";
			case "MrDink": msg = "YOU BROKE MY GRILL?!?";
			case "FatAlbert": msg = "Oh no I'm late to work hurhurhur";
			case "mark":
				switch (FlxG.random.int(1, 3)) {
					case 1: msg = "Do you want to touch my shiny bald head?";
					case 2: msg = "Come on, Mark with me!";
					case 3: msg = "mark you next time";
				}
			case "Hermanoquebasto": msg = "Pensabas que estaba muerto no? pues no, no lo estaba!";
			case "Clue_Buddy": msg = "Get a clue, buddy!";
			case "anderson043": msg = "no ve er nota este";
			case "Robotnik": msg = "SNOOPINGas usual I see!";
			case "ElRubisOMG": msg = "pero esto que es chaval tio que cojones";
			case "Walter_White":
				msg = FlxG.random.bool(50) ? "We need to COOK" : "I AM the one who knocks";
			case "Ganon": msg = "You dare bring light to my lair!? YOU MUST DIE!";
			case "Joker": msg = "Just one good jelq sesh... Can change a man...";
			case "Super Wario Man":
				msg = FlxG.random.bool(50) ? "Esta bonito" : "Esta Bien Culero";
			case "WhiteyDvl":
				msg = FlxG.random.bool(50) ? "THAT'S a technical fouuul..." : "Here comes the seuizure nyeuuughghghjuhgh";
			// 'EleanorDvl' is not in the usernames table, so the source can never
			// pick it; kept literal here anyway.
			case "EleanorDvl":
				msg = FlxG.random.bool(50) ? "Has anyone seen my wig" : "It's horrible!";
			case "Joe_Biden":
				switch (FlxG.random.int(1, 4)) {
					case 1: msg = "I have a sister who's the love of my life...";
					case 2: msg = "SODA!!!!!!";
					case 3: msg = "I got hairy legs.";
					case 4: msg = "chocolate chocolate chip";
				}
			case "misterSYS":
				if (FlxG.random.bool(50)) msg = "this song is truly unbeatable";
		}

		mmChatText = user + ": " + msg;
	} else {
		mmChatTooLong = false;
		mmChatText = mmChatLong;
	}

	// The 35-character wrap (DirectChat's own split): the overflow becomes the
	// next call's message line and the first 35 characters this one, both marked
	// with a '-' so the continuation reads as one.
	if (mmChatText.length > 35) {
		mmChatLong = "-" + StringTools.ltrim(mmChatText.substr(35));
		mmChatText = StringTools.rtrim(mmChatText.substr(0, 35)) + "-";
		mmChatTooLong = true;
	}

	if (mmChatCount >= 16) {
		for (i in 0...(16 - 1)) {
			mmChatArray[i] = mmChatArray[i + 1];
			mmChatLineColors[i] = mmChatLineColors[i + 1];
		}
		mmChatArray[15] = mmChatText;
		mmChatLineColors[15] = mmChatColor;
	} else {
		mmChatArray[mmChatCount] = mmChatText;
		mmChatLineColors[mmChatCount] = mmChatColor;
		mmChatCount += 1;
	}
	mmChatRender();
	if (mmChatTooLong) mmChatAddMessage();
}

// DirectChat.hx:386's "B" + 93 "A"s + "HHHHH", built rather than transcribed.
function mmChatWega():String {
	var s:String = "B";
	for (i in 0...93) s += "A";
	return s + "HHHHH";
}

// 16396-16399: the chart-independent beat branch (not a 'Triggers' case).
function beatHit() {
	if (FlxG.random.bool(50) && curBeat > 32) mmChatAddMessage();
}

// === end MM stage triggers ===
