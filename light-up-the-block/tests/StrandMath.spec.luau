--!strict
-- Run: luau tests/StrandMath.spec.luau   (from light-up-the-block/)
local StrandMath = require("../src/shared/StrandMath")

local failures = 0
local function check(name: string, cond: boolean)
	if cond then
		print("PASS " .. name)
	else
		failures += 1
		print("FAIL " .. name)
	end
end

local anchors = {
	a = { x = 0, y = 0, z = 0 },
	b = { x = 10, y = 0, z = 0 },
	c = { x = 1, y = 0, z = 0 },
	d = { x = 100, y = 0, z = 0 },
}

check("valid pair", (StrandMath.validatePair("a", "b", anchors, 3, 26)))
check("same point rejected", not (StrandMath.validatePair("a", "a", anchors, 3, 26)))
check("unknown id rejected", not (StrandMath.validatePair("a", "zzz", anchors, 3, 26)))
check("non-string rejected", not (StrandMath.validatePair(nil, 5, anchors, 3, 26)))
check("table id rejected", not (StrandMath.validatePair({}, "a", anchors, 3, 26)))
check("too close rejected", not (StrandMath.validatePair("a", "c", anchors, 3, 26)))
check("too far rejected", not (StrandMath.validatePair("a", "d", anchors, 3, 26)))

local pts = StrandMath.curve(anchors.a, anchors.b, 18, 0.13)
check("curve endpoints", pts[1].x == 0 and math.abs(pts[19].x - 10) < 1e-9)
local mid = pts[10]
check("curve sags below chord", math.abs(mid.y - -1.3) < 1e-9)
check("curve longer than chord", StrandMath.polylineLength(pts) > 10)

local bulbs = StrandMath.bulbPositions(pts, 1.3)
check("bulb count reasonable", #bulbs >= 6 and #bulbs <= 10)
local minGap, maxGap = math.huge, 0
for i = 2, #bulbs do
	local d = StrandMath.distance(bulbs[i - 1], bulbs[i])
	minGap, maxGap = math.min(minGap, d), math.max(maxGap, d)
end
check("bulb spacing even", maxGap - minGap < 0.15)

if failures > 0 then
	error(failures .. " test(s) failed")
end
print("ALL PASSED")
