-- Player join/leave. Owns ProfileStore sessions. Does not flip InRun after join defaults.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local AnalyticsService = game:GetService("AnalyticsService")

local ProfileStore = require(game:GetService("ServerScriptService"):WaitForChild("Packages"):WaitForChild("ProfileStore"))
local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local GameEvents = require(script.Parent:WaitForChild("GameEvents"))

local TEMPLATE = {
	Things = {},
	LastSession = "N/A",
	BestTimes = {}, -- [mazeId] = ms; HUD replica. ODS remains leaderboard truth.
}

local PlayerStore = ProfileStore.New(Constants.PROFILE_STORE_NAME, TEMPLATE)
if RunService:IsStudio() and workspace:GetAttribute("UseStudioDataStores") ~= true then
	PlayerStore = PlayerStore.Mock
end

export type PlayerProfile = typeof(PlayerStore:StartSessionAsync("0"))

local profiles: { [Player]: PlayerProfile } = {}
local diceLocked: { [Player]: { [string]: boolean } } = {}
local joinedLogged: { [Player]: boolean } = {}

local Session = {}

function Session.GetProfile(player: Player): PlayerProfile?
	return profiles[player]
end

function Session.GetBestTime(player: Player, mazeId: string): number?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local value = profile.Data.BestTimes[mazeId]
	if typeof(value) == "number" then
		return value
	end
	return nil
end

function Session.SetBestTime(player: Player, mazeId: string, elapsedMs: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Data.BestTimes[mazeId] = elapsedMs
end

function Session.UnlockDice(player: Player, mazeId: string)
	local locks = diceLocked[player]
	if locks then
		locks[mazeId] = nil
	end
end

function Session.SetDiceLocked(player: Player, mazeId: string, locked: boolean)
	local locks = diceLocked[player]
	if not locks then
		locks = {}
		diceLocked[player] = locks
	end
	locks[mazeId] = locked
end

function Session.IsDiceLocked(player: Player, mazeId: string): boolean
	local locks = diceLocked[player]
	return locks ~= nil and locks[mazeId] == true
end

local function applySpawnDefaults(character: Model)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	hum.WalkSpeed = Constants.WALK_SPEED
	hum.JumpPower = Constants.JUMP_POWER
	hum.UseJumpPower = true
end

local function applyInsaneDoorPolicy(player: Player, character: Model)
	local mon = script.Parent:FindFirstChild("Monetization")
	if not (mon and mon:IsA("ModuleScript")) then
		return
	end
	local ok, mod = pcall(require, mon)
	if ok and type(mod) == "table" and type(mod.ApplyInsaneDoorPolicy) == "function" then
		pcall(mod.ApplyInsaneDoorPolicy, player, character)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	applySpawnDefaults(character)
	local hum = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if hum and hum:IsA("Humanoid") then
		applySpawnDefaults(character)
		hum.Died:Connect(function()
			if player:GetAttribute("InRun") == true then
				GameEvents.PlayerDiedInRun:Fire(player, player:GetAttribute("MazeId"))
			end
		end)
	end
	applyInsaneDoorPolicy(player, character)

	if player:GetAttribute("InRun") == true then
		local mazeId = player:GetAttribute("MazeId")
		if typeof(mazeId) == "string" and mazeId ~= "" then
			task.defer(function()
				if player.Character ~= character or player:GetAttribute("InRun") ~= true then
					return
				end
				local WorldNav = require(script.Parent:WaitForChild("WorldNav"))
				WorldNav.TeleportToEntrance(player, mazeId)
				applySpawnDefaults(character)
			end)
		end
	end
end

local function logJoined(player: Player)
	if joinedLogged[player] then
		return
	end
	joinedLogged[player] = true
	pcall(function()
		AnalyticsService:LogCustomEvent(player, "Joined", 1)
	end)
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, 1, "Joined")
	end)
end

local function playerAdded(player: Player)
	local profile = PlayerStore:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		warn(`[MazeRunner.Session] profile load fail userId={player.UserId}`)
		player:Kick("Could not load data — please rejoin")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Profile session ended — please rejoin")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	diceLocked[player] = {}
	player:SetAttribute("InRun", false)
	player:SetAttribute("MazeId", "")
	player:SetAttribute("StartTime", 0)
	print(`[MazeRunner.Session] profile loaded userId={player.UserId}`)
	logJoined(player)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

function Session.Init()
	Players.PlayerAdded:Connect(playerAdded)
	Players.PlayerRemoving:Connect(function(player)
		if player:GetAttribute("InRun") == true then
			local MazeRun = require(script.Parent:WaitForChild("MazeRun"))
			MazeRun.Fail(player, "Leave")
		end
		local profile = profiles[player]
		if profile ~= nil then
			profile.Data.LastSession = DateTime.now():ToIsoDate()
			profile:EndSession()
			profiles[player] = nil
		end
		diceLocked[player] = nil
		joinedLogged[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(playerAdded, player)
	end
end

return Session
