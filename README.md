# StatusEffectManager
Create status effects, track damage dealt/recieved, manage max lifetime of effects, and more with client-server architecture easily.

# Documentation

## Creating effects.
1. Create a folder in ServerStorage called "StatusEffects". Add a folder in your status effect folder called "PremadeEffects". This is for you to call with CharacterMap:AddPremadeEffects(). 
<details>
<summary>Example:</summary>

```luau
--
local Status = require(game.ReplicatedStorage.Modules.StatusEffectManager)

local MyEffect = statusManager.RegisterEffect()
MyEffect.Name = "Test"

function MyEffect:OnStart(AnyVariablesPassed)
	print(self.Character) --WBlair
	self.Destroyed:Once(function()
		print("also ended")
	end)
	print(AnyVariablesPassed) --"Hello World"
	task.wait(30)
	print("never reaches here due to max lifetime - for memory leak cleanup reasons")
end

function MyEffect:OnStop()
	print("stopped")
end


return MyEffect
```
</details>

2. Copy the example above for your own effects! I recommend adding them in the StatusEffects folder (but not the PremadeEffects one).

## Methods
- init(): Initializes module and sets discriminators of all status effects.
- AddEffect(effect: EffectModule): Adds an effect to a character.
- RemoveEffect(effect: string): Removes an effect from a character. This finds the effect by "name" and not by it's actual table.
- AddPremadeEffect(effect: string): Adds an effect to a character by name. Finds in Premade Effects folder.
- GetEffectFromName(effect: string) -> EffectModule?: Finds an effect in character by the effect name.
- GetAllEffectFromDiscriminator(effect: EffectModule) -> {EffectModule}: Finds an exact effect type. All effects have unique discriminators. For example, if you had multiple types of effects named "Burn", this would return the exact one you're looking for.
- GetAllEffectFromName(effectName: string) -> {EffectModule}: Gets every effect in character by the effect name.
- WaitForEffect(effectName: string) -> EffectModule: Yields until effect is present.
- IsPartDescendentOfCharacter(part: BasePart) -> boolean: Detects if a part is a descendent of a character. Useful for projectiles, hitboxes, etc. Not useful for creating status effects really, but it has a use.
- new(character: Instance) -> CharacterMap: Creates a character map (aka. the constructor)
  - Classes:
    - **RegisterEffect** (do this first at the top of your effect module)
    - self.Character
	  - self.Player
	  - self.Effects
    -	self.LastDamage = {
    		Dealt,
    		Received
    	}
    -	self.LastKilled
    - self.InCombat
    -	self.InCombatTimerFunction
    -	self.CombatChanged
    -	self.EffectAdded
    -	self.EffectRemoved
    -	self.DamageReceivedChanged
    -	self.DamageDealtChanged
    -	self.LastKilledChanged
  - GetCharacterMap(character: Instance) -> CharacterMap: Returns a character map from a character instance.
  - GetAllCharacters(): Returns all character maps.
  - PartInCharacter(part: BasePart) -> Instance: Similar to IsPartDescendentOfCharacter, but it returns the character instance.
  - WaitForCharacter(character: Instance) -> CharacterMap: Yields until a character map of a character instance is present.
### Client Methods
  - newClient() -> CharacterMapClient: Returns a character map similar to the server character map, with a few revisions, such as not being able to interact with effects (AddEffect or RemoveEffect).
  - GetClientMap() -> CharacterMap: Returns character map based on local player character instance.
Credit to sleitnick for the Signal module.
