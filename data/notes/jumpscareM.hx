// 'jumpscareM' - a hazard note that flashes a jumpscare image and plays the
// "CAUSA" scream. Ported from Mario's Madness (source/PlayState.hx), following
// the community Mario's Madness CNE port.
var jumpscareSound:FlxSound;
var jumpscareCam:HudCamera;
var jumpscareSprite:FunkinSprite;

function create() {
	FlxG.cameras.add(jumpscareCam = new HudCamera(), false);
	jumpscareCam.bgColor = 0;
	jumpscareSound = FlxG.sound.load(Paths.sound("CAUSA"));
	jumpscareSprite = new FunkinSprite(0, 0);
	jumpscareSprite.loadGraphic(Paths.image("mario/IHY/image"));
	jumpscareSprite.camera = jumpscareCam;
	jumpscareSprite.screenCenter();
	jumpscareSprite.alpha = 0;
	add(jumpscareSprite);
}

function onPlayerHit(event) {
	if (event.noteType != "jumpscareM") return;
	jumpscareSprite.alpha = 1;
	jumpscareSprite.scale.set(1, 1);
	FlxTween.tween(jumpscareSprite.scale, {x: 1.3, y: 1.3}, 0.2, {ease: FlxEase.expoOut});
	FlxTween.tween(jumpscareSprite, {alpha: 0}, 0.6, {startDelay: 0.2});
	jumpscareSound.play();
}
