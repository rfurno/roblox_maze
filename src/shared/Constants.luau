-- Shared tunables. Server and client both require this.

local Constants = {
	WALK_SPEED = 25,
	JUMP_POWER = 100,
	SPRINT_DELTA = 10,
	SPRINT_CAP = 35,
	CROUCH_WALK_SPEED = 16,
	STAMINA_MAX = 100,
	STAMINA_RATE = 10, -- drain and regen per second
	STAMINA_RESUME = 60,
	GATE_DEBOUNCE_SECONDS = 1.5,
	ENTRANCE_PAD_Y_OFFSET = 3,
	STATS_STORE_NAME = "MazeRunnerStats",
	PROFILE_STORE_NAME = "MazeRunnerPlayer",
	LEADERBOARD_REFRESH_SECONDS = 65,
	MAZE_IDS = { "EASY_1", "EASY_2", "MILD_1", "MILD_2", "HARD_1", "INSANE_1" },
	ODS_SCOPES = { "EASY_1", "EASY_2", "MILD_1", "MILD_2", "HARD_1", "INSANE_1", "COLLECTOR" },
	-- CollectionService tag names. One tag per concern; never double-tag a model.
	TAGS = {
		MazeGate = "MazeGate",
		MazeExit = "MazeExit",
		EntrancePad = "EntrancePad",
		FallVolume = "FallVolume",
		LobbyPortal = "LobbyPortal",
		KillBeam = "KillBeam",
		DamagePad = "DamagePad",
		TimedFire = "TimedFire",
		ProjectileRing = "ProjectileRing",
		MovingPlatform = "MovingPlatform",
		Dice = "Dice",
		Secret = "Secret",
		ThingSpawnPad = "ThingSpawnPad",
		Thing = "Thing",
		InsaneDoor = "InsaneDoor",
		PatrolWaypoint = "PatrolWaypoint",
		BotSpawn = "BotSpawn",
		DicePad = "DicePad",
	},
}

return Constants
