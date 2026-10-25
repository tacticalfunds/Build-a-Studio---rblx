# Task 7 foundation: seat assignment model and integration plan

**Status:** only the pure model is implemented and tested: `src/server/Core/SeatAssignments.luau` and `src/shared/SeatProfiles.luau`.

- **No runtime hooks are wired.** Not yet changed: PlacementCore, Protocol, BuildPersistence, PresetSlotGuard, StudioLayout, PodcastSeating, PodcastPoses, the panel, the camera, the Director.
- **No avatar offsets.** `SeatProfiles.Profiles` ships empty, so every catalog item is decorative until Codex supplies real anchor and profile metadata.

Every live-contract statement below comes from the installed bb3efa6 sources in
[`docs/studio-reference/`](studio-reference/README.md). Some are also checked by `tests/spec/seat_assignments_spec.lua`.

## 1. Live seat contracts (from the bb3efa6 snapshot)

| Script | What it does with seats |
|---|---|
| `ServerScriptService.StudioLayout` | Owns `Workspace.PodcastStudio.Seats.Seat1..Seat4`. **Every** `Layout.Apply(state)` sets each seat's `CFrame`, `Disabled` and `Active` attribute (details below). It also recomputes `CameraShots.Seat<i>` and `POV<i>` from that CFrame, sets `Wide`, moves the SpawnLocation, and increments `PodcastStudio.LayoutRevision`. On a scene change it unseats every occupant (`Sit = false`, `task.wait(.2)`) and teleports players to the entry. `Layout.Occupied()` is true if any seat is occupied. |
| `ServerScriptService.PodcastSeating` | `PodcastSeatRequest` handler: index `1..4` or `"Leave"`. Refuses when the player is over 120 studs **from `Seat1`**, and when the seat is `Disabled` or `Active == false`. Guards occupancy plus a private `reservations` table. Sits with `hrp.CFrame = seat.CFrame * (0, 2, 0)`, then `seat:Sit(h)`. Leave places the player at `seat.CFrame * (0, 2, 3.6)`. |
| `ServerScriptService.PodcastPoses` | Per-player `PodcastSeatedPose` from `Natural, Relaxed, Lean, Thinking, Talking, CouchSide, CouchRecline`. **The couch modes are refused unless `SceneSet == "Lounge"`**, and leaving Lounge resets them to Natural. Wave needs a SeatPart under `PodcastStudio.Seats`. |
| `StarterPlayerScripts.PodcastPoses` | Applies the pose to anyone seated on any seat under `PodcastStudio.Seats`, as additive joint offsets on top of the default sit animation. There are no per-seat offsets. |
| `StarterPlayerScripts.PodcastCamera` | Seat shots read `CameraShots.Seat<i>` and `POV<i>`. Inactive seats (`Active == false`) are hidden and unselectable. A `LayoutRevision` change forces Wide, except while `StudioBuilderActive`. |
| `StarterPlayerScripts.PodcastSpeakerFollow` | Counts speakers seated on `Seats` children with `Active ~= false`, by the number in the seat name. |
| `ServerScriptService.PodcastDirector` | Seat labels `SeatLabel1..4` (defaults `HOST`, `GUEST 01..03`) go into `DisplayName` and the nameplates. Layout, table and chair changes and Look Recall/Reset refuse while `layout.Occupied()`. A SceneSet switch does **not** check occupancy, because `Layout.Apply` unseats. |
| `ReplicatedStorage.StudioCustomization` | `GetItems(scene)` walks only that room's root (`Workspace.PodcastStudio` for Custom, which returns nothing; otherwise the room model named by the PodcastRooms config). It skips anything containing a Seat. |

`StudioLayout.Apply` seat CFrame, per seat `i`:
- **free-model room** (a PodcastRooms config exists for the scene): `config:GetAttribute("Seat" .. i)`, always enabled;
- **Custom room:** `offset * poses[i] * CFrame.new(0, 0, ChairDistance)`, enabled per layout (Interview disables 3–4);
- **close-up shot:** from `cf * (1.5, 3.3, -6.5 free / -8.2 custom)` toward `cf * (0, 1.9, 0)`;
- **POV shot:** from `cf * (0, 2.55, -0.25)` toward `cf * (0, 2.2, -12)`.

**Design consequence:** builder seats should **reuse Seat1..Seat4** rather than add new Seat instances.
Placed templates have their Seats disabled by `TemplateSanitizer`. Seating, poses, camera shots, speaker follow, nameplates and labels are all keyed to Seat1..4.
So a builder assignment means "while the builder stage is active, Seat\<slot> sits at this placed item's approved anchor".
The model's slot numbers are those seats: 1 = Host, 2..4 = Guest 1..3.

## 2. The model (implemented, pure)

`SeatProfiles.Profiles[catalogId] = { Version = 1, PoseProfile = "Chair" | "Couch", Anchors = { [anchorId] = { X, Y, Z, Yaw } } }`

- An anchor is the Seat part's CFrame in the template's local space, measured from its bottom-centre pivot. It's approved per anchor by Codex.
- Validation is strict: catalog ID exists, version 1, known pose profile, 1–4 anchors, anchor ID pattern, finite bounded numbers, no extra keys. An invalid profile stays decorative and is listed by `profileProblems()`.
- `Chair` and `Couch` use only the live PodcastPoses modes (checked against the snapshot).
- `Couch` is refused (`UnsupportedPose`) until the live Lounge-only gate is changed (`couchPosesEnabled`).

`SeatAssignments` (deps are injected: `getItem`, `isHost`, `hostEpoch`, `isSlotOccupied`):

| Operation | Rule |
|---|---|
| `assign(ctx, slot, itemId, anchor, expectedRevision?)` | `ctx = { userId, epoch }`, captured under the caller's lock. Checks run in this order: host (`NotHost`) and the same host session (`AuthorityLost`, A → B → A included); slot an integer 1..4 (`BadSlot`); revision (`StaleRevision`); ID shapes (`BadRequest`); placed item exists (`NotFound`); catalog item has a valid profile (`NotSeatCapable`); anchor in that profile (`UnknownAnchor`); pose profile supported (`UnsupportedPose`); anchor not used by another slot (`AnchorTaken`); the slot's seat isn't occupied (`SeatOccupied`; an unreadable occupancy counts as occupied); section bound (`SectionFull`). Re-assigning the same target is a no-op. Every refusal leaves state and revision unchanged. |
| `unassign(ctx, slot, expectedRevision?)` | The same authority, slot and revision checks. Refused while occupied (`SeatOccupied`). Also discards that slot's preserved entries (explicit, and counted in the result). |
| `checkEffect(effect)` | Gate for each planned PlacementCore effect (the same shapes the world receives; Undo/Redo emit the same kinds): <br>• **spawn** (Place, Duplicate, Undo of Delete): allowed. Duplicates are never assigned. <br>• **move** (Move, Rotate, Undo/Redo of either): `SeatOccupied` when an assigned slot on the item is occupied; otherwise allowed, and it returns the slots to re-anchor. <br>• **remove** (Delete, Undo of Place, Redo of Delete): refused while the item holds any slot (`SeatOccupied` or `SeatAssigned`); the host unassigns first. <br>• **replace** (load, load rollback): `SeatOccupied` when any assigned slot is occupied. |
| `reconcile()` | Moves active assignments that are no longer valid (missing item, profile, anchor or pose support) to **preserved**, with a reason. Promotes preserved entries once valid again, if the slot is free, the anchor untaken and the seat unoccupied. |
| `resolve(stageActive)` | Per slot: `{ source = "builder", itemId, anchor, catalogId, poseProfile, offset }` while the builder stage is active, otherwise `{ source = "room" }`. Assignments are kept when the stage isn't active. |
| `encode()` / `decode()` / `prepareLoad(section, catalogIdFor)` / `commitLoad(staged)` | The save section, below. `prepareLoad` classifies against the **loaded** build and changes nothing. `commitLoad` is refused, with state unchanged, when any seat that would change is occupied at commit time. |

### Save section and compatibility

The section is a top-level additive key beside `Build`, versioned on its own:

```
BuildSeats = { Version = 1, Assignments = { { Slot = 1, ItemId = "i3", Anchor = "Seat" }, ... } }
```

- **Missing section** (every preset saved so far, and older builds): a legacy load. There are no assignments, every chair is decorative, and the room seats are used.
- **Always written** while the builder is available (`Assignments = {}` when empty). So a missing section means "an older or builderless writer", never "no seats".
- **Newer `Version`:** `UnsupportedVersion`. **Malformed** (types, slot range, ID shape, extra keys, over 16 entries): `Corrupt`. Either way the whole load must be refused before any mutation, like a newer or corrupt Build.
- **Well formed but not valid now** (unknown or unconfigured profile, item missing from the loaded build, unknown anchor, pose not supported, slot or anchor conflict): the entry is kept as **preserved**, with a reason.
  - It's written back on every save, and promoted by `reconcile()` once valid.
  - It's never dropped silently. Only an explicit `unassign` of that slot, or a new assignment to it (reported as `superseded`), removes it.
- **Older installed builders** (bb3efa6) ignore `BuildSeats` on load. Their Director snapshot is rebuilt on save without it, so an old writer would drop it.
  That's why the slot guard needs the `SeatsWouldBeLost` rule below before seat saving ships.

## 3. Decisions needed before wiring

1. **What "builder stage active" means.** The sandbox isn't a SceneSet today (`Custom` or a `PodcastRooms` child; the Director validates). I recommend a new `PodcastRooms` config entry for the builder studio (Codex creates it: ModelName, `Wide`, `Entry`, `Description`), so the existing Director, StudioLayout, camera Wide/Entry, spawn and lighting paths apply. The alternative is a separate Director toggle.
2. **The 120-stud check measures from `Seat1`.** If Host isn't assigned but guests are, guests at the sandbox are refused. Options: require slot 1 for stage activation, or patch PodcastSeating to measure from the requested seat. I recommend the patch, a one-line live change.
3. **Couch poses.** PodcastPoses is Lounge-only on the server (refusal, plus a reset on leaving Lounge), and the panel says "Living Room Lounge only". Couch profiles stay refused until that gate also accepts a builder seat with a Couch profile.
4. **Camera shots for builder seats.** I propose reusing StudioLayout's free-room formula (close-up `-6.5`). It needs a visual check by Codex; no new offsets are guessed.
5. **Reservation race.** PodcastSeating's `reservations` table is private. During its `0.2 s + 0.15 s` sit yields, a seat can be reserved while `Occupant` is still nil. The occupancy adapter needs a readable reservation (for example, a seat attribute set by PodcastSeating), or the runtime disables the seat while re-anchoring.

## 4. Runtime hooks (NOT implemented)

| # | Where | Hook |
|---|---|---|
| H1 | `PlacementCore` | Owns one `SeatAssignments`:<br>• deps: `getItem = model:get`, `hostEpoch = self.hostEpoch`, `isHost` via authority, `isSlotOccupied` from H5;<br>• in the exclusive path, after planning and before `world.apply`, call `checkEffect(plan.effect)` and reject with its code. Undo/Redo go through the existing `HistoryConflict` path with `reason`;<br>• after commit, re-anchor the returned slots (H4b);<br>• call `reconcile()` after recovery and reconcile. |
| H2 | `Protocol` / `RequestValidator` | New ops with exact fields: `AssignSeat { slot, id, anchor, expectedSeatRevision? }` and `UnassignSeat { slot }`. Status gains a seat revision and per-slot assignment. Edit rate bucket. |
| H3 | `BuildPersistence` / `PresetSlotGuard` | • `attachBuild` adds `BuildSeats = encode()`.<br>• `prepareLoad` also runs `seats:prepareLoad` against the staged build's placeable entries; a refusal fails the load before mutation.<br>• The transaction checks `checkEffect(replace)` before `applyBuild`, and calls `commitLoad` inside `commit`; a refusal rolls back the whole load.<br>• The guard gets `SeatsWouldBeLost`, plus a newer or invalid `BuildSeats` refusal, mirroring the Build rules. |
| H4a | `StudioLayout` (live) | A small injected override, for example `Layout.SetSeatOverride(fn)`. In the existing per-seat loop, when `fn(i, state)` returns a CFrame (builder stage, `source == "builder"`): use it, enable the seat, and compute the shots with the same formula. |
| H4b | Seat runtime (new, server) | Re-anchors **one** seat after a builder Move/Rotate: sets `Seat<i>.CFrame` and its two CameraShots. It must **not** call `Layout.Apply`, because that increments `LayoutRevision`, and that forces Wide for everyone and closes the builder (the panel passes `LayoutRevision` as `roomSwitchSignal`). Occupied seats never move, per `checkEffect`. |
| H5 | Occupancy adapter | `isSlotOccupied(i)`: `Seats["Seat" .. i].Occupant ~= nil`, or reserved (decision 5). |
| H6 | Panel UI | A seat control for seat-capable items only, built with `PanelTheme` in the existing drawer style (selection row, choice buttons). No new panel or tab, and no styling of its own. |
| H7 | Room switch | Stage active only for the builder scene (decision 1). `Layout.Apply` already unseats on a scene change. Switching away resolves every slot to the room seat, and the assignments are kept. |
| H8 | `StudioCustomization` | No change needed today (see below). Add a `BuildItemId` skip if builder items are ever placed inside a room root. |

## StudioCustomization isolation (actual, bb3efa6)

`StudioCustomization.GetItems(scene)` walks only the selected room root:
- `Workspace.PodcastStudio` for Custom, which returns no items;
- otherwise the model named by `PodcastRooms[scene].ModelName`.

Builder items live separately in `Workspace.StudioBuilderPlacedItems`, so its `StudioBasePivot` reset never reaches them today.
There is **no explicit `BuildItemId` or folder guard** in the live module; isolation comes only from that root traversal.
A defensive guard (skip any descendant with the `BuildItemId` attribute) is needed before builder items are ever placed into a room root.
The test suite asserts the current isolation, and asserts that the guard is absent, so a change to either is noticed.

## 5. Not executed

- Any Roblox Instance: Seat CFrames, sitting, poses, camera shots, streaming of seats at the sandbox.
- Occupied avatars, real anchors, the live hooks above, multiplayer.
