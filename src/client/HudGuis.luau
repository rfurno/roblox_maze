-- Builds TimerGui / StaminaGui / RunGui. Idempotent. Used by HUD and Studio stamp.

local HudGuis = {}

local function inst(className: string, props: { [string]: any }): Instance
	local obj = Instance.new(className)
	for key, value in props do
		(obj :: any)[key] = value
	end
	return obj
end

local function child(parent: Instance, className: string, name: string, props: { [string]: any }?): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		if props then
			for key, value in props do
				(existing :: any)[key] = value
			end
		end
		return existing
	end
	local obj = inst(className, props or {})
	obj.Name = name
	obj.Parent = parent
	return obj
end

function HudGuis.Create(parent: Instance)
	local timerGui = child(parent, "ScreenGui", "TimerGui", {
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	})
	local timerPanel = child(timerGui, "Frame", "Panel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(280, 64),
		BackgroundColor3 = Color3.fromRGB(18, 22, 28),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	})
	child(timerPanel, "UICorner", "Corner", { CornerRadius = UDim.new(0, 8) })
	child(timerPanel, "TextLabel", "Time", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 36),
		Font = Enum.Font.RobotoMono,
		Text = "00:00:00:000",
		TextColor3 = Color3.fromRGB(255, 230, 120),
		TextSize = 28,
	})
	child(timerPanel, "TextLabel", "PB", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 22),
		Font = Enum.Font.Gotham,
		Text = "PB 00:00:00:000",
		TextColor3 = Color3.fromRGB(180, 190, 200),
		TextSize = 14,
	})

	local staminaGui = child(parent, "ScreenGui", "StaminaGui", {
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 19,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	})
	local stamPanel = child(staminaGui, "Frame", "Panel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -28),
		Size = UDim2.fromOffset(220, 18),
		BackgroundColor3 = Color3.fromRGB(18, 22, 28),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	})
	child(stamPanel, "UICorner", "Corner", { CornerRadius = UDim.new(0, 6) })
	child(stamPanel, "Frame", "Fill", {
		BackgroundColor3 = Color3.fromRGB(80, 200, 120),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	})
	local fill = stamPanel:FindFirstChild("Fill")
	if fill then
		child(fill, "UICorner", "Corner", { CornerRadius = UDim.new(0, 6) })
	end

	local runGui = child(parent, "ScreenGui", "RunGui", {
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 21,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	})
	child(runGui, "TextButton", "GiveUp", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(120, 40),
		BackgroundColor3 = Color3.fromRGB(160, 50, 50),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "Give up",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 18,
		AutoButtonColor = true,
	})
	local giveUp = runGui:FindFirstChild("GiveUp")
	if giveUp then
		child(giveUp, "UICorner", "Corner", { CornerRadius = UDim.new(0, 8) })
	end
	child(runGui, "TextButton", "MapButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -68),
		Size = UDim2.fromOffset(120, 40),
		BackgroundColor3 = Color3.fromRGB(50, 80, 140),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "Map",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 18,
		Visible = false,
	})

	local confirm = child(runGui, "Frame", "Confirm", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(320, 140),
		BackgroundColor3 = Color3.fromRGB(18, 22, 28),
		BorderSizePixel = 0,
		Visible = false,
	})
	child(confirm, "UICorner", "Corner", { CornerRadius = UDim.new(0, 10) })
	child(confirm, "TextLabel", "Title", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 40),
		Font = Enum.Font.GothamBold,
		Text = "Give up this run?",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 20,
	})
	child(confirm, "TextButton", "Yes", {
		Position = UDim2.new(0.5, 8, 1, -52),
		Size = UDim2.fromOffset(120, 36),
		BackgroundColor3 = Color3.fromRGB(160, 50, 50),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "Give up",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 16,
	})
	child(confirm, "TextButton", "No", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.5, -8, 1, -52),
		Size = UDim2.fromOffset(120, 36),
		BackgroundColor3 = Color3.fromRGB(50, 58, 70),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "Keep running",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 16,
	})
	for _, name in { "Yes", "No" } do
		local btn = confirm:FindFirstChild(name)
		if btn then
			child(btn, "UICorner", "Corner", { CornerRadius = UDim.new(0, 6) })
		end
	end

	return {
		TimerGui = timerGui,
		StaminaGui = staminaGui,
		RunGui = runGui,
	}
end

return HudGuis
