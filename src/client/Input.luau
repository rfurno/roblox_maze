-- Hold-state for sprint (Shift / R2) and crouch (C / L3). Required by Movement.

local UserInputService = game:GetService("UserInputService")

local Input = {}

local function anyGamepad(button: Enum.KeyCode): boolean
	for _, gamepad in UserInputService:GetConnectedGamepads() do
		if UserInputService:IsGamepadButtonDown(gamepad, button) then
			return true
		end
	end
	return false
end

function Input.IsSprintHeld(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or anyGamepad(Enum.KeyCode.ButtonR2)
end

function Input.IsCrouchHeld(): boolean
	if UserInputService:GetFocusedTextBox() ~= nil then
		return false
	end
	return UserInputService:IsKeyDown(Enum.KeyCode.C) or anyGamepad(Enum.KeyCode.ButtonL3)
end

return Input
