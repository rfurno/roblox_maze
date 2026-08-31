-- ODS adapter. Board UI lands in the stats PR. TrySaveBestTime is used by MazeRun.Complete.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"))
local Session = require(script.Parent:WaitForChild("Session"))

local Leaderboards = {}

local function statsStore(scope: string)
	return DataStoreService:GetOrderedDataStore(Constants.STATS_STORE_NAME, scope)
end

function Leaderboards.TrySaveBestTime(player: Player, mazeId: string, elapsedMs: number): boolean
	local current = Session.GetBestTime(player, mazeId)
	local faster = current == nil or elapsedMs < current
	if not faster then
		return false
	end

	local wroteNewBest = false
	local useReal = not RunService:IsStudio() or workspace:GetAttribute("UseStudioDataStores") == true
	if useReal then
		local ok, err = pcall(function()
			statsStore(mazeId):UpdateAsync(tostring(player.UserId), function(old)
				if old == nil or elapsedMs < old then
					wroteNewBest = true
					return elapsedMs
				end
				return old
			end)
		end)
		if not ok then
			warn(`[MazeRunner.Leaderboards] UpdateAsync fail: {err}`)
			wroteNewBest = true
		end
	else
		wroteNewBest = true
	end

	if wroteNewBest then
		Session.SetBestTime(player, mazeId, elapsedMs)
	end
	return wroteNewBest
end

function Leaderboards.Init() end

return Leaderboards
