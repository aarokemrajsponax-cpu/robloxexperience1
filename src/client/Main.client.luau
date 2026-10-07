--!strict
-- Maison Noir: client boot. Intro → title over the street → Play → the walk in → the table.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Build = require(ReplicatedStorage.Shared.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Speed = require(ReplicatedStorage.Shared.Speed)

local State = require(script.Parent.State)
local Root = require(script.Parent.UI.Root)
local Theme = require(script.Parent.UI.Theme)
local Sound = require(script.Parent.Sound)
local CameraRig = require(script.Parent.Camera)
local Intro = require(script.Parent.UI.Intro)
local Title = require(script.Parent.UI.Title)
local Dialogue = require(script.Parent.UI.Dialogue)
local Prompts = require(script.Parent.UI.Prompts)
local Hud = require(script.Parent.UI.Hud)
local Objective = require(script.Parent.UI.Objective)
local Toast = require(script.Parent.UI.Toast)
local SettingsPanel = require(script.Parent.UI.SettingsPanel)
local BoardPanel = require(script.Parent.UI.BoardPanel)
local HowToPlay = require(script.Parent.UI.HowToPlay)
local Invite = require(script.Parent.UI.Invite)
local Closet = require(script.Parent.Closet)
local BoutiquePanel = require(script.Parent.UI.BoutiquePanel)
local BlackCardPanel = require(script.Parent.UI.BlackCardPanel)
local SuitePanel = require(script.Parent.UI.SuitePanel)
local CirclePanel = require(script.Parent.UI.CirclePanel)
local SuiteView = require(script.Parent.World.SuiteView)
local SaluteView = require(script.Parent.World.SaluteView)
local EventBanner = require(script.Parent.UI.EventBanner)
local SortScreen = require(script.Parent.Table.SortScreen)
local AdmireCard = require(script.Parent.UI.AdmireCard)
local GuestBookPanel = require(script.Parent.UI.GuestBookPanel)
local RegularPlates = require(script.Parent.World.RegularPlates)
local AdminPanel = require(script.Parent.UI.AdminPanel)
local WardrobePanel = require(script.Parent.UI.WardrobePanel)
local LedgerPanel = require(script.Parent.UI.LedgerPanel)
local GiftPanel = require(script.Parent.UI.GiftPanel)
local RegisterPanel = require(script.Parent.UI.RegisterPanel)
local VaultView = require(script.Parent.World.VaultView)
local StaffLife = require(script.Parent.World.StaffLife)
local Counter = require(script.Parent.Table.Counter)
local TableClient = require(script.Parent.Table.TableClient)
local Ambient = require(script.Parent.World.Ambient)
local BallroomView = require(script.Parent.Table.BallroomView)
local Tour = require(script.Parent.World.Tour)
local Perks = require(script.Parent.Perks)
local PerkChips = require(script.Parent.UI.PerkChips)
local DecreePanel = require(script.Parent.UI.DecreePanel)
local CurioState = require(script.Parent.CurioState)
local CurioReveal = require(script.Parent.UI.CurioReveal)
local CuriosPanel = require(script.Parent.UI.CuriosPanel)
local MenuPanel = require(script.Parent.UI.MenuPanel)
local TradePanel = require(script.Parent.UI.TradePanel)
local PianoPanel = require(script.Parent.UI.PianoPanel)
local DecreeBanner = require(script.Parent.UI.DecreeBanner)
local RainView = require(script.Parent.World.RainView)

local player = Players.LocalPlayer

-- First of all: for the owner, anything that breaks shows on screen.
pcall(function()
	require(script.Parent.UI.ErrorNotice).start()
end)

-- Roblox's own chat stays. The house has no tools and no health bar, and no player list in
-- the top-right corner (it sat over the house's own keys; the boards show who's here).
for _, kind in { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.PlayerList } do
	pcall(function()
		StarterGui:SetCoreGuiEnabled(kind, false)
	end)
end

State.watch("movement", function(value)
	Ease.motionScale = if value == "Still" then 0 elseif value == "Calm" then 0.6 else 1
end)
Theme.onClick(Sound.ui)
Theme.onHover(Sound.hover)
Root.onDip(Sound.dip)
Sound.preload()
Theme.preloadFonts()

Closet.start()
pcall(function()
	require(script.Parent.NotifyAsk).start()
end)
Sound.wornChime = function()
	local style = Closet.style("chime")
	return if style then style.sound else nil
end
Closet.Message:Connect(function(op: string, m: any)
	if op == "open" then
		if m.panel == "boutique" then
			BoutiquePanel.open()
		elseif m.panel == "wardrobe" then
			WardrobePanel.open()
		elseif m.panel == "ledger" then
			LedgerPanel.open()
		elseif m.panel == "register" then
			RegisterPanel.open()
		elseif m.panel == "blackCard" then
			BlackCardPanel.open()
		elseif m.panel == "suite" then
			SuitePanel.open()
		elseif m.panel == "circles" then
			CirclePanel.open()
		elseif m.panel == "salutes" then
			BoutiquePanel.open("salutes")
		elseif m.panel == "guestBook" then
			GuestBookPanel.open()
		end
	elseif op == "gift" and type(m.item) == "table" then
		task.delay(2.5, GiftPanel.show, tostring(m.from), m.item)
	elseif op == "pages" and type(m.pages) == "table" then
		local last = m.pages[#m.pages]
		Toast.show("The Ledger", string.format("Page %d turned.", last or 0), 2.5)
	elseif op == "circleOffer" then
		CirclePanel.offer(m)
	elseif op == "notice" then
		Toast.show(tostring(m.title), tostring(m.line), 4)
	end
end)
-- Every part of the house on this screen starts on its own: one that fails is reported and the
-- rest carry on, so a guest can always walk in and play.
local function start(name: string, fn: () -> ()): boolean
	local message = ""
	local ok = xpcall(fn, function(e: any)
		message = debug.traceback(tostring(e))
	end)
	if not ok then
		warn(string.format("[Maison] %s didn't start on this screen: %s", name, message))
	end
	return ok
end
start("Dialogue", Dialogue.start)
if not start("Prompts", Prompts.start) then
	-- Without the house's own prompts, Roblox's standard ones: every Sit and Speak still works.
	local function plain(p: Instance)
		if p:IsA("ProximityPrompt") then
			p.Style = Enum.ProximityPromptStyle.Default
		end
	end
	for _, d in Workspace:GetDescendants() do
		plain(d)
	end
	Workspace.DescendantAdded:Connect(plain)
end
start("The Black Card", BlackCardPanel.start)
start("The counter", Counter.start)
start("Tables", TableClient.start)
start("The house around you", Ambient.start)
start("The Ballroom", BallroomView.start)
start("The Vault", VaultView.start)
start("The Suite", function()
	SuiteView.playPiano = PianoPanel.private
	SuiteView.start()
end)
start("Seats", require(script.Parent.World.Seating).start)
-- Curios, Gems, trading, and the Menu's tiles.
start("Curios", function()
	CurioState.start()
	TradePanel.start()
	CurioState.Message:Connect(function(op: string, m: any)
		if op == "found" and type(m.id) == "string" then
			CurioReveal.show(m.id, tostring(m.line or ""), if type(m.gilt) == "number" then m.gilt else 0)
		elseif op == "gems" and type(m.amount) == "number" then
			Toast.show("Gems", string.format("+%d Gems. You hold %d.", m.amount, CurioState.gems), 4)
		end
	end)
	AdmireCard.trade = TradePanel.invite
	-- The quick dock: Collection, Trade, Wardrobe and Gems, one tap away (C, T, V).
	local QuickDock = require(script.Parent.UI.QuickDock)
	QuickDock.openCollection = function()
		CuriosPanel.open("yours")
	end
	QuickDock.openTrades = function()
		CuriosPanel.open("trades")
	end
	QuickDock.openWardrobe = WardrobePanel.open
	QuickDock.openGems = function()
		CuriosPanel.open("gems")
	end
	QuickDock.invite = TradePanel.invite
	QuickDock.isSeated = function(): boolean
		return TableClient.isSeated() or Root.isOpen()
	end
	QuickDock.start()
	TableClient.Seated.Event:Connect(function()
		QuickDock.setSeated(true)
	end)
	TableClient.Left.Event:Connect(function()
		QuickDock.setSeated(false)
	end)
	for _, tile in {
		{ id = "collection", title = "Your Collection", line = "Your curios, every one to find, and the Cabinet.", glyph = "🏺", open = function()
			CuriosPanel.open("yours")
		end },
		{ id = "trading", title = "Trading", line = "Trade curios with another guest, and your past trades.", glyph = "🤝", open = function()
			CuriosPanel.open("trades")
		end },
		{ id = "gems", title = "Gems", line = "Gem packs, and what Gems buy in the Cabinet.", glyph = "💎", open = function()
			CuriosPanel.open("gems")
		end },
		{ id = "boutique", title = "The Boutique", line = "Looks, table styles, lamps and more. Style, never score.", glyph = "🛍️", open = function()
			BoutiquePanel.open()
		end },
		{ id = "wardrobe", title = "Your Wardrobe", line = "Wear what you own.", glyph = "👔", open = WardrobePanel.open },
		{ id = "ledger", title = "The Ledger", line = "This term's rewards, page by page.", glyph = "📖", open = LedgerPanel.open },
		{ id = "register", title = "The Register", line = "Achievements: the house's badges and your records.", glyph = "🏅", open = RegisterPanel.open },
		{ id = "guestbook", title = "The Livre d'Or", line = "Sign the guest book, and read who came.", glyph = "✒️", open = GuestBookPanel.open },
		{ id = "circle", title = "Your Circle", line = "Your club of friends in the house.", glyph = "⭕", open = CirclePanel.open },
		{ id = "help", title = "How to play", line = "The tables, the cases, and the house.", glyph = "❔", open = function()
			HowToPlay.open()
		end },
		{ id = "settings", title = "Settings", line = "Sound, camera, motion, and your perks.", glyph = "⚙️", open = SettingsPanel.open },
	} do
		MenuPanel.add(tile :: any)
	end
end)
start("Event effects", require(script.Parent.World.EventFX).start)
start("The Terrace Bar", function()
	require(script.Parent.UI.BarPanel).start()
	require(script.Parent.World.Treats).start()
end)
start("Salutes", SaluteView.start)
start("The lift", require(script.Parent.World.LiftView).start)
start("Events", EventBanner.start)
-- Purchases: the perks this guest holds, and what the whole house sees (decrees, rains).
start("Perks", function()
	Perks.Message:Connect(function(op: string, m: any)
		if op == "notice" then
			Toast.show(tostring(m.title), tostring(m.line), 4)
		elseif op == "decree" then
			DecreeBanner.decree(m)
		elseif op == "rain" then
			RainView.rain(m)
		elseif op == "rainShare" then
			RainView.share(m)
		elseif op == "spectacle" and type(m.key) == "string" then
			require(script.Parent.World.SuiteSpectacle).play(m.key, m.seconds)
		elseif op == "pianoOffer" then
			PianoPanel.offer()
		elseif op == "pianoEnd" then
			PianoPanel.ended(m)
		end
	end)
	Perks.start()
	PerkChips.openDecree = DecreePanel.open
	PerkChips.openPiano = PianoPanel.offer
	PianoPanel.zone = function(): string
		return Ambient.zone
	end
	PianoPanel.start()
	PerkChips.start()
	EventBanner.onSeatedLine = SortScreen.setEvent
	TableClient.Seated.Event:Connect(function()
		PerkChips.setHidden(true)
		EventBanner.setSeated(true)
	end)
	TableClient.Left.Event:Connect(function()
		PerkChips.setHidden(false)
		EventBanner.setSeated(false)
	end)
end)
AdmireCard.openBoutique = function(tab, forGuest)
	BoutiquePanel.open(tab, forGuest)
end
AdmireCard.isSeated = TableClient.isSeated
start("Admire", AdmireCard.start)
require(script.Parent.UI.BallroomPanel).openSalutes = function()
	BoutiquePanel.open("salutes")
end
start("Usual tables", RegularPlates.start)
start("Staff", StaffLife.start)

-- The player's own controls (Roblox's): taken away only at a table, in photo mode, or under the
-- optional title screen.
local controls: any = nil
local function getControls(): any
	if controls then
		return controls
	end
	local ok, module = pcall(function()
		return require((player:WaitForChild("PlayerScripts") :: any):WaitForChild("PlayerModule") :: ModuleScript) :: any
	end)
	if ok and module then
		controls = module:GetControls()
	end
	return controls
end
local function setControls(on: boolean)
	local c = getControls()
	if c then
		if on then
			c:Enable()
		else
			c:Disable()
		end
	end
end

-- Walk by default; hold Shift (or click the left stick) to run.
local running = false
local function applySpeed()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- One speed from every effect (Shared/Speed): the house's Quickstep event and VIP Velocity
		-- Elite (the server sets "SpeedPerk" only for a guest who owns it and hasn't switched it off).
		humanoid.WalkSpeed = Speed.resolve(running, Workspace:GetAttribute("SpeedBoost"), player:GetAttribute("SpeedPerk"))
	end
end
Workspace:GetAttributeChangedSignal("SpeedBoost"):Connect(function()
	applySpeed()
end)
player:GetAttributeChangedSignal("SpeedPerk"):Connect(function()
	applySpeed()
end)
ContextActionService:BindAction("MaisonRun", function(_, state, input)
	if input.KeyCode == Enum.KeyCode.ButtonL3 then
		if state == Enum.UserInputState.Begin then
			running = not running
		end
	else
		running = state == Enum.UserInputState.Begin
	end
	applySpeed()
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)

local function quickSit(mode: string?)
	if TableClient.isSeated() then
		return
	end
	task.spawn(function()
		local ok, seated = pcall(function()
			return Remotes.func("QuickSit"):InvokeServer(mode or "room")
		end)
		if not ok or not seated then
			Toast.show(if mode == "nightly" then "Tonight's table" else "The Salon", "Every table is taken. One will be free shortly.", 4)
		end
	end)
end

local hudStarted = false
local ownerKeyShown = false
local function startHud()
	if hudStarted then
		return
	end
	hudStarted = true
	Hud.start(SettingsPanel.open, TableClient.leave)
	Hud.setShopKey(function()
		BoutiquePanel.open()
	end)
	Hud.setMenuKey(MenuPanel.open)
	ContextActionService:BindAction("MaisonMenu", function(_, state)
		if state == Enum.UserInputState.Begin and not TableClient.isSeated() then
			MenuPanel.open()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.M)
	-- The owner's House controls: a key only they see (the server checks every request).
	local function ownerKey()
		if player:GetAttribute("MaisonAdmin") == true and not ownerKeyShown then
			ownerKeyShown = true
			Hud.setOwnerKey(AdminPanel.open)
			ContextActionService:BindAction("MaisonHouseControls", function(_, state)
				if state == Enum.UserInputState.Begin then
					AdminPanel.open()
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.KeyCode.Semicolon)
		end
	end
	ownerKey()
	player:GetAttributeChangedSignal("MaisonAdmin"):Connect(ownerKey)
	-- What to do next, under the keys while you walk.
	start("Objective", function()
		Objective.start(function(mode: string)
			quickSit(mode)
		end)
	end)
end

local function waitForCharacter(): Model
	local character = player.Character
	while not character or not character:FindFirstChild("HumanoidRootPart") do
		task.wait(0.1)
		character = player.Character
	end
	return character :: Model
end

local playing = false
local function onPlay(fromTitle: boolean?)
	if playing then
		return
	end
	playing = true
	Title.hide()
	State.funnel(2)
	waitForCharacter()
	if fromTitle then
		State.setPhase("handoff")
		CameraRig.handoff(1.6)
	else
		CameraRig.follow()
	end
	setControls(true)
	applySpeed()
	State.setPhase("play")
	State.funnel(3)
	startHud()
	local guest = State.guest
	local launch = if guest and type(guest.launch) == "string" then guest.launch else ""
	if launch == "nightly" then
		-- Arrived from a friend's Nightly invite: straight to tonight's table.
		task.delay(0.6, quickSit, "nightly")
	elseif launch == "salon" then
		-- A friend shared a Flawless round: straight to a Salon table.
		task.delay(0.6, quickSit, "room")
	elseif launch == "ballroom" then
		-- Arrived to watch a friend's evening: straight up to the Gallery.
		task.delay(0.6, quickSit, "ballroom")
	elseif launch == "soiree" then
		-- A Soirée notification: this weekend's format, straight to it.
		local format = game:GetService("Workspace"):GetAttribute("SoireeFormat")
		task.delay(0.6, quickSit, if format == "library" then "library" else "ballroom")
	elseif launch == "ledger" then
		-- The Term ends in three days: the Ledger, open.
		task.delay(0.8, LedgerPanel.open)
	elseif string.sub(launch, 1, 7) == "library" then
		-- Arrived from an invite to the Library: shown up to the friend's table.
		task.delay(0.6, quickSit, launch)
	elseif State.isFirstVisit() and not TableClient.isSeated() then
		Hud.showStraight(function()
			quickSit("room")
		end)
	end
end

-- The Concierge's tour: the last card's "Take me to a table", and it steps aside at a table.
Tour.toTable = function()
	quickSit("room")
end
Tour.isSeated = function(): boolean
	return TableClient.isSeated()
end
start("Tour", Tour.listen)

HowToPlay.onFinish = function()
	if TableClient.isSeated() then
		return
	end
	if not playing then
		task.spawn(onPlay)
		task.wait(1.8)
	end
	quickSit("room")
end

TableClient.Seated.Event:Connect(function()
	Hud.hideStraight()
end)
TableClient.Banked.Event:Connect(function(gilt: number)
	pcall(function()
		require(script.Parent.UI.OfferCard).afterRun(gilt)
	end)
end)

Remotes.event("Guest").OnClientEvent:Connect(function(message: any)
	if type(message) == "table" and message.op == "howto" then
		HowToPlay.open()
	elseif type(message) == "table" and message.op == "clubHowTo" then
		-- (On the Concierge's tour, the Club Floor is being explained already.)
		if not Tour.active() then
			task.delay(1, HowToPlay.open, true)
		end
	elseif type(message) == "table" and message.op == "inviteLibrary" then
		Invite.library()
	end
end)

-- A gesture from the Wardrobe: G, or up on the D-pad, while walking (and in photo mode).
local function playGesture(): boolean
	local style = Closet.style("gesture")
	local id = if style then (Config.data.Assets.Animations :: any)[style.animation] else nil
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if type(id) ~= "string" or id == "" or not animator then
		return false
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if ok and track then
		track:Play(0.2)
	end
	return true
end
ContextActionService:BindAction("MaisonGesture", function(_, state)
	if state ~= Enum.UserInputState.Begin or TableClient.isSeated() or Root.isOpen() then
		return Enum.ContextActionResult.Pass
	end
	return if playGesture() then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.G, Enum.KeyCode.DPadUp)

-- Photo mode (from Settings): the character stands still while the camera roams.
local PhotoMode = require(script.Parent.UI.PhotoMode)
PhotoMode.canEnter = function()
	return not TableClient.isSeated()
end
PhotoMode.onEnter = function()
	setControls(false)
end
PhotoMode.onExit = function()
	CameraRig.follow()
	setControls(true)
	applySpeed()
end
PhotoMode.gesture = function()
	if not playGesture() then
		Toast.show("Photo", "Gestures come from the Boutique and the Ledger; wear one in the Wardrobe.", 3)
	end
end

-- Respawns never replay the intro; they hand straight back to the follow camera.
player.CharacterAdded:Connect(function()
	if playing then
		task.wait(0.2)
		if not TableClient.isSeated() then
			CameraRig.follow()
			setControls(true)
			applySpeed()
		end
	end
end)

-- The title keeps its composed shot even if Roblox resets the camera when the avatar appears.
local function guardTitleCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	camera:GetPropertyChangedSignal("CameraType"):Connect(function()
		if (State.phase == "intro" or State.phase == "title") and camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
	end)
end

-- On the title, walking counts as Play: anyone who reaches for W, A, S, D or the arrows is
-- taken straight into the house with their own character.
local function walkToPlay()
	ContextActionService:BindAction("MaisonWalkToPlay", function(_, state)
		if state == Enum.UserInputState.Begin and State.phase == "title" and not Root.isOpen() then
			ContextActionService:UnbindAction("MaisonWalkToPlay")
			task.spawn(onPlay, true)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Space)
end

-- Boot. The client has started; a separate safety script (Failsafe) stands down.
player:SetAttribute("MaisonClient", "ready")
print(string.format("[Maison] %s (client)", Build.label))
if RunService:IsStudio() then
	-- In Studio, the build in the corner, to see at a glance that Studio has the latest code.
	pcall(function()
		local stamp = Instance.new("TextLabel")
		stamp.Name = "Build"
		stamp.BackgroundTransparency = 1
		stamp.AnchorPoint = Vector2.new(0, 1)
		stamp.Position = UDim2.new(0, 8, 1, -6)
		stamp.Size = UDim2.fromOffset(420, 16)
		stamp.TextXAlignment = Enum.TextXAlignment.Left
		stamp.TextSize = 12
		stamp.TextColor3 = Color3.fromRGB(200, 190, 160)
		stamp.TextTransparency = 0.3
		stamp.Text = Build.label
		stamp.Parent = Root.hud
		-- For the owner, in Studio: say so plainly when the music hasn't been brought in yet.
		task.delay(6, function()
			if not Sound.hasMusic() then
				Toast.show("No music", "The playlists in Config.Assets.Playlists are empty and no track is set.", 12)
			end
		end)
		-- Out of the way while sorting.
		TableClient.Seated.Event:Connect(function()
			stamp.Visible = false
		end)
		TableClient.Left.Event:Connect(function()
			stamp.Visible = true
		end)
	end)
end
if RunService:IsStudio() and Config.data.Studio.skipTitle then
	-- Testing in Studio: no intro, no title; straight into your own character and camera.
	Intro.clear()
	State.setPhase("play")
	task.spawn(onPlay, false)
elseif not Config.data.Title.show then
	-- The live game: you are your own character from the first second, with Roblox's camera and
	-- controls. The intro plays over the live house and any key, click or tap skips it.
	task.spawn(function()
		local ok = pcall(function()
			Intro.play(function()
				State.funnel(1)
			end)
		end)
		if not ok then
			pcall(Intro.clear)
		end
	end)
	State.setPhase("play")
	task.spawn(onPlay, false)
else
	-- The composed title screen over the street (Config.Title.show).
	setControls(false)
	State.setPhase("intro")
	CameraRig.titleDrift()
	guardTitleCamera()
	local okIntro = pcall(function()
		Intro.play(function()
			State.funnel(1)
		end)
	end)
	if not okIntro then
		warn("[Maison] The intro failed; going straight to the title.")
	end
	State.waitForWelcome(12)
	if not playing then
		State.setPhase("title")
		local okTitle, err = pcall(function()
			Title.show({
				play = function()
					onPlay(true)
				end,
				how = HowToPlay.open,
				board = BoardPanel.open,
			})
		end)
		if okTitle then
			walkToPlay()
		else
			-- Never leave a guest stuck behind a broken title: hand them their character.
			warn("[Maison] The title failed; playing straight away:", err)
			task.spawn(onPlay, true)
		end
	end
end
-- A last guard: if a guest is somehow still without their character after a minute (a title
-- that never drew, a panel stuck over it), give them the house anyway.
task.delay(60, function()
	if not playing and not Title.isShowing() then
		warn("[Maison] Still not playing after a minute; handing over the character.")
		onPlay(true)
	end
end)
