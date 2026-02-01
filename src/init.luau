local Settings={}

Settings.EffectsFolder = 
	game:GetService("ServerStorage"):FindFirstChild("StatusEffects")

Settings.CombatTime=10

Settings.MaxLifetime=30


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

type Character = Model & {
	Humanoid: Humanoid?,
	PrimaryPart: BasePart?
}

export type EffectModule = { 
	Name: string?,
	OnStart: (EffectModule, ...any) -> (),
	OnStop: (EffectModule) -> (),
	Destroy: (EffectModule) -> (),
	Destroyed: Signal.Signal<>,
	Character: Character,
	Discriminator: number,
}

export type CharacterMap = {
	Effects: {EffectModule},
	LastDamage: {Dealt: number, Received: number},
	LastKilled: CharacterMap,
	InCombat: boolean,
	InCombatTimerFunction: thread?, 
	Player: Player?,
	Character: Character,
	CombatChanged: Signal.Signal<boolean>,
	EffectAdded: Signal.Signal<EffectModule>,
	EffectRemoved: Signal.Signal<EffectModule>, 
	DamageReceivedChanged: Signal.Signal<CharacterMap, number>,
	DamageDealtChanged: Signal.Signal<CharacterMap, number>,
	LastKilledChanged: Signal.Signal<CharacterMap>,

	AddLocalEffect: (self: CharacterMap, effect: EffectModule, ...any) -> (),
	RemoveEffect: (self: CharacterMap, effectName: string) -> (),
	AddEffect: (self: CharacterMap, instanceName: string, ...any) -> (),
	GetEffectFromName: (self: CharacterMap, effectName: string) -> EffectModule?,
	GetAllEffectFromDiscriminator: (self: CharacterMap, effect: EffectModule) -> {EffectModule},
	GetAllEffectFromName: (self: CharacterMap, effectName: string) -> {EffectModule},
	WaitForEffect: (self: CharacterMap, effectName: string) -> EffectModule,
	IsPartDescendentOfCharacter: (self: CharacterMap, part: BasePart) -> boolean
}

type CharacterMapClient = {
	Effects: {EffectModule},
	LastDamage: {Dealt: number, Received: number},
	LastKilled: Instance?,
	InCombat: boolean,
	Player: Player?,
	Character: Character,
	CombatChanged: Signal.Signal<boolean>,
	EffectAdded: Signal.Signal<EffectModule>,
	EffectRemoved: Signal.Signal<EffectModule>,
	DamageReceivedChanged: Signal.Signal<Instance, number>,
	DamageDealtChanged: Signal.Signal<Instance, number>,
	LastKilledChanged: Signal.Signal<Instance>,
}

local StatusEffectManager = {}
StatusEffectManager.__index = StatusEffectManager

local characterMaps: {[Instance]: CharacterMap} = {}

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
		Destroyed = nil,
		Character = nil :: any,
		Discriminator = Random.new():NextNumber()
	}
end

function StatusEffectManager.init(): ()
	script.Initializer.Disabled = false
end



function StatusEffectManager:AddLocalEffect(effect: EffectModule, ...): ()
	assert(effect ~= nil, "Effect must not be nil")
	local newEffect = table.clone(effect)
	self:_startEffect(newEffect, ...)
end

function StatusEffectManager:RemoveEffect(effectName: string): ()
	assert(type(effectName) == "string", "effectName must be a string")
	local effect: EffectModule? = self:GetEffectFromName(effectName)
	if effect then
		if effect.Destroy then
			effect:Destroy()
		else
			warn("Cannot destroy effect:",effectName)
		end
	end
end

function StatusEffectManager:AddEffect(instanceName: string, ...): ()
	assert(type(instanceName) == "string", "instanceName must be a string")

	if Settings.EffectsFolder then
		local findModule = Settings.EffectsFolder:FindFirstChild(instanceName, true)
		if findModule and findModule:IsA("ModuleScript") then
			local success, requireEffect = pcall(require, findModule)
			if success and typeof(requireEffect) == "table" then
				local newEffect: EffectModule = table.clone(requireEffect)
				newEffect.Character = self.Character
				self:_startEffect(newEffect, ...)
			else
				warn("Failed to require or invalid type for premade effect module: " .. instanceName)
			end
		else
			warn("Couldn't find effect module:",instanceName)
		end
	else
		warn("Generic effects folder not found.")
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
	while not effect do
		task.wait()
		effect = self:GetEffectFromName(effectName)
	end
	return effect :: EffectModule
end

function StatusEffectManager:IsPartDescendentOfCharacter(part: BasePart): boolean
	return self.Character ~= nil and part:IsDescendantOf(self.Character)
end

function StatusEffectManager:_startEffect(effect: EffectModule, ...): ()
	assert(effect ~= nil, "Effect must not be nil")
	effect.Destroyed = Signal.new()
	table.insert(self.Effects, effect)
	self.EffectAdded:Fire(effect)

	if self.Player then
		ToClient:FireClient(self.Player, effect, "EffectAdded")
		local CharacterRemoved = self.Player.CharacterRemoving:Once(function()
			effect:Destroy()
		end)
		effect.Destroyed:Once(function()
			CharacterRemoved:Disconnect()
			ToClient:FireClient(self.Player, effect, "EffectRemoved")
		end)
	end

	function effect:Destroy()
		effect.Destroyed:Fire()
	end

	local thread = task.spawn(effect.OnStart, effect, ...)

	local event: RBXScriptConnection? = nil
	local destroyed = false

	local function cleanup()
		if destroyed then return end
		destroyed = true
		if effect.OnStop then
			effect:OnStop(effect)
		end
		if event then event:Disconnect() end

		local effectpos = table.find(self.Effects, effect)
		if effectpos then
			table.remove(self.Effects, effectpos)
		end

		if coroutine.status(thread) ~= "dead" then
			task.wait()
			task.cancel(thread)
			effect.Destroyed:DisconnectAll()
			if effect.Destroyed.Destroy then
				effect.Destroyed:Destroy()
			end
		end

		self.EffectRemoved:Fire(effect)

	end

	local LifecycleThread = task.delay(Settings.MaxLifetime, cleanup)

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

	self.Character = character :: Character 
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
		if self.CombatChanged then
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
			self.InCombatTimerFunction = task.delay(Settings.CombatTime, function()
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
	local character = game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()

	self.Character = character :: Character
	self.Player = Players.LocalPlayer
	self.Effects = {}
	self.LastDamage = { Dealt = 0, Received = 0 }
	self.LastKilled = nil
	self.InCombat = false

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
		characterMaps[character] = nil
	end

	self.EffectAdded:Connect(function(EffectName: string)
		table.insert(self.Effects, EffectName)
	end)

	self.EffectRemoved:Connect(function(EffectName: string)
		local index = table.find(self.Effects, EffectName)
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
				self.DamageDealtChanged:Fire(data[1], data[2])
			elseif ChangeType == "DamageReceived" then
				self.LastDamage.Received = data[2]
				self.DamageReceivedChanged:Fire(data[1], data[2])
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

function StatusEffectManager.GetCharacterMap(character: Instance): CharacterMap
	return characterMaps[character]
end

function StatusEffectManager.GetClientMap(): CharacterMapClient?
	local char = game.Players.LocalPlayer.Character
	if char then
		return characterMaps[char] :: CharacterMapClient?
	end
	return nil
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
