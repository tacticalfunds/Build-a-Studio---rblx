--[[
	PanelTheme: shared look for NEW builder UI, transcribed from the live
	PodcastStudioPanel (see docs/ui-contract.md). Values here must match that
	contract exactly; the existing panel source is not modified.

	Pure part (tested): tokens, layout constants, fit() and clamp().
	Roblox part: small constructors that apply the tokens to Instances.
]]

local PanelTheme = {}

-- C = { bg, card, teal, white, muted } plus the drawer stroke, as RGB triples.
PanelTheme.Colors = {
	bg = { 16, 24, 29 },
	card = { 31, 43, 49 },
	teal = { 91, 224, 198 },
	white = { 237, 235, 225 },
	muted = { 155, 175, 180 },
	stroke = { 66, 89, 94 },
}

PanelTheme.FontName = "GothamMedium"

PanelTheme.TextSize = {
	button = 12,
	heading = 13,
	description = 10,
	body = 12,
	title = 17,
	status = 11,
	handle = 9,
}

PanelTheme.Drawer = {
	transparency = 0.015,
	radius = 14,
	strokeTransparency = 0.25,
}

PanelTheme.ButtonRadius = 8

PanelTheme.Layout = {
	headerX = 18, headerY = 13, titleHeight = 24,
	statusX = 18, statusY = 39,
	handleText = "DRAG TO MOVE",
	closeSize = 30, closeRightInset = 48, closeTop = 12,
	tabsX = 14, tabsY = 72, tabsHeight = 34, tabsGap = 6,
	bodyX = 14, bodyY = 119, bodyWidthInset = 28, bodyHeightInset = 177,
	scrollBarThickness = 3,
	rowPadding = 9, rowPaddingRight = 6, rowPaddingBottom = 10,
	footerX = 18, footerBottomInset = 49, footerHeight = 38,
}

PanelTheme.ScreenGui = { ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 20 }

-- Live responsive fit. Returns { x, y, width, height } in pixels.
function PanelTheme.fit(viewportX, viewportY)
	local width = math.min(402, viewportX - 24)
	local y = viewportY < 550 and 108 or 178
	local height = math.min(710, math.max(230, viewportY - y - 24))
	return { x = 18, y = y, width = width, height = height }
end

-- Keeps a dragged panel on-screen.
function PanelTheme.clamp(x, y, width, height, viewportX, viewportY)
	local maxX = math.max(0, viewportX - width)
	local maxY = math.max(0, viewportY - height)
	return math.min(math.max(x, 0), maxX), math.min(math.max(y, 0), maxY)
end

-- Width of each of `count` buttons in a row of `rowWidth` with tab gaps.
function PanelTheme.rowButtonWidth(count, rowWidth)
	local gap = PanelTheme.Layout.tabsGap
	return (rowWidth - gap * (count - 1)) / count
end

-- Roblox constructors -------------------------------------------------------

function PanelTheme.color(name)
	local c = PanelTheme.Colors[name]
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function corner(parent, radius)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

-- Standard button: card background, white text, 12 px; selected = teal on bg.
function PanelTheme.button(text, selected)
	local b = Instance.new("TextButton")
	b.Font = Enum.Font[PanelTheme.FontName]
	b.TextSize = PanelTheme.TextSize.button
	b.Text = text
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	corner(b, PanelTheme.ButtonRadius)
	PanelTheme.setSelected(b, selected == true)
	return b
end

function PanelTheme.setSelected(button, selected)
	button.BackgroundColor3 = PanelTheme.color(selected and "teal" or "card")
	button.TextColor3 = PanelTheme.color(selected and "bg" or "white")
end

-- kind: "heading" (teal 13), "description" (muted 10), "body" (white 12),
-- "title" (white 17), "status" (muted 11), "handle" (muted 9).
function PanelTheme.label(kind, text)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font[PanelTheme.FontName]
	l.TextSize = PanelTheme.TextSize[kind]
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = text or ""
	local colorName = "white"
	if kind == "heading" then
		colorName = "teal"
	elseif kind == "description" or kind == "status" or kind == "handle" then
		colorName = "muted"
	end
	l.TextColor3 = PanelTheme.color(colorName)
	return l
end

-- Drawer frame: bg at 0.015 transparency, 14 px corner, stroke at 0.25.
function PanelTheme.drawer(name)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = PanelTheme.color("bg")
	f.BackgroundTransparency = PanelTheme.Drawer.transparency
	f.BorderSizePixel = 0
	corner(f, PanelTheme.Drawer.radius)
	local stroke = Instance.new("UIStroke")
	stroke.Color = PanelTheme.color("stroke")
	stroke.Transparency = PanelTheme.Drawer.strokeTransparency
	stroke.Parent = f
	return f
end

return PanelTheme
