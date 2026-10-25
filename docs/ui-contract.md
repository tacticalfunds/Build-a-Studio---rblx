# Builder UI contract: match the live host panel

**User requirement (2026-10-25):** the builder UI (task 4) and Branding (task 9) must match
the current in-game host panel. **Don't redesign it or introduce a different visual style.**

Source of truth: the live `StarterPlayer.StarterPlayerScripts.PodcastStudioPanel` source, read by
Codex from authorized Studio on 2026-10-25. The values below are transcribed from it. If the
live source changes, the live source wins; update this file.

## Design tokens (exact)

```lua
local C = {
	bg    = Color3.fromRGB(16, 24, 29),
	card  = Color3.fromRGB(31, 43, 49),
	teal  = Color3.fromRGB(91, 224, 198),
	white = Color3.fromRGB(237, 235, 225),
	muted = Color3.fromRGB(155, 175, 180),
}
-- Drawer stroke: Color3.fromRGB(66, 89, 94), Transparency 0.25
```

| Element | Spec |
|---|---|
| Font | `Enum.Font.GothamMedium` everywhere |
| Standard button | Background `C.card`, text `C.white`, TextSize 12, `BorderSizePixel = 0`, `AutoButtonColor = true`, `UICorner` 8 px |
| Selected button | Background `C.teal`, text `C.bg` |
| Heading | `C.teal`, 13 px |
| Description | `C.muted`, 10 px |
| Body text | 12–13 px |
| Panel title | 17 px |

## Layout (exact)

| Element | Spec |
|---|---|
| Drawer | Background `C.bg`, `BackgroundTransparency = 0.015`, corner radius 14 px, `UIStroke` RGB(66, 89, 94) at transparency 0.25 |
| Header | At (18, 13). Title 24 px tall |
| Shared status line | At (18, 39), 11 px |
| Drag handle | Top right, label `DRAG TO MOVE`, 9 px, `C.muted` |
| Close button | 30 × 30 at (right − 48, top 12) |
| Tabs | Camera, Studio, Lighting, Meeting at x 14, y 72, height 34, 6 px gaps |
| Scroll body | x 14, y 119, width −28 (of drawer), height −177 (of drawer). Scrollbar 3 px, teal |
| Rows | `UIListLayout` padding 9 px; `UIPadding` right 6, bottom 10 |
| Footer status | x 18, bottom − 49, height 38, 11 px, `C.muted` |

## Responsive fit (exact)

- `width = min(402, viewport.X - 24)`
- default `y = (viewport.Y < 550) and 108 or 178`
- `height = min(710, max(230, viewport.Y - y - 24))`
- default left = 18
- Dragging clamps the panel on-screen, and the dragged position is kept.
- The launcher sits on the left at x 18, y 60 on small viewports or y 100 otherwise, clear of the leaderboard. `P` toggles it.
- ScreenGui: `ResetOnSpawn = false`, `IgnoreGuiInset = false`, `DisplayOrder = 20`.

## UX rules

- **Entry point:** add a Build entry inside the existing **Studio** tab. Keep the four tabs
  (Camera, Studio, Lighting, Meeting) and all their current functions. **No fifth tab, and no second, competing host panel.**
- **Catalog drawer:** the builder may show a dedicated catalog drawer using these exact tokens and
  layout conventions and matching buttons. A clear **Back** / **Done** returns to the existing panel and **keeps
  the panel's position**.
- **Theme filters:** Retro, 1980s, Futuristic, Cozy and Winter all use the same button styling
  (standard, or selected = teal). No unrelated theme.
- **Branding (task 9):** lives within Studio, in the same row, heading and input style.
- **Preserve:** the drag handle, touch input, readable labels, host and read-only messaging, cursor release
  (Escape, releasing right mouse, focus loss) and keyboard safety (no new bindings over 1–5, V, F, E, Q).
- **Shared helpers:** new builder UI gets its own shared theme/helper module (the tokens and
  constructors above) so it stays consistent. **No wholesale rewrite of the existing panel source.**

## Integration boundary

- Wire up through explicit callbacks and adapters. Don't call guessed live functions.
- The live `toggleOpen` is a **local** function that updates `Drawer.Visible`, `launch.Text` and the
  ScreenGui `PanelOpen` attribute. **No callable public toggle exists yet.** The builder's `hostDrawer`
  hook (BuildModeHandoff) needs Codex to expose one; setting `Drawer.Visible` alone leaves
  `PanelOpen` and the launcher text stale.
- Codex handles the exact wiring into the existing panel and the visual comparison against it.
