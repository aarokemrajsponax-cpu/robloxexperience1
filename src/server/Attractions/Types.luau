--!strict
-- The shapes the attractions share (server/Attractions and its games: Luxe, Basement, Executive).

local Types = {}

-- A feat for the whole house (server/Herald).
export type Feat = { kind: string, title: string, line: string, glyph: string?, worth: number?, colour: Color3?, everywhere: boolean? }

-- What every attraction works through (server/Attractions makes it). Every reward is decided by
-- the attraction from what the server sees; nothing a screen says is a reward, a price or a place.
export type Ctx = {
	cfg: (id: string) -> { [string]: any },
	rng: Random,
	folder: () -> Instance, -- where the attractions' places are built (Workspace.Attractions)
	rootOf: (player: Player) -> BasePart?,
	trusted: (player: Player) -> boolean, -- not just after a move nobody could make (server/Integrity)
	moved: (player: Player) -> (), -- the house moved them: their next step isn't a jump of their own
	teleport: (player: Player, cf: CFrame) -> boolean,
	sendHome: (player: Player, id: string) -> (), -- back to the attraction's room off the Foyer
	inside: (player: Player) -> string?, -- the attraction a guest is in now
	at: (player: Player, id: string) -> Vector3?, -- where a guest stands, from the attraction's origin
	data: (player: Player) -> any?, -- the guest's saved record
	saved: (data: any, id: string) -> { [string]: any }, -- the attraction's page in it
	estate: (player: Player, worth: number, source: string, cash: boolean?) -> number, -- to the Estate (and Gilt)
	gilt: (player: Player, amount: number, source: string) -> number, -- earned Gilt (Gilt.pay)
	spend: (player: Player, gilt: number, gems: number, sink: string) -> boolean, -- pays a price (or nothing)
	gems: (player: Player, amount: number, source: string, id: string) -> number, -- within the day's cap
	curio: (player: Player, id: string, source: string) -> boolean,
	herald: (player: Player, feat: Feat) -> boolean,
	send: (player: Player, message: { [string]: any }) -> (),
	broadcast: (message: { [string]: any }) -> (),
	notice: (player: Player, title: string, line: string) -> (),
	tally: (player: Player, stat: string, n: number, once: string?) -> (),
	award: (player: Player, key: string) -> (),
	progress: (player: Player, kind: string, n: number) -> (), -- the day's and the week's objectives
	setSpeed: (player: Player, multiplier: number?) -> (), -- the "SpeedTrained" attribute (nil: none)
	isOwner: (player: Player) -> boolean,
	fortune: (player: Player) -> (), -- work a guest's Fortune out again now
}

-- An attraction. Built once when the house opens; a beat ten times a second.
export type Game = {
	build: (ctx: Ctx, parent: Instance) -> (),
	-- A guest asks to go in: where they arrive, or nil and why not.
	enter: (ctx: Ctx, player: Player) -> (CFrame?, string?),
	-- A guest has left it ("home", "respawn", "quit", "away": the house moved them elsewhere).
	leave: (ctx: Ctx, player: Player, why: string) -> (),
	step: (ctx: Ctx, dt: number) -> (),
	-- Its own requests (AttractionAsk with op "act").
	ask: ((ctx: Ctx, player: Player, r: { [string]: unknown }) -> any)?,
	-- What a guest's screen is told about their part in it.
	state: ((ctx: Ctx, player: Player) -> { [string]: any })?,
	-- A guest has just arrived in the house (their saved record is ready).
	arrived: ((ctx: Ctx, player: Player) -> ())?,
	-- Whether it's closed to a guest for now (its entrance then opens its board, to say how).
	locked: ((ctx: Ctx, player: Player) -> boolean)?,
}

return Types
