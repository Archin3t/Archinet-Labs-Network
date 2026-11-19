--!strict
-- Server authority for strands: validates every request, builds the strand for
-- everyone, and owns undo. Previews never touch the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local StrandBuilder = require(ReplicatedStorage.Shared.StrandBuilder)
local StrandMath = require(ReplicatedStorage.Shared.StrandMath)

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local placeRemote = Instance.new("RemoteFunction")
placeRemote.Name = "PlaceStrand"
placeRemote.Parent = remotes
local undoRemote = Instance.new("RemoteFunction")
undoRemote.Name = "UndoStrand"
undoRemote.Parent = remotes

local strandsFolder = Instance.new("Folder")
strandsFolder.Name = "Strands"
strandsFolder.Parent = Workspace

local anchorById: { [string]: StrandMath.Point } = {}
for _, a in ipairs(Config.ANCHORS) do
	anchorById[a.id] = { x = a.x, y = a.y, z = a.z }
end

type Placed = { model: Model, pair: string }
local placedByUser: { [number]: { Placed } } = {}
local lastRequest: { [number]: number } = {}
local totalStrands = 0

local function pairKey(a: string, b: string): string
	if a < b then
		return a .. "|" .. b
	end
	return b .. "|" .. a
end

local function throttled(player: Player): boolean
	local now = os.clock()
	local last = lastRequest[player.UserId]
	if last and now - last < Config.REQUEST_COOLDOWN then
		return true
	end
	lastRequest[player.UserId] = now
	return false
end

local function validColorMode(mode: any): boolean
	return table.find(Config.COLOR_MODES, mode) ~= nil
end

placeRemote.OnServerInvoke = function(player: Player, idA: any, idB: any, colorMode: any)
	if throttled(player) then
		return { ok = false, reason = "Slow down a moment." }
	end
	local ok, reason = StrandMath.validatePair(idA, idB, anchorById, Config.MIN_SPAN, Config.MAX_SPAN)
	if not ok then
		return { ok = false, reason = reason }
	end
	if not validColorMode(colorMode) then
		return { ok = false, reason = "Invalid color." }
	end

	local list = placedByUser[player.UserId]
	if not list then
		list = {}
		placedByUser[player.UserId] = list
	end
	if #list >= Config.MAX_STRANDS_PER_PLAYER then
		return { ok = false, reason = "Strand limit reached. Undo one first." }
	end
	if totalStrands >= Config.MAX_STRANDS_TOTAL then
		return { ok = false, reason = "The porch is full." }
	end
	local key = pairKey(idA, idB)
	for _, p in ipairs(list) do
		if p.pair == key then
			return { ok = false, reason = "You already have a strand there." }
		end
	end

	local a, b = anchorById[idA], anchorById[idB]
	local model = StrandBuilder.build(Vector3.new(a.x, a.y, a.z), Vector3.new(b.x, b.y, b.z), colorMode, false)
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = strandsFolder
	table.insert(list, { model = model, pair = key })
	totalStrands += 1
	return { ok = true, count = #list }
end

local function removeLast(userId: number): boolean
	local list = placedByUser[userId]
	if not list or #list == 0 then
		return false
	end
	local last = table.remove(list) :: Placed
	last.model:Destroy()
	totalStrands -= 1
	return true
end

undoRemote.OnServerInvoke = function(player: Player)
	if throttled(player) then
		return { ok = false, reason = "Slow down a moment." }
	end
	if not removeLast(player.UserId) then
		return { ok = false, reason = "Nothing to undo." }
	end
	local list = placedByUser[player.UserId]
	return { ok = true, count = if list then #list else 0 }
end

Players.PlayerRemoving:Connect(function(player)
	while removeLast(player.UserId) do
	end
	placedByUser[player.UserId] = nil
	lastRequest[player.UserId] = nil
end)
