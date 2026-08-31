-- Only writer of InRun / MazeId / StartTime.

local BadgeService = game:GetService("BadgeService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnalyticsService = game:GetService("AnalyticsService")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local MazeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MazeConfig"))
local GameEvents = require(script.Parent:WaitForChild("GameEvents"))
local Session = require(script.Parent:WaitForChild("Session"))

local TAGS = Constants.TAGS

local lastStartAt: { [Player]: number } = {}
local firstStart: { [Player]: boolean } = {}
local firstComplete: { [Player]: boolean } = {}
local funnelSessionId: { [Player]: string } = {}
local bound: { [Instance]: boolean } = {}

local hudSync: RemoteEvent
local giveUp: RemoteEvent

local MazeRun = {}

local function playerFromHit(hit: BasePart): (Player?, Humanoid?)
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then
		return nil, nil
	end
	local player = Players:GetPlayerFromCharacter(model)
	if not player then
		return nil, nil
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	return player, hum
end

local function field(name: string): string
	return Enum.AnalyticsCustomFieldKeys[name].Name
end

local function ownsInsane(player: Player): boolean
	return player:GetAttribute("OwnsInsane") == true
end

local function bypassPasses(): boolean
	return workspace:GetAttribute("BypassPasses") == true
end

local function rowBlocked(player: Player, row): boolean
	return row.requiresPass == true and not bypassPasses() and not ownsInsane(player)
end

local function ensureRemote(folderName: string, remoteName: string, className: string): Instance
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		error("[MazeRunner.MazeRun] remotes folder absent")
	end
	local folder = remotes:FindFirstChild(folderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = remotes
	end
	local remote = folder:FindFirstChild(remoteName)
	if not remote then
		remote = Instance.new(className)
		remote.Name = remoteName
		remote.Parent = folder
	end
	return remote
end

local remotesReady = false

local function ensureRemotes()
	if remotesReady and hudSync and giveUp then
		return
	end
	hudSync = ensureRemote("MazeRun", "HudSync", "RemoteEvent") :: RemoteEvent
	giveUp = ensureRemote("MazeRun", "GiveUp", "RemoteEvent") :: RemoteEvent
	remotesReady = true
end

local function fireHudSync(player: Player, inRun: boolean, mazeId: string?, startTime: number?, personalBestMs: number?)
	ensureRemotes()
	hudSync:FireClient(player, {
		inRun = inRun,
		mazeId = mazeId,
		startTime = startTime,
		personalBestMs = personalBestMs,
	})
end

function MazeRun.GiveUp(player: Player)
	if player:GetAttribute("InRun") ~= true then
		return
	end
	MazeRun.Fail(player, "GiveUp")
	local WorldNav = require(script.Parent:WaitForChild("WorldNav"))
	WorldNav.TeleportToLobby(player)
end

local function clearRun(player: Player)
	player:SetAttribute("InRun", false)
	player:SetAttribute("MazeId", "")
	player:SetAttribute("StartTime", 0)
	funnelSessionId[player] = nil
end

local function trySaveBest(player: Player, mazeId: string, elapsedMs: number): boolean
	local mod = script.Parent:FindFirstChild("Leaderboards")
	if mod and mod:IsA("ModuleScript") then
		local ok, lb = pcall(require, mod)
		if ok and type(lb) == "table" and type(lb.TrySaveBestTime) == "function" then
			local savedOk, isNew = pcall(lb.TrySaveBestTime, player, mazeId, elapsedMs)
			if savedOk then
				return isNew == true
			end
		end
	end
	local current = Session.GetBestTime(player, mazeId)
	if current == nil or elapsedMs < current then
		Session.SetBestTime(player, mazeId, elapsedMs)
		return true
	end
	return false
end

function MazeRun.TryStart(player: Player, mazeId: string)
	local row = MazeConfig[mazeId]
	if not row or row.enabled == false then
		return
	end
	if player:GetAttribute("InRun") == true and player:GetAttribute("MazeId") == mazeId then
		return
	end
	if player:GetAttribute("InRun") ~= true then
		local last = lastStartAt[player]
		if last and workspace:GetServerTimeNow() - last < Constants.GATE_DEBOUNCE_SECONDS then
			return
		end
	end
	if rowBlocked(player, row) then
		return
	end
	if player:GetAttribute("InRun") == true and player:GetAttribute("MazeId") ~= mazeId then
		MazeRun.Fail(player, "Superseded")
	end

	local startTime = workspace:GetServerTimeNow()
	player:SetAttribute("InRun", true)
	player:SetAttribute("MazeId", mazeId)
	player:SetAttribute("StartTime", startTime)
	lastStartAt[player] = startTime
	Session.UnlockDice(player, mazeId)

	local pb = Session.GetBestTime(player, mazeId)
	fireHudSync(player, true, mazeId, startTime, pb)
	GameEvents.RunStarted:Fire(player, mazeId, startTime)
	print(`[MazeRunner.MazeRun] start {player.Name} {mazeId}`)

	pcall(function()
		AnalyticsService:LogCustomEvent(player, "RunStarted", 1, {
			[field("CustomField01")] = mazeId,
		})
	end)
	if not firstStart[player] then
		firstStart[player] = true
		pcall(function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, 2, "FirstRunStarted")
		end)
	end
	local fid = HttpService:GenerateGUID(false)
	funnelSessionId[player] = fid
	pcall(function()
		AnalyticsService:LogFunnelStepEvent(player, "MazeRun", fid, 1, "Start", {
			[field("CustomField01")] = mazeId,
		})
	end)
end

function MazeRun.Complete(player: Player, mazeId: string)
	if player:GetAttribute("InRun") ~= true or player:GetAttribute("MazeId") ~= mazeId then
		return
	end
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local row = MazeConfig[mazeId]
	if not row then
		warn(`[MazeRunner.MazeRun] maze config missing row at Complete {mazeId}`)
		return
	end
	if rowBlocked(player, row) then
		return
	end

	local startTime = player:GetAttribute("StartTime")
	if typeof(startTime) ~= "number" then
		startTime = workspace:GetServerTimeNow()
	end
	local elapsedMs = math.round((workspace:GetServerTimeNow() - startTime) * 1000)
	local fid = funnelSessionId[player]
	clearRun(player)

	if typeof(row.badgeId) ~= "number" then
		warn(`[MazeRunner.MazeRun] maze config missing badgeId at Complete {mazeId}`)
	elseif row.badgeId ~= 0 then
		pcall(function()
			BadgeService:AwardBadge(player.UserId, row.badgeId)
		end)
	end

	local isNewBest = trySaveBest(player, mazeId, elapsedMs)
	local pb = Session.GetBestTime(player, mazeId)
	GameEvents.RunCompleted:Fire(player, mazeId, elapsedMs, isNewBest)
	fireHudSync(player, false, nil, nil, pb)
	print(`[MazeRunner.MazeRun] complete {player.Name} {mazeId} {elapsedMs}ms newBest={isNewBest}`)

	pcall(function()
		AnalyticsService:LogCustomEvent(player, "RunCompleted", elapsedMs, {
			[field("CustomField01")] = mazeId,
			[field("CustomField02")] = if isNewBest then "true" else "false",
		})
	end)
	if not firstComplete[player] then
		firstComplete[player] = true
		pcall(function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, 3, "FirstRunCompleted")
		end)
	end
	if fid then
		pcall(function()
			AnalyticsService:LogFunnelStepEvent(player, "MazeRun", fid, 2, "Complete", {
				[field("CustomField01")] = mazeId,
			})
		end)
	end
end

function MazeRun.Fail(player: Player, reason: string)
	if player:GetAttribute("InRun") ~= true then
		return
	end
	local mazeId = player:GetAttribute("MazeId")
	if typeof(mazeId) ~= "string" then
		mazeId = ""
	end
	local pb = Session.GetBestTime(player, mazeId)
	clearRun(player)
	GameEvents.RunFailed:Fire(player, mazeId, reason)
	fireHudSync(player, false, nil, nil, pb)
	print(`[MazeRunner.MazeRun] fail {player.Name} {mazeId} {reason}`)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, "RunFailed", 1, {
			[field("CustomField01")] = mazeId,
			[field("CustomField02")] = reason,
		})
	end)
end

local function onGate(part: Instance)
	if bound[part] or not part:IsA("BasePart") then
		return
	end
	bound[part] = true
	part.Touched:Connect(function(hit)
		if not hit:IsA("BasePart") then
			return
		end
		local player, hum = playerFromHit(hit)
		if not player or not hum or hum.Health <= 0 then
			return
		end
		local mazeId = part:GetAttribute("MazeId")
		if typeof(mazeId) == "string" and mazeId ~= "" then
			MazeRun.TryStart(player, mazeId)
		end
	end)
end

local function onExit(part: Instance)
	if bound[part] or not part:IsA("BasePart") then
		return
	end
	bound[part] = true
	part.Touched:Connect(function(hit)
		if not hit:IsA("BasePart") then
			return
		end
		local player = playerFromHit(hit)
		if not player then
			return
		end
		local mazeId = part:GetAttribute("MazeId")
		if typeof(mazeId) == "string" and mazeId ~= "" then
			MazeRun.Complete(player, mazeId)
		end
	end)
end

local function onSecret(part: Instance)
	if bound[part] or not part:IsA("BasePart") then
		return
	end
	bound[part] = true
	part.Touched:Connect(function(hit)
		if not hit:IsA("BasePart") then
			return
		end
		local player = playerFromHit(hit)
		if not player then
			return
		end
		local badgeId = part:GetAttribute("BadgeId")
		if typeof(badgeId) == "number" and badgeId ~= 0 then
			pcall(function()
				BadgeService:AwardBadge(player.UserId, badgeId)
			end)
		end
	end)
end

function MazeRun.Init()
	ensureRemotes()
	giveUp.OnServerEvent:Connect(function(player)
		MazeRun.GiveUp(player)
	end)

	for _, inst in CollectionService:GetTagged(TAGS.MazeGate) do
		onGate(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAGS.MazeGate):Connect(onGate)

	for _, inst in CollectionService:GetTagged(TAGS.MazeExit) do
		onExit(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAGS.MazeExit):Connect(onExit)

	for _, inst in CollectionService:GetTagged(TAGS.Secret) do
		onSecret(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAGS.Secret):Connect(onSecret)

	Players.PlayerRemoving:Connect(function(player)
		lastStartAt[player] = nil
		firstStart[player] = nil
		firstComplete[player] = nil
		funnelSessionId[player] = nil
	end)
end

return MazeRun
