// BF Run v2 (Apparition's player, source assets/preload/characters/bfrunv2.lua).
//
// The lua's `onUpdatePost` kept this character's idle animation frame in sync
// with the "bftors" back-legs sprite:
//
//     if boyfriend.animation.curAnim.name == 'idle' then
//         boyfriend.animation.frameIndex = bftors.animation.frameIndex
//
// That sprite belongs to the 'warioworld' stage, and this engine gives stage
// sprites to the stage script (not to PlayState, which is where the lua read it
// from), so the sync lives in data/stages/warioworld.hx -> postUpdate together
// with the source's bftors/bftorsmiss visibility toggle. Nothing to do here.
