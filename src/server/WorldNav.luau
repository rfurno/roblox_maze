-- Lobby portals, fall volumes, entrance / pad teleports. Does not flip InRun.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))

local TAGS = Constants.TAGS
local FALL_DEBOUNCE = 0.4

local lastFallAt: { [Player]: number } = {}
local lastPortalAt: { [Player]: number } = {}
local bound: { [Instance]: boolean } = {}

local WorldNav = {}

local function playerFromHit(hit: BasePart): (Player?, Model?)
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then
		return nil, nil
	end
	local player = Players:GetPlayerFromCharacter(model)
	if not player then
		return nil, nil
	end
	return player, model
end

local function findTagged(tag: string, mazeId: string, padId: string?): BasePart?
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA("BasePart") and inst:GetAttribute("MazeId") == mazeId then
			if padId == nil or inst:GetAttribute("PadId") == padId then
				return inst
			end
		end
	end
	return nil
end

function WorldNav.TeleportToLobby(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation")
	local cf = if spawn then spawn:GetPivot() * CFrame.new(0, 3, 0) else CFrame.new(0, 5, 0)
	character:PivotTo(cf)
end

function WorldNav.TeleportToEntrance(player: Player, mazeId: string)
	local character = player.Character
	if not character then
		return
	end
	if not character.PrimaryPart then
		character:WaitForChild("HumanoidRootPart", 5)
	end
	if player.Character ~= character then
		return
	end
	local pad = findTagged(TAGS.EntrancePad, mazeId)
	if not pad then
		warn(`[MazeRunner.WorldNav] no EntrancePad for {mazeId}`)
		return
	end
	character:PivotTo(pad:GetPivot() * CFrame.new(0, Constants.ENTRANCE_PAD_Y_OFFSET, 0))
end

function WorldNav.TeleportToPad(player: Player, mazeId: string, padId: string)
	local character = player.Character
	if not character then
		return
	end
	local pad = findTagged(TAGS.DicePad, mazeId, padId)
	if not pad then
		warn(`[MazeRunner.WorldNav] no DicePad {padId} in {mazeId}`)
		return
	end
	character:PivotTo(pad:GetPivot() * CFrame.new(0, Constants.ENTRANCE_PAD_Y_OFFSET, 0))
end

local function onFallVolume(part: Instance)
	if bound[part] or not part:IsA("BasePart") then
		return
	end
	bound[part] = true
	part.Touched:Connect(function(hit)
		if not hit:IsA("BasePart") then
			return
		end
		local player, character = playerFromHit(hit)
		if not player or not character then
			return
		end
		local mazeId = part:GetAttribute("MazeId")
		if typeof(mazeId) ~= "string" or mazeId == "" then
			return
		end
		local now = os.clock()
		if lastFallAt[player] and now - lastFallAt[player] < FALL_DEBOUNCE then
			return
		end
		lastFallAt[player] = now
		WorldNav.TeleportToEntrance(player, mazeId)
	end)
end

local function onLobbyPortal(part: Instance)
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
		local now = os.clock()
		if lastPortalAt[player] and now - lastPortalAt[player] < FALL_DEBOUNCE then
			return
		end
		lastPortalAt[player] = now
		if player:GetAttribute("InRun") == true then
			local MazeRun = require(script.Parent:WaitForChild("MazeRun"))
			MazeRun.Fail(player, "LobbyPortal")
		end
		WorldNav.TeleportToLobby(player)
	end)
end

function WorldNav.Init()
	for _, inst in CollectionService:GetTagged(TAGS.FallVolume) do
		onFallVolume(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAGS.FallVolume):Connect(onFallVolume)

	for _, inst in CollectionService:GetTagged(TAGS.LobbyPortal) do
		onLobbyPortal(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAGS.LobbyPortal):Connect(onLobbyPortal)

	Players.PlayerRemoving:Connect(function(player)
		lastFallAt[player] = nil
		lastPortalAt[player] = nil
	end)
end

return WorldNav
