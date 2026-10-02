// 'Nota veneno' (poison note) - hitting it stacks a health drain that ticks
// down over time. Ported from Mario's Madness (source/PlayState.hx:
// healthDrain += 0.0020; timerDrain = 2). The Codename implementation mirrors
// the community Mario's Madness CNE port.
var poisonTime:Float = 0;

function update(elapsed:Float) {
	if (poisonTime > 0) {
		poisonTime -= elapsed;
		health -= (elapsed * Math.floor(poisonTime + 1) / 3);
	}
}

function onPlayerHit(event) {
	if (event.noteType != "Nota veneno") return;
	if (poisonTime < 0) poisonTime = 0;
	poisonTime++;
	event.cancel();
}

function onPlayerMiss(event) {
	if (event.noteType == "Nota veneno")
		event.cancel();
}
