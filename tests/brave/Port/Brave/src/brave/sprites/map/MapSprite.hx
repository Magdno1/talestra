package brave.sprites.map;
import brave.Animation;
import brave.GameInput;
import brave.LangUtils;
import brave.map.Map;
import brave.MathEx;
import brave.SpriteUtils;
import haxe.Log;
import nme.display.BitmapData;
import nme.display.Sprite;
import nme.events.Event;
import nme.events.KeyboardEvent;
import nme.system.System;

/**
 * ...
 * @author 
 */

private class RowSprite {
	public var y:Int;
	public var sprite:Sprite;
	
	public function new(y:Int, sprite:Sprite) {
		this.y = y;
		this.sprite = sprite;
	}
}

class MapSprite extends Sprite
{
	public var map:Map;
	public var characters:IntHash<Character>;
	public var cameraX:Float = 0;
	public var cameraY:Float = 0;

	public var tilesWidth:Int = Std.int((640 / 40) + 2);
	public var tilesHeight:Int = Std.int((480 / 40) + 2 + 4);
	
	private var backgroundSprite:Sprite;
	private var foregroundSprite:Sprite;
	private var rowSprites:Array<RowSprite>;

	public function new() 
	{
		super();
		
		addChild(backgroundSprite = new Sprite());
		addChild(foregroundSprite = new Sprite());

		rowSprites = LangUtils.createArray(function() { return new RowSprite(0, new Sprite()); }, tilesHeight);

		this.characters = new IntHash<Character>();

		this.addEventListener(Event.ADDED_TO_STAGE, function(e:Event) {
			this.stage.addEventListener(Event.ENTER_FRAME, function(e:Event) {
				updateCamera();
			});
		});
	}
	
	public function addCharacter(character:Character):Void {
		this.characters.set(character.id, character);
		if (character.id == 0) {
			followCharacter(character);
		}
	}
	
	public function setMap(map:Map):Void {
		this.map = map;
		this.characters = new IntHash<Character>();
		updateCamera();
	}

	public function setCameraTo(destX:Float, destY:Float):Void {
		this.cameraX = destX;
		this.cameraY = destY;
	}

	public function moveCameraTo(destX:Float, destY:Float, time:Float, ?done:Void -> Void):Void {
		destX = MathEx.clamp(destX, 0, map.width * 40 - 640);
		destY = MathEx.clamp(destY, 0, map.height * 40 - 480);
		
		Animation.animate(done, time, this, { cameraX : destX, cameraY : destY }, Animation.Sin, function(step) {
			//BraveLog.trace(Std.format("step! $cameraX, $cameraY"));
			//updateCamera();
		});
	}
	
	private var followingCharacter:Character;
	
	public function followCharacter(character:Character):Void {
		this.followingCharacter = character;
	}
	
	public function enableMoveWithKeyboard():Void {
		var cameraVelX:Float = 0;
		var cameraVelY:Float = 0;
		
		var multiplier:Float = 60 / this.stage.frameRate;
		
		var inc:Float = 0.7 * (multiplier * multiplier);
		var mul:Float = 0.94 / Math.sqrt(Math.sqrt(multiplier));
		
		this.stage.addEventListener(Event.ENTER_FRAME, function(e:Event) {
			if (GameInput.isPressing(Keys.Left)) cameraVelX -= inc;
			if (GameInput.isPressing(Keys.Up)) cameraVelY -= inc;
			if (GameInput.isPressing(Keys.Right)) cameraVelX += inc;
			if (GameInput.isPressing(Keys.Down)) cameraVelY += inc;
			
			cameraX += cameraVelX;
			cameraY += cameraVelY;
			
			cameraVelX *= mul;
			cameraVelY *= mul;
		});
	}
	
	public function updateCamera():Void {
		if (map == null) return;
		if (!visible) return;
		
		if (followingCharacter != null) {
			var targetX = followingCharacter.x - 640 / 2;
			var targetY = followingCharacter.y - 480 / 2;
			
			cameraX = (cameraX + targetX) / 2;
			cameraY = (cameraY + targetY) / 2;
		}
		
		cameraX = MathEx.clamp(cameraX, 0, map.width * 40 - 640);
		cameraY = MathEx.clamp(cameraY, 0, map.height * 40 - 480 - 40);

		var miniDispX:Int = Std.int(cameraX) % 40;
		var miniDispY:Int = Std.int(cameraY) % 40;

		var tileX:Int = Std.int(cameraX / 40);
		var tileY:Int = Std.int(cameraY / 40);

		backgroundSprite.graphics.clear();
		this.map.drawLayerTo(backgroundSprite.graphics, 0, -miniDispX, -miniDispY, tileX, tileY, tilesWidth, tilesHeight);
		
		for (row in 0 ... tilesHeight) {
			rowSprites[row].y = (tileY + row) * 40;
			rowSprites[row].sprite.graphics.clear();
			this.map.drawLayerTo(rowSprites[row].sprite.graphics, 1, -miniDispX, -miniDispY + row * 40, tileX, tileY + row, tilesWidth, 1);
		}
		
		//System.gc();
		
		reorderEntities();
	}
	
	public function reorderEntities():Void {
		SpriteUtils.extractSpriteChilds(foregroundSprite);
		//for (row in 0...rowSprites.length) foregroundSprite.addChildAt(rowSprites[row], 0);
		
		var charactersSorted:Array<Character> = Lambda.array(characters);
		charactersSorted.sort(function(a:Character, b:Character):Int {
			return a.y - b.y;
		});
		
		for (row in 0...rowSprites.length) {
			var rowSprite = rowSprites[row];
			for (character in charactersSorted) {
				if ((character.y >= rowSprite.y - 40) && (character.y < rowSprite.y)) {
					var sprite:Sprite = character.sprite;
					sprite.x = character.x - cameraX;
					sprite.y = character.y - cameraY;
					character.updateSprite();
					foregroundSprite.addChild(sprite);
				}
			}
			foregroundSprite.addChild(rowSprite.sprite);
		}
	}
}