--!strict
-- Porch layout and rules shared by server (authority) and client (preview/UI).
-- Porch is centered at the origin: X runs along the porch front, Z points toward the street.

export type Anchor = { id: string, label: string, x: number, y: number, z: number }

local Config = {}

Config.MIN_SPAN = 3
Config.MAX_SPAN = 26
Config.MAX_STRANDS_PER_PLAYER = 4
Config.MAX_STRANDS_TOTAL = 24
Config.BULB_SPACING = 1.3
Config.SAG_RATIO = 0.13 -- sag depth as a fraction of span
Config.COLOR_MODES = { "warm", "multi" }
Config.REQUEST_COOLDOWN = 0.25

Config.WARM = Color3.fromRGB(255, 190, 105)
Config.MULTI = {
	Color3.fromRGB(255, 70, 70),
	Color3.fromRGB(255, 170, 40),
	Color3.fromRGB(70, 220, 110),
	Color3.fromRGB(70, 150, 255),
	Color3.fromRGB(210, 90, 255),
}

Config.ANCHORS = {
	{ id = "eave_L",   label = "Left eave",       x = -9,   y = 11,  z = 5 },
	{ id = "eave_ML",  label = "Mid-left eave",   x = -4.5, y = 11,  z = 5 },
	{ id = "eave_MR",  label = "Mid-right eave",  x = 4.5,  y = 11,  z = 5 },
	{ id = "eave_R",   label = "Right eave",      x = 9,    y = 11,  z = 5 },
	{ id = "post_L",   label = "Left post",       x = -9,   y = 5.5, z = 5 },
	{ id = "post_R",   label = "Right post",      x = 9,    y = 5.5, z = 5 },
	{ id = "door_L",   label = "Door left",       x = -2.2, y = 9,   z = -4.6 },
	{ id = "door_R",   label = "Door right",      x = 2.2,  y = 9,   z = -4.6 },
	{ id = "rail_L",   label = "Railing left",    x = -4.5, y = 3.4, z = 5 },
	{ id = "rail_R",   label = "Railing right",   x = 4.5,  y = 3.4, z = 5 },
	{ id = "gable",    label = "Roof peak",       x = 0,    y = 14,  z = 5 },
} :: { Anchor }

return Config
