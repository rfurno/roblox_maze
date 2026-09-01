-- Client walk / sprint / crouch. Server reapplies base WalkSpeed / JumpPower on spawn.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local Input = require(script.Parent:WaitForChild("Input"))

local Movement = {}

local stamina = Constants.STAMINA_MAX
local exhausted = false
local sprinting = false
local crouching = false
local started = false

function Movement.GetStamina(): number
	return stamina
end

function Movement.IsSprinting(): boolean
	return sprinting
end

function Movement.IsCrouching(): boolean
	return crouching
end

function Movement.IsStaminaVisible(): boolean
	return sprinting or stamina < Constants.STAMINA_MAX
end

local function humanoidOf(character: Model?): Humanoid?
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function apply(hum: Humanoid, walk: number, jump: number)
	hum.UseJumpPower = true
	hum.WalkSpeed = walk
	hum.JumpPower = jump
end

function Movement.Start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer

	RunService.Heartbeat:Connect(function(dt)
		local hum = humanoidOf(player.Character)
		if not hum or hum.Health <= 0 then
			sprinting = false
			crouching = false
			return
		end

		crouching = Input.IsCrouchHeld()
		local sprintHeld = Input.IsSprintHeld()
		local canSprint = if exhausted then stamina > Constants.STAMINA_RESUME else stamina > 0

		if crouching then
			sprinting = false
			apply(hum, Constants.CROUCH_WALK_SPEED, 0)
		elseif sprintHeld and canSprint then
			sprinting = true
			exhausted = false
			apply(hum, Constants.SPRINT_CAP, Constants.JUMP_POWER)
		else
			sprinting = false
			apply(hum, Constants.WALK_SPEED, Constants.JUMP_POWER)
		end

		if sprinting then
			stamina = math.max(0, stamina - Constants.STAMINA_RATE * dt)
			if stamina <= 0 then
				stamina = 0
				exhausted = true
				sprinting = false
				apply(hum, Constants.WALK_SPEED, Constants.JUMP_POWER)
			end
		else
			stamina = math.min(Constants.STAMINA_MAX, stamina + Constants.STAMINA_RATE * dt)
			if exhausted and stamina > Constants.STAMINA_RESUME then
				exhausted = false
			end
		end
	end)
end

return Movement
