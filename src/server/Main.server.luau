-- Boot. Require is optional so early slices boot without later modules.

local function init(name: string)
	local mod = script.Parent:FindFirstChild(name)
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if not ok then
			warn(`[Main] require {name} failed: {result}`)
			return
		end
		if type(result) == "table" and type(result.Init) == "function" then
			local initOk, initErr = pcall(result.Init)
			if not initOk then
				warn(`[Main] {name}.Init failed: {initErr}`)
			end
		end
	end
end

init("Session")
init("Monetization")
init("MazeRun")
init("WorldNav")
init("Hazards")
init("Bots")
init("Collectibles")
init("Leaderboards")
-- Baker is Studio-only; do not Init here.
