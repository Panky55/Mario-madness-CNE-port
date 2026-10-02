// 'ycbu text' is handled by the 'nesbeat' stage script
// (data/stages/nesbeat.hx -> onEvent / onTrigger -> mmYcbuText), which owns
// everything the event touches: the gyromite / lakitu / head sprites and the two
// beat texts, all of which the source creates in that stage's own create block
// (PlayState.hx:2605-2760, case 'nesbeat'). Nothing to do here.
//
// This file used to draw a single screen-centred text of its own, which covered
// only the source's trigger2 == 0 branch - and with the wrong font, size, colour
// path and layering. The source writes `otherBeatText` when trigger2 is 1 (32 of
// Unbeatable's 550 uses) and `beatText` otherwise, flashes the copy orange and
// restores it 0.1s later, and drives the stage sprites for trigger2 1-5 (the
// 4 and 5 branches alone are 200 uses). All of that is in the stage script now,
// which is also where the source's own re-dispatches land (cases 25 and 26).
