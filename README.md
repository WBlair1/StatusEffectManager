# StatusEffectManager
Create status effects, track damage dealt/recieved, manage max lifetime of effects, and more with client-server architecture easily.

# Documentation

## Creating effects.
1. Create a folder in ServerStorage called "StatusEffects". This is for you to call with CharacterMap:AddEffect(). Make sure module instance names are fully unique (even different from folder names).
<details>
<summary>Example:</summary>

```luau
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

2. Copy the example above for your own effects! Status effects can really be placed anywhere, such as in a tool, as long as they are required. Premade effects are meant to given easy access to all scripts, which is why they're placed in ReplicatedStorage/StatusEffects **and can be added by name** (example `CharacterMap:AddEffect("Test")`)

## Methods
- init(): Initializes module and sets discriminators of all **global** status effects.
- **RegisterEffect**: *In your effect module*, adds effect discriminators and sets dummy functions for the typechecker.
- AddEffect(instanceName: string): Adds a (global) effect to a character by searching the effects folder for instances.
- RemoveEffect(effect: string): Removes an effect from a character. This finds the effect by "name" and not by it's actual table.
- AddLocalEffect(effect: EffectModule): Adds an effect to a character by the module itself. Useful if you want the same effect with different discriminators.
- GetEffectFromName(effect: string) -> EffectModule?: Finds an effect in character by the effect name.
- GetAllEffectFromDiscriminator(effect: EffectModule) -> {EffectModule}: Finds an exact effect type. All effects have unique discriminators. For example, if you had multiple types of effects named "Burn", this would return the exact one you're looking for.
- GetAllEffectFromName(effectName: string) -> {EffectModule}: Gets every effect in character by the effect name.
- WaitForEffect(effectName: string) -> EffectModule: Yields until effect is present.
- IsPartDescendentOfCharacter(part: BasePart) -> boolean: Detects if a part is a descendent of a character. Useful for projectiles, hitboxes, etc. Not useful for creating status effects really, but it has a use.
- new(character: Instance) -> CharacterMap: Creates a character map (aka. the constructor)
  - Classes:
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
  - GetClientMap() -> CharacterMapClient: Returns character map based on local player character instance.
Credit to sleitnick for the Signal module.
