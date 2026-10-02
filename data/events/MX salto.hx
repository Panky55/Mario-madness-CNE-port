// 'MX salto' is handled by the 'exeport' stage script
// (data/stages/exeport.hx -> onEvent -> mmMxSalto), which owns the two MX face
// sprites (modstuff/cuidao and modstuff/cuidao0). Nothing to do here.
//
// It used to be handled in this file, reading PlayState fields ("mmImgWar" /
// "mmImgWarB") that nothing ever created - `Reflect.field` throws "Invalid field"
// on cpp instead of returning null, and this engine hands stage sprites to the
// stage script rather than to PlayState, so the jumpscare could never fire.
