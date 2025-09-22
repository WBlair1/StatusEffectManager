# StatusEffectManager
Create status effects, track damage dealt/recieved, manage max lifetime of effects, and more with client-server architecture easily.

# Documentation

## Creating effects.
1. Create a folder in ServerStorage called "StatusEffects". Add a folder in your status effect folder called "PremadeEffects". This is for you to call with CharacterMap:AddPremadeEffects(). 
<details>
<summary>Example:</summary>

```luau
-- The client sided functionality of status effects uses refX. It's not native to the module, unfortunately.
local statusManager = require(game.ReplicatedStorage.Modules.StatusEffectManager)
type Effect=statusManager.EffectModule
local EffectFolder = game.ReplicatedStorage.VFX
local VFX = require(EffectFolder.Base)

function killeffect(char,dmg)
	local function burn()
		local humdesc = char.Humanoid:GetAppliedDescription() 
		humdesc.Shirt = 0
		humdesc.Pants = 0
		humdesc.HeadColor = Color3.fromRGB(0, 0, 0)
		humdesc.TorsoColor = Color3.fromRGB(0, 0, 0)
		humdesc.RightArmColor = Color3.fromRGB(0, 0, 0)
		humdesc.LeftArmColor = Color3.fromRGB(0, 0, 0)
		humdesc.RightLegColor = Color3.fromRGB(0, 0, 0)
		humdesc.LeftLegColor = Color3.fromRGB(0, 0, 0)
		char.Humanoid:ApplyDescription(humdesc)
		for _,part in pairs(char:GetDescendants()) do
			if part:IsA("Shirt") then
				part:Destroy()
			end
			if part:IsA("Pants") then
				part:Destroy()
			end
			if part:IsA("Accessory") then
				part:Destroy()
			end
			if part:IsA("BasePart") then
				part.Color = Color3.fromRGB(0,0,0)
				part.Material = Enum.Material.Plastic
			end
		end
	end

	if char:HasTag("Dead") then
		burn()
	end
	if not char.Humanoid then return end
	if char.Humanoid.Health - dmg > 0 then return end
	char.Humanoid.Health =- dmg
	task.wait()
	if char.Humanoid.Health > 0 then return end

	burn()
end

local MyEffect:Effect = statusManager.RegisterEffect()
MyEffect.Name = "Burn"

function MyEffect:OnStart()
	self.Character:AddTag("Burning")
	VFX.new(self.Character,"Burn","BurnEntity"):Start(game.Players:GetPlayers())
	local scorchsfx = Instance.new("Sound",self.Character.PrimaryPart)
	scorchsfx.SoundId = "rbxassetid://3518167306"
	scorchsfx.Volume = .65
	scorchsfx:Play()
	game.Debris:AddItem(scorchsfx,scorchsfx.TimeLength+2)
	for i=1,60 do
		self.Character.Humanoid:TakeDamage(.5)
		killeffect(self.Character,.5)
		if self.Character.Humanoid:GetState() == Enum.HumanoidStateType.Swimming then
			self:Destroy()
		end
		task.wait(.2)
	end
	self.Destroyed:Once(function()
		scorchsfx:Destroy()
	end)
end

function MyEffect:OnStop()
	self.Character:RemoveTag("Burning")
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
