--!strict
-- Builds the physical strand (cable + bulbs). Used by the server for final strands
-- and by the client for the local-only preview.
local Config = require(script.Parent.Config)
local StrandMath = require(script.Parent.StrandMath)

local StrandBuilder = {}

local SEGMENTS = 18

local function toPoint(v: Vector3): StrandMath.Point
	return { x = v.X, y = v.Y, z = v.Z }
end

local function toVec(p: StrandMath.Point): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

function StrandBuilder.build(a: Vector3, b: Vector3, colorMode: string, preview: boolean): Model
	local model = Instance.new("Model")
	model.Name = if preview then "StrandPreview" else "Strand"

	local pts = StrandMath.curve(toPoint(a), toPoint(b), SEGMENTS, Config.SAG_RATIO)
	local fade = if preview then 0.45 else 0

	for i = 1, #pts - 1 do
		local p, q = toVec(pts[i]), toVec(pts[i + 1])
		local cable = Instance.new("Part")
		cable.Name = "Cable"
		cable.Anchored = true
		cable.CanCollide = false
		cable.CanQuery = false
		cable.CanTouch = false
		cable.CastShadow = false
		cable.Material = Enum.Material.SmoothPlastic
		cable.Color = Color3.fromRGB(22, 40, 28)
		cable.Transparency = fade
		cable.Size = Vector3.new(0.1, 0.1, (q - p).Magnitude + 0.04)
		cable.CFrame = CFrame.lookAt((p + q) / 2, q)
		cable.Parent = model
	end

	local bulbs = StrandMath.bulbPositions(pts, Config.BULB_SPACING)
	for i, bp in ipairs(bulbs) do
		local color = if colorMode == "multi" then Config.MULTI[(i - 1) % #Config.MULTI + 1] else Config.WARM
		local bulb = Instance.new("Part")
		bulb.Name = "Bulb"
		bulb.Shape = Enum.PartType.Ball
		bulb.Size = Vector3.new(0.38, 0.38, 0.38)
		bulb.Anchored = true
		bulb.CanCollide = false
		bulb.CanQuery = false
		bulb.CanTouch = false
		bulb.CastShadow = false
		bulb.Material = Enum.Material.Neon
		bulb.Color = color
		bulb.Transparency = if preview then 0.35 else 0
		-- Hang the bulb slightly below the cable so it reads as a bulb on a wire.
		bulb.Position = toVec(bp) - Vector3.new(0, 0.22, 0)
		bulb.Parent = model

		-- Real lights on every 3rd bulb only, to keep the lighting budget sane.
		if not preview and i % 3 == 1 then
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 9
			light.Brightness = 1.1
			light.Shadows = false
			light.Parent = bulb
		end
	end

	return model
end

return StrandBuilder
