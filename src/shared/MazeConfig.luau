-- Per-maze rows. Tagged instances own placement; this table is a checklist + metadata.
-- badgeId / pass ids stay 0 until the monetization PR (new universe).

export type Hunters = {
	mode: "none" | "hunt",
	count: number,
}

export type MazeRow = {
	id: string,
	displayName: string,
	badgeId: number,
	requiresPass: boolean,
	hunters: Hunters,
	hazards: { string }, -- types expected as CollectionService tags in this maze
	hasDice: boolean,
	hasSecret: boolean,
}

local MazeConfig: { [string]: MazeRow } = {
	EASY_1 = {
		id = "EASY_1",
		displayName = "Easy 1",
		badgeId = 0,
		requiresPass = false,
		hunters = { mode = "none", count = 0 },
		hazards = { "KillBeam" },
		hasDice = false,
		hasSecret = false,
	},
	EASY_2 = {
		id = "EASY_2",
		displayName = "Easy 2",
		badgeId = 0,
		requiresPass = false,
		hunters = { mode = "none", count = 0 },
		hazards = { "TimedFire" },
		hasDice = false,
		hasSecret = false,
	},
	MILD_1 = {
		id = "MILD_1",
		displayName = "Mild 1",
		badgeId = 0,
		requiresPass = false,
		hunters = { mode = "none", count = 0 },
		hazards = { "KillBeam", "DamagePad", "Dice" },
		hasDice = true,
		hasSecret = true,
	},
	MILD_2 = {
		id = "MILD_2",
		displayName = "Mild 2",
		badgeId = 0,
		requiresPass = false,
		hunters = { mode = "none", count = 0 },
		hazards = { "KillBeam", "MovingPlatform", "ProjectileRing", "Dice" },
		hasDice = true,
		hasSecret = true,
	},
	HARD_1 = {
		id = "HARD_1",
		displayName = "Hard 1",
		badgeId = 0,
		requiresPass = false,
		hunters = { mode = "hunt", count = 2 },
		hazards = { "Dice" },
		hasDice = true,
		hasSecret = true,
	},
	INSANE_1 = {
		id = "INSANE_1",
		displayName = "Insane 1",
		badgeId = 0,
		requiresPass = true,
		hunters = { mode = "none", count = 0 },
		hazards = {},
		hasDice = false,
		hasSecret = true,
	},
}

return MazeConfig
