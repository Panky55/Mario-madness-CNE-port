// Note skins and note splashes.
//
// Psych's StrumNote/Note default every song of this mod to 'Mario_NOTE_assets'
// (`StrumNote.hx:41 var skin:String = 'Mario_NOTE_assets';`, and `Note.hx:393`
// falls back to the same name whenever `SONG.arrowSkin` is empty - all 41
// songData files here leave `arrowSkin` empty or null).  Codename has no such
// default: a note wears `game/notes/default` unless a script points it
// elsewhere, so the port was drawing the engine's own arrows instead of the
// mod's.
//
// `onNoteCreation` / `onStrumCreation` are the hooks for it.  `Note.hx` builds
// its `NoteCreationEvent` with `noteSprite = 'game/notes/default'` and then does
// `Paths.getFrames(event.noteSprite)` unless the event was cancelled;
// `StrumCreationEvent.sprite` is documented as "sprite path, in case you only
// want to change the sprite".  The mod's atlas has the frame names the engine
// asks for (`purple0`, `purple hold piece`, `pruple end hold`, ...), so pointing
// at it is all that is needed - no `cancel()` and no manual animation setup.
// The PNG/XML pairs are copied to `images/game/notes/` by port_marios_madness.py
// (`copy_assets`), the folder the engine's own note skins live in.
//
// The per-note-type skins are the other half, and they are not cosmetic
// defaults: Psych's `Note.set_noteType` (`source/Note.hx:110-235`) runs
// `reloadNote(<prefix>)` for most of this mod's note types, and `reloadNote`
// rebuilds the note's frames from `<prefix>` + the default skin name
// (`'poison'` + `'Mario_NOTE_assets'` = `poisonMario_NOTE_assets`), so a poison
// note is drawn with the poison sheet, a coin note with the coin sheet, and so
// on.  That branch *also* nudges two of them around (`Note.hx:199-232`: a
// `Bullet Bill` by (-50, +10), a `Bullet2` by (-163, +10), y-flipped and pulled
// up by their own height in downscroll).  Both keep the normal 0.7 note scale:
// `bullet` is set *after* `reloadNote('BulletBill')` (`Note.hx:201`), so the
// `if(!bullet) setGraphicSize(width * 0.7)` inside `loadNoteAnims` still runs
// and there is no atlas-size head - the two projectiles are the same size and
// must land on top of each other.  The flip and both nudges are applied in the
// hooks below (both nudges through `frameOffset`, since `offset` cancels - see
// the list).  Those nudges are applied by the fork to the note's *sprite box*
// (`daNote.x = strums[n].x + daNote.offsetX`, `PlayState.hx:8276-8282`), so the
// projectile's left edge is lined up with its strum's; this engine centres the
// note's frame on the strum instead, so `mmBulletFrameOffset()` converts one
// convention into the other (and, because the conversion carries the note's own
// `frameWidth * scale` term, the two types do not take the same shift).  Both
// conversions are head-only: on a sustain the `frameWidth` is the hold piece and
// the live `scale.y` is the hold's length, so a head-sized nudge would be
// multiplied several times over - see `onPostNoteCreation`.
//
// The mod ships its own `noteSplashes` sheet as well.  Psych's `NoteSplash`
// starts from `SONG.splashSkin` and falls back to 'noteSplashes', which is what
// every songData of this mod ends up on (20 name it, the other 4 leave it
// empty), so all notes get `splash = 'noteSplashes'` here.  Codename mounts a
// splash group per `note.splash` through `Paths.xml('splashes/<name>')`, which
// the data file `data/splashes/noteSplashes.xml` (port_templates/splashes/)
// fills in, pointing at the mod's sheet in `images/game/splashes/`.
//
// The four pixel stages (`virtual`, `landstage`, `somari`, `piracy`) are ported,
// not skipped: their sheets are plain PNGs rather than sparrow atlases
// (`pixelUI/NES_NOTE_assets` and its `...ENDS` sustain twin), and Psych slices
// them by hand (`StrumNote.hx:50-83`, `Note.hx:409-447`) - which is exactly what
// `noteSprite` cannot describe.  So those four cancel the creation event and do
// the same slicing here: `loadGraphic(path)` to measure the sheet, then
// `loadGraphic(path, true, imageWidth / 4, imageHeight / rows)` (5 rows for a
// note head, 2 for a sustain's `ENDS` sheet, 5 for a strum), then the fork's own
// animations under this engine's names (`scroll`/`hold`/`holdend` on notes,
// `static`/`pressed`/`confirm` on strums) so the engine's own post-create code
// (`animation.play('scroll')`, `playAnim('static')`) still finds them.  The base
// sheet, the pixel zoom (virtual 3.5, piracy 2.6, `daPixelZoom` 6 otherwise,
// `PlayState.hx:752`) and the exceptions are the source's: landstage's *old*
// song drops back to the default skin name (`pixelUI/Mario_NOTE_assets`), and
// because `reloadNote` folds the type prefix into the name before the pixel
// branch prepends it again, a typed note there loads a double-prefixed sheet
// (`poisonpoisonMario_NOTE_assets`) - both are in the extracted `pixelUI/`
// folder, so that is the fork's own naming, not a typo.  `Ring Note` (only ever
// in `mario-sing-and-game-rythm-9`, stage `somari`) is covered by the same
// prefix path: `pixelUI/ringNES_NOTE_assets`.  A sheet the mod does not ship - a
// poison *sustain* on Golden Land Old is the one case, there is no
// `poisonpoisonMario_NOTE_assetsENDS` - leaves that note with the engine's own
// arrows and traces once, instead of Psych's missing-image box.
//
// Two more source behaviours are ported here:
//   - the `Bullet Bill`/`Bullet2` splash *sheet*.  The source swaps the splash
//     texture for those two types (`Note.hx:199/221`
//     `noteSplashTexture = 'BulletBillMario_NOTE_assets'`, whose `loadAnims`
//     branch builds every lane/variant from a single `addByPrefix('notesplash')`)
//     and raises its alpha to 1 (`NoteSplash.hx:35-46`).  A bullet note's `splash`
//     now points at `data/splashes/BulletBill.xml`, which mounts that same strip
//     from the bullet atlas.  The source also repositions the splashes by hand
//     (x-370 / y-340 upscroll, y-620 + flipY downscroll); Codename centres a
//     splash on its strum, so that offset is not reproduced (the mod's own
//     sheet leaves it off for the same reason).
//   - the botplay skin.  While botplay is on, the source re-skins every strum
//     and every note that keeps a generic skin to `Luigi_NOTE_assets`
//     (`PlayState.hx:6898-6914`, `7026-7038`, `7236 note.reloadNote('',
//     'Luigi_NOTE_assets')`).  `mmBotplaySkin()` reproduces it for the non-pixel
//     stages; the typed notes whose source `botplaySkin = false` keep their own
//     sheet, and the pixel/End stages are excluded as in the source.
//   - the pixel *sustain*'s centring.  The source nudges its sustains sideways
//     (`Note.hx:325-336`: `offsetX += -100/+4` on virtual, `-15/+30` on piracy,
//     `+30` otherwise), but that is a Psych placement artefact and is NOT
//     reproduced - see `mmPixelSustainArtShift` for why, and for the only
//     correction a pixel hold actually needs on this engine.  The zooms are
//     ported as before.
//
// Not ported, and why:
//   - the pixel sustain's extra `scale.y *= PlayState.daPixelZoom`
//     (`Note.hx:364-368`): Psych stretches its hold piece by hand after
//     `updateHitbox`, while this engine's `Strum.updateSustain` writes `scale.y`
//     from the sustain's length and the sliced frame height, so that write would
//     be overwritten on the next frame anyway.
//   - the somari pixel splash (`NoteSplash.hx:71-77`): `pixelUI/splash-NES`, a
//     4x4 plain sheet at `daPixelZoom`, sliced by hand like the arrows.  This
//     engine mounts splashes from `data/splashes/<name>.xml`, which describes a
//     sparrow atlas, so somari keeps the mod's normal `noteSplashes` sheet.
//   - `Note.offset`, which cannot move a Codename note: a strum-relative note's
//     `draw()` repositions the sprite from the strum and carries its logical
//     position in `frameOffset` instead, so an `offset`/`offsetX` written from a
//     script is a silent no-op (this is also why the source's `x += offsetX`
//     nudges below are reproduced through `frameOffset`).  The pixel sustains
//     and the `Bullet Bill` nudges both route around it that way (see
//     `onPostNoteCreation`).
//   - the bullets' `+10` / downscroll `-(height - 50)` vertical shifts *are*
//     carried across (through `frameOffset.y`, next to the x nudge).  The
//     downscroll conversion has to account for `HudCamera.alterScreenPosition`
//     anchoring a mirrored note by its box *bottom*; see
//     `mmBulletFrameOffsetY` for the arithmetic.
//   - `HURTnoteSplashes`: no chart of this mod has a `Hurt Note`.
//   - the `endstage` / `landstage` desaturation (`Note.hx:107-110` writes
//     `colorSwap.saturation = -100`): Codename notes have no colour-swap shader
//     hooked up, and none of the port's scripts wear one.

// The stages whose stage JSON says `isPixelStage: true` - exactly the four
// StrumNote special-cases, and not The End's `endstage`.
var MM_PIXEL_STAGES:Array<String> = ['virtual', 'landstage', 'somari', 'piracy'];
var MM_NOTE_SKIN:String = 'game/notes/Mario_NOTE_assets';
var MM_NOTE_DIR:String = 'game/notes/';
var MM_SPLASH_SKIN:String = 'noteSplashes';
var MM_PIXEL_DIR:String = 'pixelUI/';
var MM_PIXEL_ZOOM:Float = 6; // PlayState.daPixelZoom (752), the stage default
// `Flags.DEFAULT_NOTE_SCALE` - the engine scales every note head by this, and
// the class is not exposed as a script global, so it is mirrored here.
var MM_NOTE_SCALE:Float = 0.7;
var MM_BOTPLAY_SKIN:String = 'Luigi_NOTE_assets';
var MM_BULLET_SPLASH:String = 'BulletBill';
// The stages the source's botplay swap skips (`PlayState.hx:7026/7234`): the four
// pixel stages plus The End.  The strum half at 6898 tests only `!isPixelStage`,
// which would leave The End's strums Luigi while its notes stay Mario; the port
// applies the note guard to both and notes the choice here.
var MM_BOTPLAY_EXCLUDED:Array<String> = ['virtual', 'landstage', 'somari', 'endstage', 'piracy'];

function mmStage() {
	return (PlayState.SONG != null) ? PlayState.SONG.stage : null;
}

function mmIsPixelStage() {
	var songStage = mmStage();
	return songStage != null && MM_PIXEL_STAGES.indexOf(songStage) >= 0;
}

// The player strumline's `cpu` flag is this engine's `cpuControlled` - the
// switch the source checks before it re-skins anything to Luigi.
function mmBotplay():Bool {
	if (strumLines == null || strumLines.members == null || strumLines.members.length < 2) return false;
	var line = strumLines.members[1];
	return line != null && line.cpu == true;
}

function mmBotplaySkin():Bool {
	if (mmIsPixelStage()) return false;
	var songStage = mmStage();
	return songStage != null && MM_BOTPLAY_EXCLUDED.indexOf(songStage) < 0 && mmBotplay();
}

// The types whose source `botplaySkin` stays false (`Note.hx:131-210`), i.e. the
// ones that keep their typed sheet while botplay is on.  'Nota boo' is absent on
// purpose: the source reloads its frames but never clears the flag, so a boo note
// does take the Luigi skin.
function mmTypeLocksSkin(noteType):Bool {
	switch (noteType) {
		case 'Nota veneno', 'Nota bomba', 'Coin Note', 'Water Note', 'Bullet',
			'Bullet Bill', 'Bullet2', 'Bad Poison', 'jumpscareM', 'Hurt Note',
			'Yoshi Note':
			return true;
		default:
			return false;
	}
}

// `Note.hx:110-235` - `reloadNote(prefix)` = prefix + 'Mario_NOTE_assets'.
// Untyped params like the other helpers (`mmSongName()` in MMcamera.hx): a note
// with no type hands us null.
function mmTypeSkin(noteType) {
	switch (noteType) {
		case 'Nota veneno': return 'poisonMario_NOTE_assets';
		case 'Nota bomba': return 'bombMario_NOTE_assets';
		case 'Nota boo': return 'booMario_NOTE_assets';
		case 'Coin Note': return 'coinMario_NOTE_assets';
		case 'Water Note': return 'waterMario_NOTE_assets';
		case 'Bullet': return 'BulletMario_NOTE_assets';
		case 'Bullet Bill': return 'BulletBillMario_NOTE_assets';
		case 'Bullet2': return 'BulletBillMario_NOTE_assets';
		case 'Bad Poison': return 'badMario_NOTE_assets';
		case 'jumpscareM': return 'JMMario_NOTE_assets';
		case 'Hurt Note': return 'HURTMario_NOTE_assets';
		case 'Yoshi Note': return mmYoshiSkin();
		default: return null;
	}
}

// `Note.hx:210-216`: the Yoshi note is drawn invisible on three stages only, so
// the check is on the stage and not on the type alone.
function mmYoshiSkin() {
	var songStage = mmStage();
	if (songStage == 'exesequel' || songStage == 'betamansion' || songStage == 'nesbeat')
		return 'invisibleMario_NOTE_assets';
	return null;
}

function onNoteCreation(event) {
	// Psych's NoteSplash default (`NoteSplash.hx:18`) - the mod's own sheet, not
	// the engine's `game/splashes/default`.  Dictator's projectiles use the
	// bullet sheet instead (`Note.hx:199/221 noteSplashTexture`), mounted from
	// `data/splashes/BulletBill.xml`.
	event.note.splash = (event.noteType == 'Bullet Bill' || event.noteType == 'Bullet2')
		? MM_BULLET_SPLASH : MM_SPLASH_SKIN;
	if (mmIsPixelStage()) {
		mmPixelNote(event);
		return;
	}
	var skin = null;
	// `PlayState.hx:7236`: every note whose `botplaySkin` is still set takes the
	// Luigi sheet while botplay is on.
	if (mmBotplaySkin() && !mmTypeLocksSkin(event.noteType)) skin = MM_BOTPLAY_SKIN;
	if (skin == null) skin = mmTypeSkin(event.noteType);
	if (skin == null) skin = 'Mario_NOTE_assets';
	event.noteSprite = MM_NOTE_DIR + skin;
	// `Note.hx:196-201`: the Bullet Bill case calls `reloadNote('BulletBill')`
	// first and only then sets `bullet`, so `loadNoteAnims`' `if(!bullet)`
	// test still sees false and resizes the projectile to `width * 0.7` like
	// every other note.  Both Dictator types are therefore drawn at the normal
	// scale - do not divide `event.noteScale` back out for the head.
}

// The strums never follow the note type in the source - only `StrumNote`'s own
// default skin (and the botplay/pixel swaps, see the header).
function onStrumCreation(event) {
	if (mmIsPixelStage()) {
		mmPixelStrum(event);
		return;
	}
	// `PlayState.hx:6898-6914`/`7026-7038`: both strumlines wear Luigi while
	// botplay is on (outside the pixel/End stages).
	event.sprite = mmBotplaySkin() ? MM_NOTE_DIR + MM_BOTPLAY_SKIN : MM_NOTE_SKIN;
}

// 300-306: the fork leaves Somari's holds fully opaque (its `curStage != 'somari'`
// guard skips the 0.6 write), while this engine writes `alpha = 0.6` for every
// sustain *after* the creation event has run, so the exception is re-applied
// here.  The post event is the same object the engine re-dispatches.
function onPostNoteCreation(event) {
	var n = event.note;
	if (n == null) return;
	// Note.hx:202-205/228-231: Dictator's two projectile types point down
	// under downscroll. HudCamera mirrors positions, not the sprites' art,
	// and Note.isOnScreen resets flipY to false for non-sustains by default.
	// Opt these heads out of that reset so the source's flip survives drawing.
	if (event.noteType == 'Bullet Bill' || event.noteType == 'Bullet2') {
		n.updateFlipY = false;
		n.flipY = downscroll;
		// Heads only.  The two conversions below are written for a *note head*,
		// and a sustain is not one in either term:
		//
		//   - `mmBulletFrameOffset` carries the note's own `frameWidth`, which on
		//     a sustain is the hold piece (50px), not the projectile sheet's box
		//     (463px), so the lane-centring term changes value;
		//   - both writes are turned into pixels by the sprite's live `scale`, and
		//     a sustain's `scale.y` is its *length* in frame units (see
		//     `Note.updateSustain`: `scale.y = sustainLength * 0.45 * speed /
		//     frameHeight`), not the note scale.  A nudge sized for the head is
		//     therefore multiplied by 4-30x on a shaft, which throws the hold's
		//     body and its end cap far off its own head.
		//
		// The fork's nudges are a flat sprite-box offset there (`daNote.x =
		// strums[n].x + daNote.offsetX`), and this engine cannot express a flat
		// box offset on a stretched sustain through `frameOffset` at all, so the
		// hold is left where a hold of any other note type sits - aligned with
		// its lane - instead of being thrown by the head's constant.
		if (!n.isSustainNote) {
			// `Note.hx:199-232`'s -50/-163 offsets land the pair (one lane
			// apart, 112px at the default note scale) on top of each other - both
			// types are the same size, so they stack into one projectile.  `Note.
			// offset` cancels in this engine (see the header), and this engine draws
			// a strum-relative note centred on its strum, so the nudges go through
			// `mmBulletFrameOffset()` (see it for the exact arithmetic).
			n.frameOffset.x = mmBulletFrameOffset(event.noteType == 'Bullet Bill' ? 50 : 163, n.scale.x, n.frameWidth);
			// `Note.hx:209/224`'s `offsetY += 10` (both types) plus the downscroll
			// `offsetY -= height - 50`, converted for this engine's anchoring (see
			// `mmBulletFrameOffsetY` - the mirrored camera anchors a downscroll note
			// by its box *bottom*, so the strum's height is needed here).
			n.frameOffset.y = mmBulletFrameOffsetY(n.height, mmBulletStrumHeight(event), n.scale.y, downscroll);
		}
	}
	if (mmStage() == 'somari' && n.isSustainNote) n.alpha = 1;
	// A pixel hold's art does not fill its sheet cell, so its art centre sits
	// off the frame centre; pull it back on with the frame translation
	// (`-frameOffset * scale`, see `mmPixelSustainArtShift`).  The source's own
	// scroll-dependent `offsetX` nudge is deliberately not applied - same
	// reference, same reason as there.
	if (n.isSustainNote && mmIsPixelStage())
		n.frameOffset.x = -mmPixelSustainArtShift();
}

// ---------------------------------------------------------------------------
// The pixel slicer (`StrumNote.hx:50-83`, `Note.hx:409-447`)
// ---------------------------------------------------------------------------
// The stage's base sheet: GB on the modern Golden Land, NES on Somari, DS on
// Piracy, Virtual on Paranoia.  Golden Land *Old* fails the source's
// `SONG.song != 'Golden Land Old'` guard and falls through to the default skin
// name - the sheet `pixelUI/Mario_NOTE_assets` really exists.
function mmPixelBase():String {
	var songStage:String = mmStage();
	if (songStage == 'virtual') return 'Virtual_NOTE_assets';
	if (songStage == 'somari') return 'NES_NOTE_assets';
	if (songStage == 'piracy') return 'DS_NOTE_assets';
	if (songStage == 'landstage') return mmGoldenLandOld() ? 'Mario_NOTE_assets' : 'GB_NOTE_assets';
	return null;
}

function mmGoldenLandOld():Bool {
	if (PlayState.SONG == null) return false;
	var meta = Reflect.field(PlayState.SONG, 'meta');
	if (meta != null) {
		var display = Reflect.field(meta, 'displayName');
		if (display != null && StringTools.trim('' + display) == 'Golden Land Old') return true;
	}
	var name = Reflect.field(PlayState.SONG, 'song');
	return name != null && ('' + name) == 'Golden Land Old';
}

function mmPixelZoom():Float {
	var songStage:String = mmStage();
	if (songStage == 'virtual') return 3.5;
	if (songStage == 'piracy') return 2.6;
	return MM_PIXEL_ZOOM;
}

// The engine's own lane width - `StrumLine.generateStrums` spaces the strums by
// `Note.swagWidth * strumScale * spacing` (`v1.0.1 StrumLine.hx:386`), and the
// strum's frame is the same 160 * 0.7 box, so its `width` is one lane.
var MM_LANE_WIDTH:Float = 160 * MM_NOTE_SCALE; // Note.swagWidth

// `Note.hx:199-232`'s -50 (Bullet Bill) / -163 (Bullet2) nudges, converted from
// the fork's box offset into this engine's `frameOffset`.
//
// Psych moves the note's *sprite box*: `daNote.x = playerStrums.members[
// daNote.noteData].x + daNote.offsetX` (`PlayState.hx:8276-8282`), and the
// strum's `x` is its box's left edge, so a note's left edge sits on its strum's
// left edge (plus `offsetX`).  This engine (v1.0.1) centres the note's frame on
// the strum instead: `Strum.updateNotePos` puts a strum-relative note at
// `x = (strum.width - note.width) / 2`, and `Note.draw` then draws the note from
// `__strum.x` with `frameOffset.x -= x / scale.x`, so the note's frame centre
// lands at `strum.x + strum.width * 0.5 - frameOffset.x * scale.x`.
//
// For a plain note the two conventions agree - its frame is one lane wide, so
// centring it puts its left edge on the strum's.  The projectiles' frame is
// 463px (the `BulletBillMario_NOTE_assets` box) though, so centring drags the
// pair a lane and a half to the left of where the fork draws them.
//
// Matching the fork means putting the frame's left edge at
// `strum.x + offsetX` (offsetX being the source's -50 / -163), i.e.
//
//     frameOffset.x * scale = lane/2 - frameWidth*scale/2 - offsetX
//
// `nudge` is the source's `-offsetX` (50 / 163) so the call reads positively.
// The `frameWidth * scale` term is what matters: it depends on the note's own
// scale, so the `Bullet2` (0.7) needs a different `frameOffset` from the
// `Bullet Bill` (1).  A single constant shift (the head's own half-frame, 175.5)
// leaves the scaled tail ~68px off and the pair stops reading as one projectile.
// Only these two types need it: every other note frame is one lane wide, where
// the two conventions already agree.
function mmBulletFrameOffset(nudge:Float, noteScale:Float, frameWidth:Float):Float {
	if (noteScale == 0) return 0;
	return (MM_LANE_WIDTH * 0.5 - frameWidth * noteScale * 0.5 + nudge) / noteScale;
}

// The strum a projectile note belongs to, so the y nudge below can use its
// height.  Falls back to a lane's width if the strums are not up yet.
function mmBulletStrumHeight(event):Float {
	if (event == null || event.strumLineID == null || event.strumID == null) return MM_LANE_WIDTH;
	var ps = PlayState.instance;
	if (ps != null && ps.strumLines != null && ps.strumLines.members != null) {
		var line = ps.strumLines.members[event.strumLineID];
		if (line != null && line.members != null && line.members.length > 0) {
			var strum = line.members[event.strumID % line.members.length];
			if (strum != null && strum.height != null && strum.height > 0) return strum.height;
		}
	}
	return MM_LANE_WIDTH;
}

// `Note.hx:209/224`'s `offsetY`: `+10` for both projectile types, and under
// downscroll another `-(height - 50)` - `height` being the note's own height at
// the time the type was set (both types reload at the normal 0.7 scale, so they
// agree).  Psych draws the note's box *top* at `strumY + offsetY`; this engine
// anchors the box differently per direction:
//
//   - upscroll `HudCamera.alterScreenPosition` is a no-op, so the box top sits
//     on the strum's top - the frame shift just has to equal `offsetY`:
//     `-frameOffset.y * scale.y = offsetY`.
//   - downscroll the camera mirrors with `height - y - spr.height`, which
//     anchors the box *bottom* on the strum's bottom.  The projectile's box is
//     much taller than the strum's, so it starts a whole height too high and
//     the shift has to make that up:
//     `-frameOffset.y * scale.y = (strumHeight - noteHeight) - offsetY`.
//
// Substituting the source's downscroll `offsetY` cancels the note height
// entirely there, leaving `strumHeight - 60` - which is exactly the `50` of
// `-(height - 50)` minus the `+10`, i.e. where the flipped projectile's nose
// should sit relative to the strum's top.
function mmBulletFrameOffsetY(noteHeight:Float, strumHeight:Float, noteScale:Float, down:Bool):Float {
	if (noteScale == 0) return 0;
	var offsetY:Float = 10 + (down ? -(noteHeight - 50) : 0);
	var anchor:Float = down ? (strumHeight - noteHeight) : 0;
	return (anchor - offsetY) / noteScale;
}

// A pixel hold's whole placement, on this engine.  Two of the ENDS sheets pack
// each 30px/25px piece into the left of a wider cell instead of filling it, so
// the art centre sits left of the frame centre and the hold body hangs beside
// its own head.  Measured off the art (alpha bbox per cell, 4 columns by 2
// rows):
//
//   Virtual_NOTE_assetsENDS  240x12, 60x6 cells, art x[0-29]  -> 15px left of
//                            centre, i.e. 15 * 3.5 = 52px on screen in Paranoia
//   DS_NOTE_assetsENDS       204x12, 51x6 cells, art x[3-27]  -> 10px left of
//                            centre (10 * 2.6 = 26px on screen in Piracy)
//
// Every other pixel sheet fills its frame (GB/NES/the typed ENDS sheets are
// within half a pixel of centred), so they need nothing - which is why the
// reference port applies this correction only on `virtual`.  The value is in
// *frame* pixels, the same unit as `frameOffset` itself, so it is not divided by
// the live scale.
//
// Why this is the *only* hold correction, and the source's scroll-dependent
// `offsetX` nudge is dropped:
//
//   Psych places a note's sprite-box left edge at `strum.x + offsetX`
//   (`PlayState.hx:8275-8286`) and gives the sustain sheet the same 60px/51px
//   cell, so its `offsetX` (+4/-100 virtual, -15/+30 piracy, +30 otherwise) is
//   really a sprite-placement constant there.  This engine instead *centres* a
//   strum-relative note's frame on its strum - `Strum.updateNotePos`:
//   `x = (strum.width - note.width) / 2`, then `Note.draw` re-anchors the sprite
//   to the strum and carries the logical position in `frameOffset` - so the
//   frame is already centred and the only thing out of place is the art inside
//   it.  Re-applying the source's nudge on top drags the body a further ~100px
//   off its head on virtual downscroll (the scroll the mod's charts play on),
//   which is exactly the "holds are off to the side" this was chasing.
//
// Derivation, for the record: with the sprite drawn centred, the hold art
// centre lands at `strumCentre + scale * (artCentreFrame - cellWidth/2 -
// frameOffset)`, so aligning it needs `frameOffset = artCentreFrame -
// cellWidth/2 = -(cell centre - art centre)` - the shift below, independent of
// the strum width and of the zoom.
function mmPixelSustainArtShift():Float {
	var songStage:String = mmStage();
	if (songStage == 'virtual') return 15;
	if (songStage == 'piracy') return 10;
	return 0;
}

// `reloadNote`'s prefix - the part of the type's skin name before
// 'Mario_NOTE_assets' (`poison` + base = `poisonGB_NOTE_assets`).
function mmTypePrefix(noteType):String {
	var skin = mmTypeSkin(noteType);
	if (skin == null) return '';
	var cut:Int = skin.indexOf('Mario_NOTE_assets');
	return (cut > 0) ? skin.substr(0, cut) : '';
}

// `pixelUI/` + <prefix> + <stage base> (+ 'ENDS' for sustains).  On Golden Land
// Old the source's `blahblah` keeps the already-prefixed default name, so the
// prefix lands twice - see the header.
function mmPixelSheet(noteType, isSustain:Bool):String {
	var base = mmPixelBase();
	if (base == null) return null;
	var prefix = mmTypePrefix(noteType);
	var name = (base == 'Mario_NOTE_assets') ? prefix + prefix + base : prefix + base;
	return MM_PIXEL_DIR + name + (isSustain ? 'ENDS' : '');
}

// The source's hand-slicing: load the sheet whole to measure it, cut it by 4
// columns and `rows` rows, load it again as an animated sheet.  A sheet the mod
// does not ship leaves the sprite alone (the caller then lets the engine draw
// its own arrows).
function mmPixelLoad(spr, path:String, rows:Int):Bool {
	if (spr == null || !Assets.exists(Paths.image(path))) return false;
	spr.loadGraphic(Paths.image(path));
	var fw:Int = Math.floor(spr.frameWidth / 4);
	var fh:Int = Math.floor(spr.frameHeight / rows);
	if (fw <= 0 || fh <= 0) return false;
	spr.loadGraphic(Paths.image(path), true, fw, fh);
	spr.antialiasing = false;
	return true;
}

// One pixel note.  The frames are the fork's (`Note.hx:502-520`): a head's
// `scroll` is the lane's arrow in row 1, a sustain's `hold`/`holdend` are its
// body and end in the ENDS sheet's two rows.  The names are this engine's -
// its own post-create code plays exactly `scroll`, `hold` and `holdend`.
function mmPixelNote(event) {
	var lane:Int = event.strumID % 4;
	var sustain:Bool = event.note.isSustainNote == true;
	var sheet = mmPixelSheet(event.noteType, sustain);
	if (sheet == null || !mmPixelLoad(event.note, sheet, sustain ? 2 : 5)) return;
	event.cancelled = true;
	var n = event.note;
	if (sustain) {
		n.animation.add('hold', [lane]);
		n.animation.add('holdend', [lane + 4]);
	} else {
		n.animation.add('scroll', [lane + 4]);
	}
	n.setGraphicSize(Std.int(n.width * mmPixelZoom()));
	n.updateHitbox();
}

// One pixel strum.  Frames from `StrumNote.hx:84-110`: statics are row 0,
// pressed row 2, confirms rows 3-4 (lane 2's pair at 12fps, the others 24), and
// the four colour frames are the row-1 arrows.  Same names this engine plays.
function mmPixelStrum(event) {
	var base = mmPixelBase();
	if (base == null || !mmPixelLoad(event.strum, MM_PIXEL_DIR + base, 5)) return;
	event.cancelled = true;
	var lane:Int = event.strumID % 4;
	var s = event.strum;
	s.animation.add('green', [6]);
	s.animation.add('red', [7]);
	s.animation.add('blue', [5]);
	s.animation.add('purple', [4]);
	s.animation.add('static', [lane]);
	s.animation.add('pressed', [lane + 8], 12, false);
	s.animation.add('confirm', [lane + 12, lane + 16], lane == 2 ? 12 : 24, false);
	s.setGraphicSize(Std.int(s.width * mmPixelZoom()));
	s.updateHitbox();
	s.playAnim('static');
}
