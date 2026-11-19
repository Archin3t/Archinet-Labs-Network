--!strict
-- Pure math (no Roblox types) so it can be unit-tested outside Studio.
local StrandMath = {}

export type Point = { x: number, y: number, z: number }

function StrandMath.distance(a: Point, b: Point): number
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Parabolic sag between two points; the cable hangs lowest at the middle.
function StrandMath.curve(a: Point, b: Point, segments: number, sagRatio: number): { Point }
	local span = StrandMath.distance(a, b)
	local sag = span * sagRatio
	local pts = {}
	for i = 0, segments do
		local t = i / segments
		pts[#pts + 1] = {
			x = a.x + (b.x - a.x) * t,
			y = a.y + (b.y - a.y) * t - sag * 4 * t * (1 - t),
			z = a.z + (b.z - a.z) * t,
		}
	end
	return pts
end

function StrandMath.polylineLength(pts: { Point }): number
	local total = 0
	for i = 2, #pts do
		total += StrandMath.distance(pts[i - 1], pts[i])
	end
	return total
end

-- Points spaced evenly by arc length along the curve (bulb positions), inset from the ends.
function StrandMath.bulbPositions(pts: { Point }, spacing: number): { Point }
	local total = StrandMath.polylineLength(pts)
	local count = math.max(2, math.floor(total / spacing))
	local step = total / count
	local out: { Point } = {}
	local seg, segStart = 1, 0
	for n = 1, count - 1 do
		local target = n * step
		while seg < #pts - 1 and segStart + StrandMath.distance(pts[seg], pts[seg + 1]) < target do
			segStart += StrandMath.distance(pts[seg], pts[seg + 1])
			seg += 1
		end
		local p, q = pts[seg], pts[seg + 1]
		local len = StrandMath.distance(p, q)
		local f = if len > 0 then (target - segStart) / len else 0
		out[#out + 1] = { x = p.x + (q.x - p.x) * f, y = p.y + (q.y - p.y) * f, z = p.z + (q.z - p.z) * f }
	end
	return out
end

-- Returns ok, reason. `existing` is a list of {a, b} id pairs this player already placed.
function StrandMath.validatePair(
	idA: any, idB: any, anchors: { [string]: Point },
	minSpan: number, maxSpan: number
): (boolean, string?)
	if type(idA) ~= "string" or type(idB) ~= "string" then
		return false, "Invalid request."
	end
	local a, b = anchors[idA], anchors[idB]
	if not a or not b then
		return false, "Unknown attachment point."
	end
	if idA == idB then
		return false, "Pick two different points."
	end
	local d = StrandMath.distance(a, b)
	if d < minSpan then
		return false, "Points are too close together."
	end
	if d > maxSpan then
		return false, "Points are too far apart."
	end
	return true, nil
end

return StrandMath
