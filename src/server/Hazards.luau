-- Data-driven hazards. Tagged parts carry numbers. No Scripts under Workspace.Mazes.
-- PR 5: KillBeam only. Other types bind in later slices.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local MazeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MazeConfig"))

local TAGS = Constants.TAGS
local bound: { [Instance]: boolean } = {}
local lastHit: { [Player]: { [BasePart]: number } } = {}
local HIT_DEBOUNCE = 0.2

local Hazards = {}

local function playerFromHit(hit: BasePart): (Player?, Humanoid?)
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then
		return nil, nil
	end
	local player = Players:GetPlayerFromCharacter(model)
	if not player then
		return nil, nil
	end
	return player, model:FindFirstChildOfClass("Humanoid")
end

local function applyDamage(trigger: BasePart, hit: BasePart)
	local player, hum = playerFromHit(hit)
	if not player or not hum or hum.Health <= 0 then
		return
	end
	local now = os.clock()
	local byPart = lastHit[player]
	if not byPart then
		byPart = {}
		lastHit[player] = byPart
	end
	if byPart[trigger] and now - byPart[trigger] < HIT_DEBOUNCE then
		return
	end
	byPart[trigger] = now
	local damage = trigger:GetAttribute("Damage")
	if typeof(damage) ~= "number" then
		damage = 100
	end
	hum:TakeDamage(damage)
end

local function setVisual(trigger: BasePart, active: boolean)
	trigger.CanTouch = active
	trigger.CanQuery = true
	trigger.CanCollide = false
	if active then
		trigger.Transparency = 0.2
		trigger.Color = Color3.fromRGB(255, 48, 48)
		trigger.Material = Enum.Material.Neon
	else
		trigger.Transparency = 0.72
		trigger.Color = Color3.fromRGB(70, 18, 18)
		trigger.Material = Enum.Material.SmoothPlastic
	end
	local root: Instance = trigger.Parent or trigger
	for _, d in root:GetDescendants() do
		if d:IsA("Beam") then
			d.Enabled = active
		end
	end
end

local function damageOccupants(trigger: BasePart)
	for _, inst in workspace:GetPartsInPart(trigger) do
		if inst:IsA("BasePart") then
			applyDamage(trigger, inst)
		end
	end
end

local function bindKillBeam(part: Instance)
	if bound[part] or not part:IsA("BasePart") then
		return
	end
	bound[part] = true

	local period = part:GetAttribute("Period")
	if typeof(period) ~= "number" then
		period = 3
	end
	local startOn = part:GetAttribute("StartOn") == true
	if typeof(part:GetAttribute("Damage")) ~= "number" then
		part:SetAttribute("Damage", 100)
	end

	local function setActive(active: boolean)
		setVisual(part, active)
		if active then
			damageOccupants(part)
		end
	end

	if period <= 0 then
		setActive(startOn)
	else
		setActive(startOn)
		task.spawn(function()
			local on = startOn
			while part.Parent do
				task.wait(period)
				if not part.Parent then
					break
				end
				on = not on
				setActive(on)
			end
		end)
	end

	part.Touched:Connect(function(hit)
		if hit:IsA("BasePart") and part.CanTouch then
			applyDamage(part, hit)
		end
	end)
end

local function warnMissingTags()
	local mazes = workspace:FindFirstChild("Mazes")
	if not mazes then
		return
	end
	for mazeId, row in MazeConfig do
		local folder = mazes:FindFirstChild(mazeId)
		if not folder then
			continue
		end
		for _, hazardType in row.hazards do
			local count = 0
			for _, inst in CollectionService:GetTagged(hazardType) do
				if inst:IsDescendantOf(folder) then
					count += 1
				end
			end
			if count == 0 then
				warn(`[MazeRunner.Hazards] {mazeId} checklist {hazardType} has zero tags`)
			end
		end
	end
end

function Hazards.Init()
	for _, inst in CollectionService:GetTagged(TAGS.KillBeam) do
		bindKillBeam(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAGS.KillBeam):Connect(bindKillBeam)
	warnMissingTags()
	Players.PlayerRemoving:Connect(function(player)
		lastHit[player] = nil
	end)
end

return Hazards
