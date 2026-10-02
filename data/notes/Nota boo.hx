// 'Nota boo' - in Mario's Madness this note type only swaps the note's skin
// (source/Note.hx: reloadNote('boo')); it has no gameplay behaviour of its own.
// Kept as a documented no-op so the note type exists in the port.
function onNoteHit(event) {
	if (event.noteType != "Nota boo") return;
	// No custom behaviour in the source.
}
