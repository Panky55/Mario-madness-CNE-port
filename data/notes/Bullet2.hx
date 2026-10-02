// Source Note.hx:218-232: Bullet2 hits do not play a sing animation. The extra
// damage is on a MISS, handled by the secretbg stage's bulletTimer.
//
// The paired-hit splash + `SHbullethit` that go with this type (source
// PlayState.hx:14777-14790) are shared with `Bullet Bill` and live in
// `data/notes/Bullet Bill.hx`, whose `onNoteHit` sees both types; this file
// only keeps the type's own `preventAnim` backstop.
function onNoteHit(event) {
	if (event.noteType == "Bullet2") event.preventAnim();
}
