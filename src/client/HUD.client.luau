-- Timer, stamina bar, give-up confirm. Map button stays hidden until the SKU slice.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local HudGuis = require(script.Parent:WaitForChild("HudGuis"))
local Movement = require(script.Parent:WaitForChild("Movement"))
Movement.Start()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local guis = HudGuis.Create(playerGui)

local timerLabel = guis.TimerGui.Panel.Time :: TextLabel
local pbLabel = (guis.TimerGui.Panel:FindFirstChild("PB") :: TextLabel)
local fill = guis.StaminaGui.Panel.Fill :: Frame
local giveUpBtn = guis.RunGui.GiveUp :: TextButton
local confirm = guis.RunGui.Confirm :: Frame
local yesBtn = confirm.Yes :: TextButton
local noBtn = confirm.No :: TextButton

local inRun = false
local startTime = 0
local personalBestMs: number? = nil

local function formatTime(seconds: number): string
	if seconds < 0 then
		seconds = 0
	end
	local ms = math.floor((seconds % 1) * 1000 + 0.0001)
	local total = math.floor(seconds)
	local s = total % 60
	local m = math.floor(total / 60) % 60
	local h = math.floor(total / 3600)
	return string.format("%02d:%02d:%02d:%03d", h, m, s, ms)
end

local function formatMs(ms: number?): string
	if typeof(ms) ~= "number" or ms <= 0 then
		return formatTime(0)
	end
	return formatTime(ms / 1000)
end

local function setRunVisible(visible: boolean)
	guis.TimerGui.Enabled = visible
	guis.RunGui.Enabled = visible
	if not visible then
		confirm.Visible = false
	end
end

local function applyHudSync(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	inRun = payload.inRun == true
	if inRun then
		if typeof(payload.startTime) == "number" then
			startTime = payload.startTime
		end
	else
		startTime = 0
	end
	if typeof(payload.personalBestMs) == "number" then
		personalBestMs = payload.personalBestMs
	end
	setRunVisible(inRun)
	pbLabel.Text = `PB {formatMs(personalBestMs)}`
end

local function refreshFromAttributes()
	local attrInRun = player:GetAttribute("InRun") == true
	if attrInRun then
		inRun = true
		local t = player:GetAttribute("StartTime")
		if typeof(t) == "number" then
			startTime = t
		end
		setRunVisible(true)
	elseif not attrInRun then
		inRun = false
		setRunVisible(false)
	end
end

player:GetAttributeChangedSignal("InRun"):Connect(refreshFromAttributes)
player:GetAttributeChangedSignal("StartTime"):Connect(refreshFromAttributes)
refreshFromAttributes()

local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MazeRun")
local hudSync = remotes:WaitForChild("HudSync") :: RemoteEvent
local giveUpRemote = remotes:WaitForChild("GiveUp") :: RemoteEvent
hudSync.OnClientEvent:Connect(applyHudSync)

giveUpBtn.Activated:Connect(function()
	if inRun then
		confirm.Visible = true
	end
end)
yesBtn.Activated:Connect(function()
	confirm.Visible = false
	if inRun then
		giveUpRemote:FireServer()
	end
end)
noBtn.Activated:Connect(function()
	confirm.Visible = false
end)

RunService.RenderStepped:Connect(function()
	if inRun then
		local elapsed = workspace:GetServerTimeNow() - startTime
		timerLabel.Text = formatTime(elapsed)
		pbLabel.Text = `PB {formatMs(personalBestMs)}`
	end
	local visible = Movement.IsStaminaVisible()
	guis.StaminaGui.Enabled = visible
	if visible then
		local alpha = math.clamp(Movement.GetStamina() / Constants.STAMINA_MAX, 0, 1)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		fill.BackgroundColor3 = if Movement.IsSprinting()
			then Color3.fromRGB(80, 200, 120)
			else Color3.fromRGB(220, 180, 70)
	end
end)
