// 'Sacar Lava' is handled by the 'hatebg' stage script
// (data/stages/hatebg.hx -> onEvent -> mmSacarLava), which owns the ihyLava
// sprite. Nothing to do here.
//
// It used to be handled in this file, reading a PlayState field ("mmLava") that
// nothing ever created - `Reflect.field` throws "Invalid field" on cpp instead of
// returning null, and this engine hands stage sprites to the stage script rather
// than to PlayState, so the feature could never work from an event script.
