--!strict
-- Builds the snowy porch scene and its attachment markers at runtime so the
-- Rojo project needs no binary place file.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local SNOW = Color3.fromRGB(238, 244, 250)
local WOOD = Color3.fromRGB(92, 64, 46)
local WALL = Color3.fromRGB(70, 82, 104)

local function part(parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = material or Enum.Material.Wood
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Dusk lighting
Lighting.ClockTime = 17.6
Lighting.Brightness = 1
Lighting.Ambient = Color3.fromRGB(52, 58, 86)
Lighting.OutdoorAmbient = Color3.fromRGB(70, 76, 108)
Lighting.ColorShift_Top = Color3.fromRGB(255, 170, 120)
Lighting.EnvironmentDiffuseScale = 0.4
Lighting.EnvironmentSpecularScale = 0.2
for _, c in ipairs(Lighting:GetChildren()) do
	if c:IsA("Atmosphere") or c:IsA("Sky") then
		c:Destroy()
	end
end
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.32
atmosphere.Offset = 0.25
atmosphere.Color = Color3.fromRGB(190, 170, 200)
atmosphere.Decay = Color3.fromRGB(120, 100, 150)
atmosphere.Parent = Lighting

for _, c in ipairs(Workspace:GetChildren()) do
	if c:IsA("Terrain") == false and (c.Name == "Baseplate" or c:IsA("SpawnLocation")) then
		c:Destroy()
	end
end

local porch = Instance.new("Folder")
porch.Name = "Porch"
porch.Parent = Workspace

part(porch, "SnowGround", Vector3.new(160, 1, 160), Vector3.new(0, -0.5, 20), SNOW, Enum.Material.Snow)
part(porch, "Floor", Vector3.new(20, 1, 10), Vector3.new(0, 0.5, 0), WOOD)
part(porch, "FloorSnow", Vector3.new(19, 0.15, 9), Vector3.new(0, 1.07, 0), SNOW, Enum.Material.Snow)
part(porch, "Steps", Vector3.new(6, 0.5, 2), Vector3.new(0, 0.25, 6.5), WOOD)

local wall = part(porch, "Wall", Vector3.new(24, 13, 1), Vector3.new(0, 6.5, -5), WALL, Enum.Material.WoodPlanks)
wall.Name = "HouseWall"
part(porch, "DoorFrame", Vector3.new(5, 8, 0.4), Vector3.new(0, 5, -4.4), Color3.fromRGB(40, 30, 28))
part(porch, "Door", Vector3.new(4, 7.2, 0.3), Vector3.new(0, 4.6, -4.2), Color3.fromRGB(120, 38, 38))

for _, x in ipairs({ -9, 9 }) do
	part(porch, "Post", Vector3.new(1, 10, 1), Vector3.new(x, 6, 5), WOOD)
	part(porch, "PostSnow", Vector3.new(1.2, 0.3, 1.2), Vector3.new(x, 11.1, 5), SNOW, Enum.Material.Snow)
end
part(porch, "EaveBeam", Vector3.new(20, 1, 1), Vector3.new(0, 11, 5), WOOD)
part(porch, "Roof", Vector3.new(22, 0.8, 12.5), Vector3.new(0, 11.9, -0.2), Color3.fromRGB(58, 46, 46))
part(porch, "RoofSnow", Vector3.new(22.4, 0.7, 12.9), Vector3.new(0, 12.6, -0.2), SNOW, Enum.Material.Snow)
part(porch, "Finial", Vector3.new(0.6, 2.6, 0.6), Vector3.new(0, 13.3, 5), WOOD)
part(porch, "RailTop", Vector3.new(18, 0.4, 0.5), Vector3.new(0, 3.4, 5), WOOD)
part(porch, "RailSnow", Vector3.new(18, 0.15, 0.55), Vector3.new(0, 3.68, 5), SNOW, Enum.Material.Snow)
for i = -8, 8, 2 do
	part(porch, "Baluster", Vector3.new(0.3, 2.4, 0.3), Vector3.new(i, 2.2, 5), WOOD)
end

-- Warm wall lantern so the porch has a light source before any strand exists.
local lantern = part(porch, "Lantern", Vector3.new(0.7, 1.1, 0.7), Vector3.new(-5.5, 6, -4.3), Color3.fromRGB(255, 200, 130), Enum.Material.Neon)
local lanternLight = Instance.new("PointLight")
lanternLight.Color = Color3.fromRGB(255, 190, 110)
lanternLight.Range = 14
lanternLight.Brightness = 1.2
lanternLight.Parent = lantern

local spawn = Instance.new("SpawnLocation")
spawn.Anchored = true
spawn.Neutral = true
spawn.Size = Vector3.new(8, 1, 8)
spawn.Position = Vector3.new(0, 0.5, 20)
spawn.Color = SNOW
spawn.Material = Enum.Material.Snow
spawn.Parent = porch

-- Falling snow
local emitterPart = Instance.new("Part")
emitterPart.Name = "SnowEmitter"
emitterPart.Anchored = true
emitterPart.CanCollide = false
emitterPart.CanQuery = false
emitterPart.Transparency = 1
emitterPart.Size = Vector3.new(60, 1, 50)
emitterPart.Position = Vector3.new(0, 30, 10)
emitterPart.Parent = porch
local snow = Instance.new("ParticleEmitter")
snow.Rate = 60
snow.Lifetime = NumberRange.new(6, 8)
snow.Speed = NumberRange.new(5, 8)
snow.EmissionDirection = Enum.NormalId.Bottom
snow.Size = NumberSequence.new(0.18)
snow.LightEmission = 0.4
snow.Acceleration = Vector3.new(1.5, 0, 0)
snow.Parent = emitterPart

-- Attachment markers: small glowing bead + a large invisible hit zone for touch.
local markers = Instance.new("Folder")
markers.Name = "AnchorMarkers"
markers.Parent = porch
for _, a in ipairs(Config.ANCHORS) do
	local pos = Vector3.new(a.x, a.y, a.z)
	local bead = Instance.new("Part")
	bead.Name = a.id
	bead.Shape = Enum.PartType.Ball
	bead.Size = Vector3.new(1, 1, 1)
	bead.Position = pos
	bead.Anchored = true
	bead.CanCollide = false
	bead.CanQuery = false
	bead.CanTouch = false
	bead.CastShadow = false
	bead.Material = Enum.Material.Neon
	bead.Color = Color3.fromRGB(120, 220, 255)
	bead:SetAttribute("AnchorId", a.id)
	bead:SetAttribute("Label", a.label)
	bead.Parent = markers
	CollectionService:AddTag(bead, "LightAnchor")
end
