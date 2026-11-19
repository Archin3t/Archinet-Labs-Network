--!strict
-- Client: tap-to-pick attachment points, local-only preview, confirm / undo UI.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local StrandBuilder = require(ReplicatedStorage.Shared.StrandBuilder)
local StrandMath = require(ReplicatedStorage.Shared.StrandMath)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local placeRemote = remotes:WaitForChild("PlaceStrand") :: RemoteFunction
local undoRemote = remotes:WaitForChild("UndoStrand") :: RemoteFunction
local strandsFolder = Workspace:WaitForChild("Strands")

-- Generous picking radius in pixels: the nearest point within it wins, no precise tap needed.
local PICK_RADIUS_TOUCH = 110
local PICK_RADIUS_MOUSE = 70
local TAP_MAX_MOVE = 14
local TAP_MAX_TIME = 0.45

local COLOR_IDLE = Color3.fromRGB(120, 220, 255)
local COLOR_SELECTED = Color3.fromRGB(255, 214, 90)

type Marker = { part: Part, ring: Frame, stroke: UIStroke, tag: TextLabel }

local anchorById: { [string]: StrandMath.Point } = {}
for _, a in ipairs(Config.ANCHORS) do
	anchorById[a.id] = { x = a.x, y = a.y, z = a.z }
end

local state: "idle" | "first" | "preview" = "idle"
local selA: string? = nil
local selB: string? = nil
local colorMode = "warm"
local busy = false
local previewModel: Model? = nil
local myCount = 0

-- UI ------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "DecoratorUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.AnchorPoint = Vector2.new(0.5, 0)
hint.Position = UDim2.new(0.5, 0, 0, 12)
hint.Size = UDim2.new(0.92, 0, 0, 52)
hint.BackgroundColor3 = Color3.fromRGB(16, 20, 34)
hint.BackgroundTransparency = 0.2
hint.TextColor3 = Color3.fromRGB(255, 244, 220)
hint.Font = Enum.Font.GothamMedium
hint.TextScaled = true
hint.TextWrapped = true
hint.Parent = gui
Instance.new("UICorner", hint).CornerRadius = UDim.new(0, 12)
local hintLimit = Instance.new("UISizeConstraint")
hintLimit.MaxSize = Vector2.new(620, 60)
hintLimit.Parent = hint
local hintPad = Instance.new("UIPadding")
hintPad.PaddingLeft = UDim.new(0, 12)
hintPad.PaddingRight = UDim.new(0, 12)
hintPad.PaddingTop = UDim.new(0, 6)
hintPad.PaddingBottom = UDim.new(0, 6)
hintPad.Parent = hint

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -112)
toast.Size = UDim2.new(0.8, 0, 0, 40)
toast.BackgroundColor3 = Color3.fromRGB(16, 20, 34)
toast.BackgroundTransparency = 1
toast.TextTransparency = 1
toast.TextColor3 = Color3.fromRGB(255, 200, 150)
toast.Font = Enum.Font.GothamBold
toast.TextScaled = true
toast.Parent = gui
Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)
local toastLimit = Instance.new("UISizeConstraint")
toastLimit.MaxSize = Vector2.new(520, 44)
toastLimit.Parent = toast

local bar = Instance.new("Frame")
bar.Name = "Controls"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -28)
bar.Size = UDim2.new(0.96, 0, 0, 72)
bar.BackgroundTransparency = 1
bar.Parent = gui
local barLimit = Instance.new("UISizeConstraint")
barLimit.MaxSize = Vector2.new(600, 72)
barLimit.Parent = bar
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0.015, 0)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Parent = bar

local function makeButton(name: string, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.new(0.235, 0, 1, 0)
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = bar
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 14)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.Parent = b
	return b
end

local confirmBtn = makeButton("Confirm", "Confirm", Color3.fromRGB(46, 150, 90))
local cancelBtn = makeButton("Cancel", "Cancel", Color3.fromRGB(150, 70, 70))
local colorBtn = makeButton("Color", "Warm", Color3.fromRGB(190, 120, 40))
local undoBtn = makeButton("Undo", "Undo", Color3.fromRGB(70, 90, 140))

if not UserInputService.TouchEnabled then
	local keys = Instance.new("TextLabel")
	keys.Name = "KeyHint"
	keys.AnchorPoint = Vector2.new(0.5, 1)
	keys.Position = UDim2.new(0.5, 0, 1, -6)
	keys.Size = UDim2.new(0, 420, 0, 18)
	keys.BackgroundTransparency = 1
	keys.TextColor3 = Color3.fromRGB(200, 205, 225)
	keys.Font = Enum.Font.Gotham
	keys.TextSize = 14
	keys.Text = "Click a point  |  E confirm  |  X cancel  |  C color  |  Z undo"
	keys.Parent = gui
end

local toastToken = 0
local function say(text: string)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.TextTransparency = 0
	toast.BackgroundTransparency = 0.25
	task.delay(2.2, function()
		if token == toastToken then
			TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		end
	end)
end

-- Markers --------------------------------------------------------------------
local markers: { [string]: Marker } = {}

local function setupMarker(part: Instance)
	if not part:IsA("Part") then
		return
	end
	local id = part:GetAttribute("AnchorId")
	if type(id) ~= "string" or markers[id] then
		return
	end
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(64, 64)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.Adornee = part
	board.Parent = part
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(34, 34)
	ring.BackgroundColor3 = COLOR_IDLE
	ring.BackgroundTransparency = 0.82
	ring.Parent = board
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLOR_IDLE
	stroke.Thickness = 2
	stroke.Parent = ring
	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.fromScale(1, 1)
	tag.BackgroundTransparency = 1
	tag.Font = Enum.Font.GothamBold
	tag.TextScaled = true
	tag.TextColor3 = Color3.fromRGB(20, 20, 20)
	tag.Text = ""
	tag.Parent = ring
	markers[id] = { part = part, ring = ring, stroke = stroke, tag = tag }
end

local function styleMarker(id: string, label: string?)
	local m = markers[id]
	if not m then
		return
	end
	local selected = label ~= nil
	local color = if selected then COLOR_SELECTED else COLOR_IDLE
	m.part.Color = color
	m.tag.Text = label or ""
	TweenService:Create(m.ring, TweenInfo.new(0.18, Enum.EasingStyle.Back), {
		Size = if selected then UDim2.fromOffset(60, 60) else UDim2.fromOffset(34, 34),
		BackgroundColor3 = color,
		BackgroundTransparency = if selected then 0.15 else 0.82,
	}):Play()
	m.stroke.Color = color
	m.stroke.Thickness = if selected then 4 else 2
	m.part.Size = if selected then Vector3.new(1.6, 1.6, 1.6) else Vector3.new(1, 1, 1)
end

for _, p in ipairs(CollectionService:GetTagged("LightAnchor")) do
	setupMarker(p)
end
CollectionService:GetInstanceAddedSignal("LightAnchor"):Connect(setupMarker)

-- State rendering ---------------------------------------------------------------
local function labelOf(id: string?): string
	for _, a in ipairs(Config.ANCHORS) do
		if a.id == id then
			return a.label
		end
	end
	return "?"
end

local function clearPreview()
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end
end

local function render()
	for id in pairs(markers) do
		styleMarker(id, if id == selA then "A" elseif id == selB then "B" else nil)
	end
	clearPreview()
	if state == "preview" and selA and selB then
		local a, b = anchorById[selA], anchorById[selB]
		local model = StrandBuilder.build(Vector3.new(a.x, a.y, a.z), Vector3.new(b.x, b.y, b.z), colorMode, true)
		model.Parent = Workspace
		previewModel = model
	end

	if state == "idle" then
		hint.Text = "Tap a glowing point on the porch to start a light strand"
	elseif state == "first" then
		hint.Text = "Start: " .. labelOf(selA) .. ". Now tap the other end"
	else
		hint.Text = "Preview (only you see it): tap Confirm, or tap another point to move end B"
	end

	local previewing = state == "preview"
	confirmBtn.Visible = previewing
	cancelBtn.Visible = state ~= "idle"
	colorBtn.Text = if colorMode == "warm" then "Warm white" else "Multicolor"
	undoBtn.Active = myCount > 0
	undoBtn.AutoButtonColor = myCount > 0
	undoBtn.BackgroundTransparency = if myCount > 0 then 0 else 0.6
end

local function reset()
	state, selA, selB = "idle", nil, nil
	render()
end

-- Picking -------------------------------------------------------------------------
local function pickAnchor(screenPos: Vector2, radius: number): string?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local best, bestDist = nil, radius
	for id, m in pairs(markers) do
		local pt, onScreen = camera:WorldToScreenPoint(m.part.Position)
		if onScreen then
			local d = (Vector2.new(pt.X, pt.Y) - screenPos).Magnitude
			if d < bestDist then
				best, bestDist = id, d
			end
		end
	end
	return best
end

local function handleTap(screenPos: Vector2, isTouch: boolean)
	if busy then
		return
	end
	local id = pickAnchor(screenPos, if isTouch then PICK_RADIUS_TOUCH else PICK_RADIUS_MOUSE)
	if not id then
		if state ~= "idle" then
			say("Tap closer to a glowing point")
		end
		return
	end

	if state == "idle" then
		selA, state = id, "first"
		render()
		return
	end

	if id == selA then
		say("That's the start point. Pick a different one")
		return
	end
	if state == "preview" and id == selB then
		say("Already the end point. Tap Confirm")
		return
	end

	local ok, reason = StrandMath.validatePair(selA, id, anchorById, Config.MIN_SPAN, Config.MAX_SPAN)
	if not ok then
		say(reason or "Can't connect those")
		return
	end
	selB, state = id, "preview"
	render()
end

local downInfo: { [InputObject]: { pos: Vector2, t: number } } = {}

UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if not processed then
			downInfo[input] = { pos = Vector2.new(input.Position.X, input.Position.Y), t = os.clock() }
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, _processed)
	local info = downInfo[input]
	if not info then
		return
	end
	downInfo[input] = nil
	local now = Vector2.new(input.Position.X, input.Position.Y)
	-- Ignore camera drags: only a short, nearly stationary press counts as a tap.
	if (now - info.pos).Magnitude <= TAP_MAX_MOVE and os.clock() - info.t <= TAP_MAX_TIME then
		handleTap(now, input.UserInputType == Enum.UserInputType.Touch)
	end
end)

-- Actions ------------------------------------------------------------------------------
local function confirm()
	if busy or state ~= "preview" or not selA or not selB then
		return
	end
	busy = true
	local ok, result = pcall(function()
		return placeRemote:InvokeServer(selA, selB, colorMode)
	end)
	busy = false
	if ok and type(result) == "table" and result.ok then
		say("Strand placed!")
		reset()
	else
		local reason = if ok and type(result) == "table" then result.reason else "Server unavailable"
		say(tostring(reason or "Couldn't place strand"))
	end
end

local function undo()
	if busy then
		return
	end
	if myCount == 0 then
		say("You have no strands to undo")
		return
	end
	busy = true
	local ok, result = pcall(function()
		return undoRemote:InvokeServer()
	end)
	busy = false
	if ok and type(result) == "table" and result.ok then
		say("Strand removed")
	else
		say("Nothing to undo")
	end
end

local function toggleColor()
	colorMode = if colorMode == "warm" then "multi" else "warm"
	render()
end

local function cancel()
	if state ~= "idle" then
		reset()
		say("Canceled")
	end
end

confirmBtn.Activated:Connect(confirm)
cancelBtn.Activated:Connect(cancel)
colorBtn.Activated:Connect(toggleColor)
undoBtn.Activated:Connect(undo)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local k = input.KeyCode
	if k == Enum.KeyCode.E then
		confirm()
	elseif k == Enum.KeyCode.X then
		cancel()
	elseif k == Enum.KeyCode.C then
		toggleColor()
	elseif k == Enum.KeyCode.Z then
		undo()
	end
end)

-- Track how many strands are mine (drives the Undo button) ------------------------------------
local function recount()
	local n = 0
	for _, s in ipairs(strandsFolder:GetChildren()) do
		if s:GetAttribute("OwnerUserId") == player.UserId then
			n += 1
		end
	end
	myCount = n
	render()
end
strandsFolder.ChildAdded:Connect(function(child)
	task.defer(recount)
	child:GetAttributeChangedSignal("OwnerUserId"):Connect(recount)
end)
strandsFolder.ChildRemoved:Connect(function()
	task.defer(recount)
end)
recount()
