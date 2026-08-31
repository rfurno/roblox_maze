-- Easy 1 baker preset. Seed stays knobbable until freeze (edit seed, then Bake).

export type Preset = {
	mazeId: string,
	seed: number,
	gridWidth: number,
	gridHeight: number,
	layers: number,
	cellSize: number,
	wallHeight: number,
	wallThickness: number,
	floorThickness: number,
	wallTemplate: string,
	algorithm: string,
	bakeSolution: boolean,
	stampPlates: boolean,
	restampPlates: boolean,
	entranceSide: string,
	exitSide: string,
}

return {
	EASY_1 = {
		mazeId = "EASY_1",
		seed = 1,
		gridWidth = 6,
		gridHeight = 6,
		layers = 2,
		cellSize = 24,
		wallHeight = 10.7,
		wallThickness = 2,
		floorThickness = 1,
		wallTemplate = "ShippingContainer",
		algorithm = "RecursiveBacktracker",
		bakeSolution = true,
		stampPlates = true,
		restampPlates = false,
		entranceSide = "S",
		exitSide = "N",
	},
}
