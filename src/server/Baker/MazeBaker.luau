-- Studio-only. Call from the command bar:
--   require(game.ServerScriptService.Baker.MazeBaker).Bake("EASY_1")
-- Not required by Main. Re-bake deletes Board* only.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))
local Presets = require(script.Parent:WaitForChild("Presets"))

local TAGS = Constants.TAGS

local DIRS = {
	{ name = "N", dx = 0, dz = 1, opp = "S", outward = Vector3.new(0, 0, 1) },
	{ name = "E", dx = 1, dz = 0, opp = "W", outward = Vector3.new(1, 0, 0) },
	{ name = "S", dx = 0, dz = -1, opp = "N", outward = Vector3.new(0, 0, -1) },
	{ name = "W", dx = -1, dz = 0, opp = "E", outward = Vector3.new(-1, 0, 0) },
}

type Cell = { N: boolean, E: boolean, S: boolean, W: boolean, visited: boolean }
type Grid = { [number]: { [number]: Cell } }
type Coord = { x: number, z: number }

local MazeBaker = {}

local function key(x: number, z: number): string
	return `{x},{z}`
end

local function inBounds(x: number, z: number, w: number, h: number): boolean
	return x >= 1 and z >= 1 and x <= w and z <= h
end

local function makeGrid(w: number, h: number): Grid
	local grid: Grid = {}
	for x = 1, w do
		grid[x] = {}
		for z = 1, h do
			grid[x][z] = { N = true, E = true, S = true, W = true, visited = false }
		end
	end
	return grid
end

local function generateLayer(w: number, h: number, rng: Random, start: Coord): Grid
	local grid = makeGrid(w, h)
	local stack: { Coord } = { { x = start.x, z = start.z } }
	grid[start.x][start.z].visited = true

	while #stack > 0 do
		local cell = stack[#stack]
		local options = {}
		for _, dir in DIRS do
			local nx, nz = cell.x + dir.dx, cell.z + dir.dz
			if inBounds(nx, nz, w, h) and not grid[nx][nz].visited then
				table.insert(options, dir)
			end
		end
		if #options == 0 then
			table.remove(stack)
		else
			local dir = options[rng:NextInteger(1, #options)]
			local nx, nz = cell.x + dir.dx, cell.z + dir.dz
			grid[cell.x][cell.z][dir.name] = false
			grid[nx][nz][dir.opp] = false
			grid[nx][nz].visited = true
			table.insert(stack, { x = nx, z = nz })
		end
	end

	return grid
end

local function cellDegree(grid: Grid, x: number, z: number): number
	local d = 0
	for _, dir in DIRS do
		if grid[x][z][dir.name] == false then
			d += 1
		end
	end
	return d
end

local function bfs(grid: Grid, w: number, h: number, start: Coord, goal: Coord): { Coord }
	local prev: { [string]: Coord? } = {}
	local queue: { Coord } = { start }
	local seen = { [key(start.x, start.z)] = true }
	local head = 1
	prev[key(start.x, start.z)] = nil

	while head <= #queue do
		local cur = queue[head]
		head += 1
		if cur.x == goal.x and cur.z == goal.z then
			break
		end
		for _, dir in DIRS do
			if grid[cur.x][cur.z][dir.name] == false then
				local nx, nz = cur.x + dir.dx, cur.z + dir.dz
				if inBounds(nx, nz, w, h) then
					local k = key(nx, nz)
					if not seen[k] then
						seen[k] = true
						prev[k] = cur
						table.insert(queue, { x = nx, z = nz })
					end
				end
			end
		end
	end

	local goalKey = key(goal.x, goal.z)
	if not seen[goalKey] then
		return { start }
	end

	local path = {}
	local cursor: Coord? = goal
	while cursor do
		table.insert(path, 1, cursor)
		cursor = prev[key(cursor.x, cursor.z)]
	end
	return path
end

local function chooseStairs(grid: Grid, path: { Coord }, h: number, entrance: Coord, exit: Coord): Coord
	local bestDist = -1
	local first: Coord? = nil
	for _, cell in path do
		local isEntrance = cell.x == entrance.x and cell.z == entrance.z
		local isExit = cell.x == exit.x and cell.z == exit.z
		if not isEntrance and not isExit and cellDegree(grid, cell.x, cell.z) == 2 then
			local dist = (h - cell.z) + math.abs(cell.x - exit.x)
			if dist > bestDist then
				bestDist = dist
				first = cell
			end
		end
	end
	if first then
		return first
	end
	local mid = path[math.clamp(math.ceil(#path / 2), 1, #path)]
	if mid.x == entrance.x and mid.z == entrance.z and #path > 1 then
		return path[2]
	end
	return mid
end

local function cellCenter(origin: Vector3, cellSize: number, x: number, z: number, y: number): Vector3
	return Vector3.new(origin.X + (x - 0.5) * cellSize, y, origin.Z + (z - 0.5) * cellSize)
end

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function tagMaze(part: BasePart, tag: string, mazeId: string)
	CollectionService:AddTag(part, tag)
	part:SetAttribute("MazeId", mazeId)
end

local function makePart(name: string, parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function ensureWallTemplate(cellSize: number, wallHeight: number, thickness: number): Model
	local templates = ensureFolder(ServerStorage, "Templates")
	local walls = ensureFolder(templates, "Walls")
	local existing = walls:FindFirstChild("ShippingContainer")
	if existing and existing:IsA("Model") then
		local primary = existing.PrimaryPart or existing:FindFirstChild("Shell")
		if primary and primary:IsA("BasePart") then
			if
				math.abs(primary.Size.X - cellSize) < 0.05
				and math.abs(primary.Size.Y - wallHeight) < 0.05
				and math.abs(primary.Size.Z - thickness) < 0.05
			then
				return existing
			end
		end
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "ShippingContainer"

	local shell = makePart(
		"Shell",
		model,
		Vector3.new(cellSize, wallHeight, thickness),
		CFrame.new(),
		Color3.fromRGB(201, 88, 36),
		Enum.Material.Metal
	)

	local ridges = math.max(5, math.floor(cellSize / 2.4))
	local span = cellSize - 2
	for i = 0, ridges - 1 do
		local t = if ridges == 1 then 0 else (i / (ridges - 1) - 0.5)
		local ridge = makePart(
			"Ridge",
			model,
			Vector3.new(1.1, wallHeight - 0.6, thickness + 0.25),
			CFrame.new(t * span, 0, 0),
			Color3.fromRGB(172, 70, 26),
			Enum.Material.DiamondPlate
		)
		ridge.Parent = model
	end

	makePart(
		"FrameTop",
		model,
		Vector3.new(cellSize, 0.4, thickness + 0.35),
		CFrame.new(0, wallHeight / 2 - 0.2, 0),
		Color3.fromRGB(40, 40, 44),
		Enum.Material.Metal
	)
	makePart(
		"FrameBottom",
		model,
		Vector3.new(cellSize, 0.4, thickness + 0.35),
		CFrame.new(0, -wallHeight / 2 + 0.2, 0),
		Color3.fromRGB(40, 40, 44),
		Enum.Material.Metal
	)

	model.PrimaryPart = shell
	model.WorldPivot = CFrame.new()
	model.Parent = walls
	return model
end

local function stampWall(
	template: Model,
	parent: Instance,
	pos: Vector3,
	outward: Vector3,
	name: string
)
	local clone = template:Clone()
	clone.Name = name
	clone:PivotTo(CFrame.lookAt(pos, pos + outward))
	clone.Parent = parent
end

local function clearBoards(mazeFolder: Folder)
	for _, child in mazeFolder:GetChildren() do
		if child.Name:match("^Board%d+$") then
			child:Destroy()
		end
	end
end

local function resolveOrigin(preset, mazeFolder: Folder): Vector3?
	local stored = mazeFolder:GetAttribute("BakeOrigin")
	if typeof(stored) == "Vector3" then
		return stored
	end

	local lobby = workspace:FindFirstChild("Lobby")
	local landing = lobby and lobby:FindFirstChild("EasyLanding")
	local floor = landing and landing:FindFirstChild("Floor")
	if not (floor and floor:IsA("BasePart")) then
		warn("[MazeBaker] baker origin unset: Workspace.Lobby.EasyLanding.Floor missing")
		return nil
	end

	local entranceX = math.floor((preset.gridWidth + 1) / 2)
	local originX = floor.Position.X - (entranceX - 0.5) * preset.cellSize
	local originY = floor.Position.Y + floor.Size.Y / 2
	local originZ = floor.Position.Z + floor.Size.Z / 2
	return Vector3.new(originX, originY, originZ)
end

local function stampFloorsAndWalls(
	board: Folder,
	grid: Grid,
	preset,
	origin: Vector3,
	layer: number,
	template: Model,
	skipFloor: Coord?
)
	local floors = ensureFolder(board, "Floors")
	local walls = ensureFolder(board, "Walls")
	local w, h = preset.gridWidth, preset.gridHeight
	local cs, wh, th, ft = preset.cellSize, preset.wallHeight, preset.wallThickness, preset.floorThickness
	local floorY = origin.Y + (layer - 1) * wh
	local wallY = floorY + wh / 2
	local floorColor = if layer == 1 then Color3.fromRGB(70, 74, 82) else Color3.fromRGB(62, 68, 78)

	for x = 1, w do
		for z = 1, h do
			if not (skipFloor and skipFloor.x == x and skipFloor.z == z) then
				makePart(
					`Floor_{x}_{z}`,
					floors,
					Vector3.new(cs, ft, cs),
					CFrame.new(cellCenter(origin, cs, x, z, floorY - ft / 2)),
					floorColor,
					Enum.Material.Concrete
				)
			end

			local cell = grid[x][z]
			if cell.N then
				stampWall(
					template,
					walls,
					Vector3.new(origin.X + (x - 0.5) * cs, wallY, origin.Z + z * cs),
					Vector3.new(0, 0, 1),
					`WallN_{x}_{z}`
				)
			end
			if cell.E then
				stampWall(
					template,
					walls,
					Vector3.new(origin.X + x * cs, wallY, origin.Z + (z - 0.5) * cs),
					Vector3.new(1, 0, 0),
					`WallE_{x}_{z}`
				)
			end
			if z == 1 and cell.S then
				stampWall(
					template,
					walls,
					Vector3.new(origin.X + (x - 0.5) * cs, wallY, origin.Z),
					Vector3.new(0, 0, -1),
					`WallS_{x}_{z}`
				)
			end
			if x == 1 and cell.W then
				stampWall(
					template,
					walls,
					Vector3.new(origin.X, wallY, origin.Z + (z - 0.5) * cs),
					Vector3.new(-1, 0, 0),
					`WallW_{x}_{z}`
				)
			end
		end
	end
end

local function stampStairs(board1: Folder, board2: Folder, origin: Vector3, preset, stairs: Coord)
	local cs, wh, ft = preset.cellSize, preset.wallHeight, preset.floorThickness
	local x0 = origin.X + (stairs.x - 1) * cs
	local z0 = origin.Z + (stairs.z - 1) * cs
	local y1 = origin.Y
	local y2 = origin.Y + wh

	local folder = Instance.new("Folder")
	folder.Name = "Stairs"
	folder.Parent = board1

	local steps = 8
	local stepRise = wh / steps
	local stepRun = (cs * 0.65) / steps
	local stepWidth = cs * 0.55
	for i = 1, steps do
		makePart(
			`Step{i}`,
			folder,
			Vector3.new(stepWidth, math.max(0.4, stepRise), stepRun),
			CFrame.new(x0 + cs * 0.5, y1 + (i - 0.5) * stepRise, z0 + 2 + (i - 0.5) * stepRun),
			Color3.fromRGB(130, 96, 60),
			Enum.Material.WoodPlanks
		)
	end

	-- U-shaped L2 floor around the stair well so the cell is still a corridor.
	local holeW = stepWidth + 2
	local holeD = 2 + steps * stepRun
	local sideW = (cs - holeW) / 2
	local floorY = y2 - ft / 2
	local floorColor = Color3.fromRGB(62, 68, 78)
	makePart(
		"L2North",
		board2,
		Vector3.new(cs, ft, math.max(2, cs - holeD)),
		CFrame.new(x0 + cs / 2, floorY, z0 + holeD + (cs - holeD) / 2),
		floorColor,
		Enum.Material.Concrete
	)
	if sideW > 1 then
		makePart(
			"L2West",
			board2,
			Vector3.new(sideW, ft, holeD),
			CFrame.new(x0 + sideW / 2, floorY, z0 + holeD / 2),
			floorColor,
			Enum.Material.Concrete
		)
		makePart(
			"L2East",
			board2,
			Vector3.new(sideW, ft, holeD),
			CFrame.new(x0 + cs - sideW / 2, floorY, z0 + holeD / 2),
			floorColor,
			Enum.Material.Concrete
		)
	end
end

local function stampPlates(mazeFolder: Folder, origin: Vector3, preset, entrance: Coord, exit: Coord)
	local cs, wh, ft = preset.cellSize, preset.wallHeight, preset.floorThickness
	local mazeId = preset.mazeId
	local entranceFolder = ensureFolder(mazeFolder, "Entrance")
	local exitFolder = ensureFolder(mazeFolder, "Exit")

	local function replace(parent: Instance, name: string): ()
		local old = parent:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	local shouldStamp = preset.stampPlates ~= false
	local restamp = preset.restampPlates == true
	if not shouldStamp then
		return
	end

	if restamp or not entranceFolder:FindFirstChild("MazeGate") then
		replace(entranceFolder, "MazeGate")
		local gatePos = Vector3.new(
			origin.X + (entrance.x - 0.5) * cs,
			origin.Y + wh / 2,
			origin.Z + 0.5
		)
		local gate = makePart(
			"MazeGate",
			entranceFolder,
			Vector3.new(cs - 4, wh, 1),
			CFrame.new(gatePos),
			Color3.fromRGB(80, 220, 120),
			Enum.Material.Neon
		)
		gate.Transparency = 0.55
		gate.CanCollide = false
		gate.CanTouch = true
		tagMaze(gate, TAGS.MazeGate, mazeId)
	end

	if restamp or not entranceFolder:FindFirstChild("EntrancePad") then
		replace(entranceFolder, "EntrancePad")
		local padPos = cellCenter(origin, cs, entrance.x, entrance.z, origin.Y + 0.15)
		-- Sit past the south gate, still inside the first cell.
		padPos = Vector3.new(padPos.X, padPos.Y, origin.Z + 8)
		local pad = makePart(
			"EntrancePad",
			entranceFolder,
			Vector3.new(10, 0.4, 10),
			CFrame.new(padPos),
			Color3.fromRGB(90, 200, 110),
			Enum.Material.Neon
		)
		pad.CanCollide = true
		pad.CanTouch = true
		tagMaze(pad, TAGS.EntrancePad, mazeId)
	end

	if restamp or not exitFolder:FindFirstChild("MazeExit") then
		replace(exitFolder, "MazeExit")
		local exitY = origin.Y + (preset.layers - 1) * wh + 0.15
		local exitPos = cellCenter(origin, cs, exit.x, exit.z, exitY)
		local plate = makePart(
			"MazeExit",
			exitFolder,
			Vector3.new(12, 0.4, 12),
			CFrame.new(exitPos),
			Color3.fromRGB(240, 190, 70),
			Enum.Material.Neon
		)
		plate.CanCollide = true
		plate.CanTouch = true
		tagMaze(plate, TAGS.MazeExit, mazeId)
	end
end

local function stampFallVolume(mazeFolder: Folder, origin: Vector3, preset, entrance: Coord)
	if preset.stampPlates == false then
		return
	end
	local existing = mazeFolder:FindFirstChild("FallVolume")
	if existing and preset.restampPlates ~= true then
		return
	end
	if existing then
		existing:Destroy()
	end

	local cs, wh, layers = preset.cellSize, preset.wallHeight, preset.layers
	local wSize = preset.gridWidth * cs
	local hSize = preset.gridHeight * cs
	local topY = origin.Y + layers * wh
	local slabTop = origin.Y - 2
	local slabThickness = 12
	local mazeId = preset.mazeId

	local folder = Instance.new("Folder")
	folder.Name = "FallVolume"
	folder.Parent = mazeFolder

	local function voidPart(name: string, size: Vector3, cframe: CFrame)
		local p = makePart(name, folder, size, cframe, Color3.fromRGB(90, 20, 20), Enum.Material.SmoothPlastic)
		p.Transparency = 0.9
		p.CanCollide = false
		p.CanTouch = true
		p.CanQuery = true
		tagMaze(p, TAGS.FallVolume, mazeId)
		return p
	end

	voidPart(
		"Slab",
		Vector3.new(wSize + 8, slabThickness, hSize + 8),
		CFrame.new(origin.X + wSize / 2, slabTop - slabThickness / 2, origin.Z + hSize / 2)
	)

	local skirtThick = 4
	local skirtGap = 3
	local skirtHeight = (topY - (slabTop - slabThickness))
	local skirtY = slabTop - slabThickness / 2 + skirtHeight / 2
	local outer = skirtGap + skirtThick / 2

	-- East / west full skirts.
	voidPart(
		"SkirtE",
		Vector3.new(skirtThick, skirtHeight, hSize + 8),
		CFrame.new(origin.X + wSize + outer, skirtY, origin.Z + hSize / 2)
	)
	voidPart(
		"SkirtW",
		Vector3.new(skirtThick, skirtHeight, hSize + 8),
		CFrame.new(origin.X - outer, skirtY, origin.Z + hSize / 2)
	)
	voidPart(
		"SkirtN",
		Vector3.new(wSize + 8, skirtHeight, skirtThick),
		CFrame.new(origin.X + wSize / 2, skirtY, origin.Z + hSize + outer)
	)

	-- South skirt split around the entrance opening so the landing walk-in is clear.
	local entranceMinX = origin.X + (entrance.x - 1) * cs
	local entranceMaxX = entranceMinX + cs
	local southZ = origin.Z - outer
	local leftWidth = math.max(0, entranceMinX - origin.X)
	local rightWidth = math.max(0, (origin.X + wSize) - entranceMaxX)
	if leftWidth > 2 then
		voidPart(
			"SkirtS_L",
			Vector3.new(leftWidth, skirtHeight, skirtThick),
			CFrame.new(origin.X + leftWidth / 2, skirtY, southZ)
		)
	end
	if rightWidth > 2 then
		voidPart(
			"SkirtS_R",
			Vector3.new(rightWidth, skirtHeight, skirtThick),
			CFrame.new(origin.X + wSize - rightWidth / 2, skirtY, southZ)
		)
	end
end

local function stampSolution(
	mazeId: string,
	origin: Vector3,
	preset,
	pathL1: { Coord },
	pathL2: { Coord }?,
	stairs: Coord?
)
	local solutions = ensureFolder(ReplicatedStorage, "MazeSolution")
	local old = solutions:FindFirstChild(mazeId)
	if old then
		old:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = mazeId

	local cs, wh = preset.cellSize, preset.wallHeight
	local function addSegment(a: Vector3, b: Vector3, name: string)
		local delta = b - a
		local length = delta.Magnitude
		if length < 0.2 then
			return
		end
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 220, 80)
		p.Size = Vector3.new(1.4, 0.35, length)
		p.CFrame = CFrame.lookAt((a + b) / 2, b)
		p.Parent = model
	end

	local function centers(path: { Coord }, y: number): { Vector3 }
		local points = {}
		for _, cell in path do
			table.insert(points, cellCenter(origin, cs, cell.x, cell.z, y + 2.5))
		end
		return points
	end

	local n = 0
	local l1 = centers(pathL1, origin.Y)
	for i = 2, #l1 do
		n += 1
		addSegment(l1[i - 1], l1[i], `Seg{n}`)
	end
	if stairs and pathL2 then
		local top = cellCenter(origin, cs, stairs.x, stairs.z, origin.Y + wh + 2.5)
		n += 1
		addSegment(l1[#l1], top, `Seg{n}`)
		local l2 = centers(pathL2, origin.Y + wh)
		if #l2 > 0 then
			n += 1
			addSegment(top, l2[1], `Seg{n}`)
		end
		for i = 2, #l2 do
			n += 1
			addSegment(l2[i - 1], l2[i], `Seg{n}`)
		end
	end

	model.WorldPivot = CFrame.new(origin)
	model.Parent = solutions
end

function MazeBaker.Bake(mazeId: string)
	local preset = Presets[mazeId]
	if not preset then
		warn(`[MazeBaker] unknown mazeId {mazeId}`)
		return false
	end

	local mazes = workspace:FindFirstChild("Mazes")
	if not mazes then
		warn("[MazeBaker] Workspace.Mazes missing")
		return false
	end
	local mazeFolder = mazes:FindFirstChild(mazeId)
	if not (mazeFolder and mazeFolder:IsA("Folder")) then
		warn(`[MazeBaker] Workspace.Mazes.{mazeId} missing`)
		return false
	end

	local origin = resolveOrigin(preset, mazeFolder)
	if not origin then
		return false
	end

	local seed = preset.seed
	local w, h, layers = preset.gridWidth, preset.gridHeight, preset.layers
	local entrance: Coord = { x = math.floor((w + 1) / 2), z = 1 }
	local exit: Coord = { x = entrance.x, z = h }

	local template = ensureWallTemplate(preset.cellSize, preset.wallHeight, preset.wallThickness)

	clearBoards(mazeFolder)
	ensureFolder(mazeFolder, "Entrance")
	ensureFolder(mazeFolder, "Arena")
	ensureFolder(mazeFolder, "Exit")
	ensureFolder(mazeFolder, "Hazards")

	local grids: { Grid } = {}
	for layer = 1, layers do
		local rng = Random.new(seed + layer * 997)
		local start = if layer == 1 then entrance else { x = entrance.x, z = entrance.z }
		grids[layer] = generateLayer(w, h, rng, start)
	end

	-- Openings: south L1 entrance, north top-layer exit.
	grids[1][entrance.x][entrance.z].S = false
	grids[layers][exit.x][exit.z].N = false

	local stairs: Coord? = nil
	local pathL1: { Coord }
	local pathL2: { Coord }? = nil
	if layers >= 2 then
		local northGoal: Coord = { x = exit.x, z = h }
		local unique = bfs(grids[1], w, h, entrance, northGoal)
		stairs = chooseStairs(grids[1], unique, h, entrance, northGoal)
		pathL1 = bfs(grids[1], w, h, entrance, stairs)
		pathL2 = bfs(grids[layers], w, h, stairs, exit)
	else
		pathL1 = bfs(grids[1], w, h, entrance, exit)
	end

	for layer = 1, layers do
		local board = Instance.new("Folder")
		board.Name = `Board{layer}`
		board.Parent = mazeFolder
		local skip = if layer == 2 and stairs then stairs else nil
		stampFloorsAndWalls(board, grids[layer], preset, origin, layer, template, skip)
	end

	if stairs and layers >= 2 then
		stampStairs(mazeFolder:FindFirstChild("Board1") :: Folder, mazeFolder:FindFirstChild("Board2") :: Folder, origin, preset, stairs)
	end

	stampPlates(mazeFolder, origin, preset, entrance, exit)
	stampFallVolume(mazeFolder, origin, preset, entrance)

	if preset.bakeSolution then
		stampSolution(mazeId, origin, preset, pathL1, pathL2, stairs)
	end

	mazeFolder:SetAttribute("MazeId", mazeId)
	mazeFolder:SetAttribute("BakeOrigin", origin)
	mazeFolder:SetAttribute("Seed", seed)

	print(`[MazeBaker] stamped {mazeId} seed={seed} boards={layers}`)
	return true
end

return MazeBaker
