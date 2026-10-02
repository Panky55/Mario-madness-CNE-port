// 'Bullet' - a Pico shooting note. Ported from Mario's Madness
// (source/PlayState.hx: `noteMiss` 15275-15296 plays 'FAILGUN' and takes a round
// off the ammo counter, which is what this note's own sound is; `goodNoteHit`
// 15608-15611 re-dispatches 'Pico Shoot', the muzzle flash).
//
// The counter and the flash live on the stage - `gunAmmo` and `gunShotPico` are
// meatworld's sprites here exactly as they are PlayState's there - so
// data/stages/meatworld.hx owns both the round count (`ammo` starts at 3, four
// misses are fatal) and the flash. This file only carries the note's audio, the
// same split every other note type in this mod has.
function onPlayerMiss(event) {
	if (event.noteType != "Bullet") return;
	FlxG.sound.play(Paths.sound("FAILGUN"));
}
