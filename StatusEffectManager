local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Signal = require(script.Signal)

local function findInTableByName(tbl: {any}, name: string): any?
	for _, value in tbl do
		if type(value) == "table" and value.Name == name then
			return value
		end
	end
	return nil
end

-- Define types
type Character = Model & {
	PrimaryPart:BasePart & {
		RootAttachment:Attachment,
	},
	Humanoid:Humanoid & {
		Animator:Animator,
	},
	Ragdoll:BoolValue
}
export type EffectModule = { 
	Name: string?,
	OnStart: (EffectModule)->(),
	OnStop: (EffectModule)->(),
	Destroy: (EffectModule)->(),
	Destroyed: Signal.Signal<>,
	Character: Character,
	Discriminator: number,
}
export type CharacterMap = {
	Effects: {EffectModule},
	LastDamage: {Dealt: number, Received: number},
	LastKilled: CharacterMap?,
	InCombat: boolean,
	InCombatTimerFunction: thread?, 
	Player: Player?,
	Character: Character,
	CombatChanged: Signal.Signal<boolean>,
	EffectAdded: Signal.Signal<EffectModule>,
	EffectRemoved: Signal.Signal<EffectModule>, 
	DamageReceivedChanged: Signal.Signal<CharacterMap,number>,
	DamageDealtChanged: (Signal.Signal<CharacterMap,number>),
	LastKilledChanged: Signal.Signal<CharacterMap>,

	AddEffect: (self: CharacterMap, effect: EffectModule) -> (),
	RemoveEffect: (self: CharacterMap, effectName: string) -> (),
	AddPremadeEffect: (self: CharacterMap, effectName: string) -> (),
	GetEffectFromName: (self: CharacterMap, effectName: string) -> EffectModule?,
	GetAllEffectFromDiscriminator: (self: CharacterMap, effect: EffectModule) -> {EffectModule},
	GetAllEffectFromName: (self: CharacterMap, effectName: string) -> {EffectModule},
	WaitForEffect: (self: CharacterMap, effectName: string) -> EffectModule,
	IsPartDescendentOfCharacter: (self: CharacterMap, part: BasePart) -> boolean
}

type CharacterMapClient = {
	Effects: {EffectModule},
	LastDamage: {Dealt: number, Received: number},
	LastKilled: CharacterMap?,
	InCombat: boolean,
	InCombatTimerFunction: thread?, 
	Player: Player?,
	Character: Instance,
	CombatChanged: Signal.Signal<boolean>,
	EffectAdded: Signal.Signal<EffectModule>,
	EffectRemoved: Signal.Signal<string>, 
	DamageReceivedChanged: Signal.Signal<{Character&number}>,
	DamageDealtChanged: Signal.Signal<{Character&number}>,
	LastKilledChanged: Signal.Signal<Character>,
}

local StatusEffectManager = {}
StatusEffectManager.__index = StatusEffectManager



local characterMaps: {[Instance]: CharacterMap} = {}
-- Correctly typed function that matches the signal's parameters

local ToClient: RemoteEvent
if RunService:IsServer() then
	ToClient = Instance.new("RemoteEvent")
	ToClient.Name = "ToClient"
	ToClient.Parent = script
else
	ToClient = script:WaitForChild("ToClient", 5) :: RemoteEvent
end
function StatusEffectManager.RegisterEffect(): EffectModule
	return {
		Name = "",
		OnStart = function() end,
		OnStop = function() end,
		Destroy = function() end,
		Destroyed = Signal.new(),
		Character = nil,
		Discriminator = 0
	}
end

function StatusEffectManager.init(): ()
	if RunService:IsServer() then
		local StatusEffectsFolder = game:GetService("ServerStorage"):FindFirstChild("StatusEffects")
		if StatusEffectsFolder then
			for _, v in StatusEffectsFolder:GetDescendants() do
				if v:IsA("ModuleScript") then
					local success, z = pcall(require, v)
					if success and typeof(z) == "table" then
						z.Discriminator = Random.new():NextNumber(-1000, 1000)
					end
				end
			end
		end
	end
end



local CombatTime = 10

function StatusEffectManager:AddEffect(effect: EffectModule): ()
	assert(effect ~= nil, "Effect must not be nil")
	local newEffect = table.clone(effect)
	for k,v in effect do
		newEffect[k] = v
	end
	self:_startEffect(newEffect)
end

function StatusEffectManager:RemoveEffect(effectName: string): ()
	assert(type(effectName) == "string", "effectName must be a string")
	local effect: EffectModule? = self:GetEffectFromName(effectName)
	if effect then
		-- Always call Destroy, which will fire Destroyed and trigger cleanup
		if effect.Destroy then
			effect:Destroy()
		end
	end
end

function StatusEffectManager:AddPremadeEffect(effectName: string): ()
	assert(type(effectName) == "string", "effectName must be a string")
	local PremadeEffectsFolder = game:GetService("ServerStorage"):FindFirstChild("StatusEffects")
		and game:GetService("ServerStorage"):FindFirstChild("StatusEffects"):FindFirstChild("PremadeEffects")
	if PremadeEffectsFolder then
		local findModule = PremadeEffectsFolder:FindFirstChild(effectName)
		if findModule and findModule:IsA("ModuleScript") then
			local success, requireEffect = pcall(require, findModule)
			if success and typeof(requireEffect) == "table" then
				local newEffect: EffectModule = table.clone(requireEffect)
				newEffect.Character = self.Character
				self:_startEffect(newEffect)
			else
				warn("Failed to require or invalid type for premade effect module: " .. effectName)
			end
		else
			warn("Couldn't find premade effect module: " .. effectName)
		end
	else
		warn("PremadeEffects folder not found.")
	end
end

function StatusEffectManager:GetEffectFromName(effectName: string): EffectModule?
	assert(type(effectName) == "string", "effectName must be a string")
	return findInTableByName(self.Effects, effectName)
end

function StatusEffectManager:GetAllEffectFromDiscriminator(effect: EffectModule): {EffectModule}
	assert(effect ~= nil, "effect must not be nil")
	local effects: {EffectModule} = {}
	for _, v in self.Effects do
		if v.Discriminator == effect.Discriminator then
			table.insert(effects, v)
		end
	end
	return effects
end

function StatusEffectManager:GetAllEffectFromName(effectName: string): {EffectModule}
	assert(type(effectName) == "string", "effectName must be a string")
	local effects: {EffectModule} = {}
	for _, v in self.Effects do
		if v.Name == effectName then
			table.insert(effects, v)
		end
	end
	return effects
end

function StatusEffectManager:WaitForEffect(effectName: string): EffectModule
	assert(type(effectName) == "string", "effectName must be a string")
	local effect = self:GetEffectFromName(effectName)
	repeat
		task.wait()
		effect = self:GetEffectFromName(effectName)
	until effect
	return effect
end

function StatusEffectManager:IsPartDescendentOfCharacter(part: BasePart): boolean
	return self.Character ~= nil and part:IsDescendantOf(self.Character)
end

-- Internal: Start and manage an effect's lifecycle
function StatusEffectManager:_startEffect(effect: EffectModule): ()
	local MaxLifecycle = 30
	
	assert(effect ~= nil, "Effect must not be nil")
	effect.Character = self.Character
	effect.Destroyed = Signal.new()
	-- Insert into Effects table immediately so it is always up to date
	table.insert(self.Effects, effect)
	self.EffectAdded:Fire(effect)
	if self.Player then
		ToClient:FireClient(self.Player, effect, "EffectAdded")
		local CharacterRemoved = self.Player.CharacterRemoving:Once(function()
			effect:Destroy()
		end)
		effect.Destroyed:Once(function()
			CharacterRemoved:Disconnect()
		end)
	end
	function effect:Destroy()
		effect.Destroyed:Fire()
	end
	
	local thread = task.defer(effect.OnStart,effect) --coroutine.create(effect.OnStart)
	--coroutine.resume(thread, effect)
	
	local event: RBXScriptConnection? = nil
	local destroyed = false

	local function cleanup()
		if destroyed then return end
		destroyed = true
		if effect.OnStop then
			effect:OnStop()
		end
		if event then event:Disconnect() end

		local effectpos = table.find(self.Effects, effect)
		if effectpos then
			table.remove(self.Effects, effectpos)
		end

		if coroutine.status(thread) ~= "dead" then
			--in case somehow it still exists...
			task.wait()
			task.cancel(thread)
		end

		self.EffectRemoved:Fire(effect)
		if self.Player then
			ToClient:FireClient(self.Player, effect.Name, "EffectRemoved")
		end
	end
	
	local LifecycleThread = task.delay(MaxLifecycle, cleanup)
	-- Ensure cleanup is only done once, whether Destroyed is fired manually or by thread dying
	effect.Destroyed:Once(cleanup)
	effect.Destroyed:Once(function()
		task.cancel(LifecycleThread)
	end)
	event = RunService.PostSimulation:Connect(function()
		if coroutine.status(thread) == "dead" then
			effect.Destroyed:Fire()
		end
	end)


end

function StatusEffectManager.new(character: Instance): CharacterMap
	assert(not characterMaps[character], "CharacterMap already found for " .. character.Name .. "!")
	local self = {} :: CharacterMap
	self.Character = character
	self.Player = Players:GetPlayerFromCharacter(character)
	self.Effects = {}
	self.LastDamage = {
		Dealt = 0,
		Received = 0
	}
	self.LastKilled = nil
	self.InCombat = false
	self.InCombatTimerFunction = nil
	self.CombatChanged = Signal.new()
	self.EffectAdded = Signal.new()
	self.EffectRemoved = Signal.new()
	self.DamageReceivedChanged = Signal.new()
	self.DamageDealtChanged = Signal.new()
	self.LastKilledChanged = Signal.new()
	local function TimerCombatFinished(): ()
		if self.CombatChanged:GetConnections() and #self.CombatChanged:GetConnections() > 0 then
			self.CombatChanged:Fire(false)
			if self.Player then
				ToClient:FireClient(self.Player, false, "Combat")
			end
		end
	end

	self.LastKilledChanged:Connect(function(enemy: CharacterMap)
		self.LastKilled = enemy
		if self.Player then
			ToClient:FireClient(self.Player, enemy.Character, "LastKilled")
		end
	end)

	self.CombatChanged:Connect(function(InCombat: boolean)
		if InCombat then
			if self.Player then
				ToClient:FireClient(self.Player, true, "Combat")
			end
			if self.InCombatTimerFunction then
				task.cancel(self.InCombatTimerFunction)
			end
			self.InCombatTimerFunction = task.delay(CombatTime, function()
				TimerCombatFinished()
			end)
		end
		self.InCombat = InCombat
	end)

	self.DamageDealtChanged:Connect(function(enemy: CharacterMap, damage: number)
		self.LastDamage.Dealt = damage
		if self.Player then
			ToClient:FireClient(self.Player, {enemy.Character, damage}, "DamageDealt")
		end
	end)

	self.DamageReceivedChanged:Connect(function(enemy: CharacterMap, damage: number)
		self.LastDamage.Received = damage
		if self.Player then
			ToClient:FireClient(self.Player, {enemy.Character, damage}, "DamageReceived")
		end
	end)

	local signalsToClean = {
		self.DamageReceivedChanged,
		self.DamageDealtChanged,
		self.EffectAdded,
		self.EffectRemoved,
		self.CombatChanged,
		self.LastKilledChanged
	}

	characterMaps[character] = self

	local function RemoveSignals(): ()
		for _, v in signalsToClean do
			if v and v.Destroy then
				v:Destroy()
			end
		end
		table.clear(characterMaps[character])
		characterMaps[character] = nil
	end

	character.Destroying:Once(RemoveSignals)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Once(function()
			if self.InCombatTimerFunction then
				task.cancel(self.InCombatTimerFunction)
				self.InCombatTimerFunction = nil
			end
			if self.CombatChanged and self.CombatChanged.DisconnectAll then
				self.CombatChanged:DisconnectAll()
			end
		end)
	end

	if self.Player then
		self.Player.CharacterRemoving:Once(RemoveSignals)
	end

	return setmetatable(self, StatusEffectManager)
end

function StatusEffectManager.newClient(): CharacterMapClient
	local self = {} :: CharacterMapClient
	local character = game.Players.LocalPlayer.Character
	self.Character = character
	self.Player = Players.LocalPlayer
	self.Effects = {}
	self.LastDamage = { Dealt = 0, Received = 0 }
	self.LastKilled = nil
	self.InCombat = false
	self.InCombatTimerFunction = nil

	self.CombatChanged = Signal.new()
	self.EffectAdded = Signal.new()
	self.EffectRemoved = Signal.new()
	self.DamageReceivedChanged = Signal.new()
	self.DamageDealtChanged = Signal.new()
	self.LastKilledChanged = Signal.new()

	local signalsToClean = {
		self.EffectAdded,
		self.EffectRemoved,
		self.CombatChanged,
		self.DamageReceivedChanged,
		self.DamageDealtChanged,
		self.LastKilledChanged
	}

	local function RemoveSignals(): ()
		for _, v in signalsToClean do
			if v and v.Destroy then
				v:Destroy()
			end
		end
		table.clear(characterMaps[character])
		characterMaps[character] = nil
	end

	self.EffectAdded:Connect(function(Effect: EffectModule)
		table.insert(self.Effects, Effect)
	end)
	self.EffectRemoved:Connect(function(Effect: EffectModule)
		local index = table.find(self.Effects, Effect)
		if index then
			table.remove(self.Effects, index)
		end
	end)

	local toClientConnection: RBXScriptConnection? = nil
	if ToClient then
		toClientConnection = ToClient.OnClientEvent:Connect(function(data: any, ChangeType: string)
			if ChangeType == "EffectAdded" then
				self.EffectAdded:Fire(data)
			elseif ChangeType == "EffectRemoved" then
				self.EffectRemoved:Fire(data)
			elseif ChangeType == "Combat" and typeof(data) == "boolean" then
				self.InCombat = data
				self.CombatChanged:Fire(data)
			elseif ChangeType == "DamageDealt" then
				self.LastDamage.Dealt = data[2]
				self.DamageDealtChanged:Fire(data)
			elseif ChangeType == "DamageReceived" then
				self.LastDamage.Received = data[2]
				self.DamageReceivedChanged:Fire(data)
			elseif ChangeType == "LastKilled" and typeof(data) == "Instance" then
				self.LastKilled = data
				self.LastKilledChanged:Fire(data)
			end
		end)
	end

	local instance = setmetatable(self, StatusEffectManager)
	characterMaps[character] = instance

	if self.Player and self.Player == Players.LocalPlayer then
		self.Player.CharacterRemoving:Once(function()
			RemoveSignals()
			if toClientConnection then
				toClientConnection:Disconnect()
			end
		end)
	else
		character.Destroying:Once(function()
			RemoveSignals()
			if toClientConnection then
				toClientConnection:Disconnect()
			end
		end)
	end

	return instance
end

function StatusEffectManager.GetCharacterMap(character: Instance): CharacterMap?
	return characterMaps[character]
end

function StatusEffectManager.GetClientMap(): CharacterMap?
	return characterMaps[game.Players.LocalPlayer.Character]
end
function StatusEffectManager.GetAllCharacters(): {CharacterMap}
	local characterTable: {CharacterMap} = {}
	for _, v in characterMaps do
		table.insert(characterTable, v)
	end
	return characterTable
end

function StatusEffectManager.PartInCharacter(part: BasePart): Instance?
	for _, v in characterMaps do
		local character = v.Character
		if character and part:IsDescendantOf(character) then
			return character
		end
	end
	return nil
end

function StatusEffectManager.WaitForCharacter(character: Instance): CharacterMap
	while not characterMaps[character] do
		RunService.Heartbeat:Wait()
	end
	return characterMaps[character]
end

return StatusEffectManager

