--[[
	Catalog: stable item and collection IDs.

	* Item IDs are permanent: saved builds store them, so never rename or reuse one.
	  Retire an item by removing it; saved copies are preserved, not deleted.
	* Each item maps to a curated template Model named exactly like the item ID in
	  ServerStorage.StudioBuilderTemplates (see server/Adapters/TemplateCatalog).
	  Nothing here is an asset ID, and nothing is ever loaded by ID.
	* `credit` (optional) is attribution the creator asked for; it is metadata
	  only and is kept verbatim from the manifest.
	* `sourceRef` is documentation only: the staging path the template was
	  prepared from, per docs/assets/Studio_Asset_Guide_2026-10-25.json or, for
	  the 24 expansion items, docs/assets/Catalog_Expansion_2026-10-25.json.
	* The expansion templates were prepared in ServerStorage.StudioBuilderExpansion.
	  The runtime probe only looks in StudioBuilderTemplates, so they show as
	  "not installed" until they are placed there under their item IDs.
	* Everything is decorative: chairs are not seats, lamps don't light, and
	  microphones/mixers have no audio, until a dedicated adapter exists.
	* Optional `structure = { kind = ... }` marks a modular structure piece
	  (StructureGrid kinds only: floor, ceiling, wall, window_wall, doorway).
	  The server then applies the 16-stud grid, level and cardinal-yaw rules
	  to it. Five kit pieces carry it (registered, Studio install pending);
	  corners and standalone window frames are not allowed until their fit
	  is approved.
	* Every furniture item has exactly one `type` (FurnitureTypes) chosen by
	  what it does, set explicitly here and never derived from its name.
	  The drawer groups a collection's furniture by type. Structure pieces
	  have no type; they keep their own Structure filters.
	* Collections are tags; an item may carry several. Every collection is free
	  today. `entitlement` is metadata for a future unlock hook
	  (server/Adapters/Entitlements); there is no paywall.
]]

local Config = require(script.Parent.Config)
local Validate = require(script.Parent.Validate)
local StructureGrid = require(script.Parent.StructureGrid)

local Catalog = {}

Catalog.ITEM_ID_PATTERN = "^[a-z][a-z0-9_]*$"
Catalog.COLLECTION_ID_PATTERN = "^[a-z0-9_]+$"

Catalog.Collections = {
	{ id = "cozy", displayName = "Cozy", order = 1, entitlement = { kind = "free" } },
	{ id = "1980s", displayName = "1980s", order = 2, entitlement = { kind = "free" } },
	{ id = "retro", displayName = "Retro", order = 3, entitlement = { kind = "free" } },
	{ id = "winter", displayName = "Winter", order = 4, entitlement = { kind = "free" } },
	{ id = "futuristic", displayName = "Futuristic", order = 5, entitlement = { kind = "free" } },
}

-- Tags follow the proposed collections in the asset guide.
Catalog.Items = {
	{
		id = "cozy_armchair_01",
		displayName = "Green Armchair",
		collections = { "cozy", "retro", "1980s" },
		type = "seating",
		sourceRef = "ServerStorage.PodcastAssetStaging.Green Armchair",
		-- Decorative only: not a participant seat until a seat-anchor adapter exists.
	},
	{
		id = "cozy_coffee_table_01",
		displayName = "Lounge Coffee Table",
		collections = { "cozy", "retro", "winter" },
		type = "tables",
		sourceRef = "ServerStorage.PodcastAssetStaging.LoungeCoffeeTable",
	},
	{
		id = "cozy_bookshelf_01",
		displayName = "Filled Bookshelf",
		collections = { "cozy", "retro", "winter" },
		type = "storage",
		sourceRef = "ServerStorage.PodcastAssetStaging.FilledBookshelf",
	},
	{
		id = "cozy_plant_01",
		displayName = "Small Potted Plant",
		collections = { "cozy", "retro", "winter" },
		type = "plants",
		sourceRef = "ServerStorage.PodcastAssetStaging.SmallPottedPlant",
	},
	{
		id = "cozy_floor_lamp_01",
		displayName = "Cork Floor Lamp",
		collections = { "cozy" },
		type = "lighting",
		sourceRef = "ServerStorage.BuilderAssetReview.Candidate_CorkFloorLamp",
	},
	{
		id = "retro_tv_cart_01",
		displayName = "AV Cart",
		collections = { "1980s" },
		type = "storage",
		sourceRef = "ServerStorage.BuilderAssetReview.Candidate_RetroTVCart",
		-- Cart only; it does not include a television.
	},
	{
		id = "retro_cassette_01",
		displayName = "Cassette Recorder",
		collections = { "retro", "1980s" },
		type = "audio",
		sourceRef = "ServerStorage.BuilderAssetReview.Candidate_VintageCassette",
		-- Decorative; no playback.
	},
	-- Expansion (2026-10-25): 24 templates prepared and visually reviewed by Codex
	-- (docs/assets/Catalog_Expansion_2026-10-25.json). Decorative only; Studio
	-- verification of the registered catalog is pending.
	{
		id = "cozy_book_set_01",
		displayName = "Hardcover Book Collection",
		collections = { "cozy", "retro", "winter" },
		type = "decor",
		sourceRef = "ServerStorage.PodcastAssetStaging.HardcoverBookSet",
	},
	{
		id = "cozy_monstera_01",
		displayName = "Large Monstera Plant",
		collections = { "cozy", "retro" },
		type = "plants",
		sourceRef = "ServerStorage.PodcastAssetStaging.Monstera",
	},
	{
		id = "cozy_upholstered_chair_01",
		displayName = "Upholstered Dining Chair",
		collections = { "cozy", "retro", "1980s" },
		type = "seating",
		sourceRef = "ServerStorage.PodcastAssetStaging.Upholstered Chair",
	},
	{
		id = "future_curved_sofa_01",
		displayName = "Curved Lounge Sofa",
		collections = { "futuristic" },
		type = "seating",
		sourceRef = "ServerStorage.BuilderCollectionExpansionImports.Futuristic C-Shaped Sofa",
	},
	{
		id = "future_glass_table_01",
		displayName = "Neon Glass Coffee Table",
		collections = { "futuristic" },
		type = "tables",
		sourceRef = "ServerStorage.BuilderCollectionExpansionImports.Sci-Fi Coffee Table",
	},
	{
		id = "future_modern_lamp_01",
		displayName = "Sculptural Modern Lamp",
		collections = { "futuristic" },
		type = "lighting",
		sourceRef = "ServerStorage.BuilderCollectionExpansionImports.Modern Lamp",
	},
	{
		id = "future_shelf_01",
		displayName = "Sci-Fi Display Shelf",
		collections = { "futuristic" },
		type = "storage",
		sourceRef = "ServerStorage.BuilderCollectionExpansionImports.Sci-Fi Shelf",
	},
	{
		id = "modern_lounge_chair_01",
		displayName = "Modern Lounge Chair",
		collections = { "cozy", "futuristic" },
		type = "seating",
		sourceRef = "ServerStorage.PodcastAssetStaging.Modern armchair",
	},
	{
		id = "retro_book_01",
		displayName = "Vintage Hardcover",
		collections = { "cozy", "retro" },
		type = "decor",
		sourceRef = "ServerStorage.PodcastAssetStaging.DetailedBook",
	},
	{
		id = "retro_crt_tv_01",
		displayName = "Vintage CRT Television",
		collections = { "retro", "1980s" },
		type = "screens",
		sourceRef = "ServerStorage.StudioBuilderPreparedAssets.retro_crt_tv_01",
	},
	{
		id = "retro_meeting_table_01",
		displayName = "Oval Wooden Table",
		collections = { "cozy", "retro", "1980s" },
		type = "tables",
		sourceRef = "ServerStorage.PodcastAssetStaging.Dinner Table",
	},
	{
		id = "studio_boom_mic_01",
		displayName = "Boom Arm Microphone",
		collections = { "cozy", "retro", "1980s", "futuristic" },
		type = "microphones",
		sourceRef = "ServerStorage.PodcastAssetStaging.SM7B_BoomArm",
	},
	{
		id = "studio_chair_01",
		displayName = "Director's Folding Chair",
		collections = { "cozy", "retro", "1980s" },
		type = "seating",
		sourceRef = "ServerStorage.PodcastAssetStaging.StudioChair",
	},
	{
		id = "studio_desk_lamp_01",
		displayName = "Adjustable Desk Lamp",
		collections = { "cozy", "1980s", "futuristic" },
		type = "lighting",
		sourceRef = "ServerStorage.PodcastAssetStaging.DeskLamp",
	},
	{
		id = "studio_desk_mic_01",
		displayName = "Desktop Microphone",
		collections = { "cozy", "retro", "1980s" },
		type = "microphones",
		sourceRef = "ServerStorage.PodcastAssetStaging.PodcastMicrophone",
	},
	{
		id = "studio_headphones_01",
		displayName = "Studio Headphones",
		collections = { "cozy", "retro", "1980s", "futuristic" },
		type = "audio",
		sourceRef = "ServerStorage.PodcastAssetStaging.StudioHeadphones",
	},
	{
		id = "studio_mixer_01",
		displayName = "Studio Mixing Console",
		collections = { "retro", "1980s", "futuristic" },
		type = "audio",
		sourceRef = "ServerStorage.PodcastAssetStaging.Audio Mixer U-100AM",
	},
	{
		id = "winter_firewood_shelf_01",
		displayName = "Firewood Storage Shelf",
		collections = { "winter", "cozy" },
		type = "storage",
		sourceRef = "ServerStorage.BuilderCollectionExpansionImports.Firewood Rack Set.Prop_FirewoodLogHolderShelf",
	},
	{
		id = "winter_folded_throw_01",
		displayName = "Folded Knit Throw",
		collections = { "cozy", "winter" },
		type = "decor",
		sourceRef = "ServerStorage.PodcastAssetStaging.FoldedThrow",
	},
	{
		id = "winter_furry_chair_01",
		displayName = "Cream Furry Lounge Chair",
		collections = { "winter", "cozy" },
		type = "seating",
		sourceRef = "ServerStorage.BuilderCollectionExpansionImports.Cream Furry Lounge Chair",
	},
	{
		id = "winter_lantern_01",
		displayName = "Candle Lantern",
		collections = { "winter", "cozy" },
		type = "lighting",
		sourceRef = "ServerStorage.BuilderCollectionExpansionImports.Candle Lantern",
	},
	{
		id = "winter_log_basket_01",
		displayName = "Firewood Basket",
		collections = { "winter", "cozy" },
		type = "storage",
		sourceRef = "ServerStorage.BuilderCollectionExpansionImports.Firewood Rack Set.Prop_FirewoodLogHolder",
	},
	{
		id = "winter_snow_globe_01",
		displayName = "Snow Globe",
		collections = { "winter" },
		type = "decor",
		sourceRef = "ServerStorage.BuilderCollectionExpansionImports.Snow Globe",
	},
	{
		id = "winter_white_rug_01",
		displayName = "Geometric Winter Rug",
		collections = { "winter", "cozy" },
		type = "decor",
		sourceRef = "ServerStorage.BuilderCollectionExpansionImports.White Rug",
	},
	-- Structure pieces (task 10): 5 candidates prepared by Codex
	-- (docs/assets/Structure_and_Decor_Candidates_2026-10-25.json; templates in
	-- ServerStorage.StudioStructureCandidates, not yet in StudioBuilderTemplates).
	-- Kit by plexaruszx. Shown only in the drawer's Structure mode; the style
	-- tags are kept for future themed variants. Studio install pending.
	{
		id = "structure_wall_01",
		displayName = "Plaster Wall",
		collections = { "cozy", "retro", "1980s", "winter", "futuristic" },
		sourceRef = "ServerStorage.StructureCandidateImports.Modular Room.Model.Wall straight windowless",
		structure = { kind = "wall" },
	},
	{
		id = "structure_window_wall_01",
		displayName = "Window Wall",
		collections = { "cozy", "retro", "1980s", "winter", "futuristic" },
		sourceRef = "ServerStorage.StructureCandidateImports.Modular Room.Model.Wall straight window",
		structure = { kind = "window_wall" },
	},
	{
		id = "structure_doorway_01",
		displayName = "Open Doorway Wall",
		collections = { "cozy", "retro", "1980s", "winter", "futuristic" },
		sourceRef = "ServerStorage.StructureCandidateImports.Modular Room.Model.Wall straight door",
		structure = { kind = "doorway" },
	},
	{
		id = "structure_floor_01",
		displayName = "Wood Floor Tile",
		collections = { "cozy", "retro", "1980s", "winter", "futuristic" },
		sourceRef = "ServerStorage.StructureCandidateImports.Modular Room.Model.Floor",
		structure = { kind = "floor" },
	},
	{
		id = "structure_ceiling_01",
		displayName = "Plain Ceiling Tile",
		collections = { "cozy", "retro", "1980s", "winter", "futuristic" },
		sourceRef = "ServerStorage.StructureCandidateImports.Modular Room.Model.Floor",
		structure = { kind = "ceiling" },
		-- Neutral recolour of the kit floor geometry (same source as structure_floor_01), not a separate marketplace model.
	},
	-- Decor (2026-10-25): 2 candidates prepared by Codex
	-- (docs/assets/Structure_and_Decor_Candidates_2026-10-25.json; templates in
	-- ServerStorage.StudioStructureCandidates, Studio install pending).
	-- Decorative only: no audio or playback.
	{
		id = "retro_record_player_01",
		displayName = "Vintage Record Player",
		collections = { "retro", "1980s", "cozy" },
		type = "audio",
		sourceRef = "ServerStorage.StructureCandidateImports.Record Player",
		-- Attribution requested by the creator; keep it wherever credits are shown.
		credit = "RushioLCO (credit requested)",
	},
	{
		id = "retro_radio_01",
		displayName = "Vintage Radio",
		collections = { "retro", "1980s", "cozy" },
		type = "audio",
		sourceRef = "ServerStorage.StructureCandidateImports.Vintage Radio",
		-- Source creator zzz_1551 (manifest sourceCreator).
	},
	-- Decor (2026-10-26): approved by Codex from the tracked candidates
	-- (docs/assets/Decor_Candidate_retro_patterned_rug_01_2026-10-26.json;
	-- template ServerStorage.PreparedDecorCandidates.retro_patterned_rug_01,
	-- Studio install pending). Source: free Creator Store model by caductis.
	{
		id = "retro_patterned_rug_01",
		displayName = "Patterned Vintage Rug",
		collections = { "cozy", "retro", "1980s" },
		type = "decor",
		sourceRef = "ServerStorage.NextCatalogInspection.Review_11829259774",
	},
	-- Lighting (2026-10-26): approved by Codex from the tracked candidates
	-- (docs/assets/Decor_Candidate_retro_classic_floor_lamp_01_2026-10-26.json;
	-- template ServerStorage.PreparedDecorCandidates.retro_classic_floor_lamp_01,
	-- Studio install pending). Source: free Creator Store model by bearduckmonkey.
	-- Decorative only: it has no Light object, gives no light and has no on/off.
	{
		id = "retro_classic_floor_lamp_01",
		displayName = "Classic Shaded Floor Lamp",
		collections = { "cozy", "retro", "1980s", "winter" },
		type = "lighting",
		sourceRef = "ServerStorage.NextCatalogInspection.Review_4128475322",
	},
	-- Structure variants (2026-10-26): 9 prepared by Codex
	-- (docs/assets/Structure_Expansion_2026-10-26.json). Adapted free assets and
	-- material variants of the modular kit (plus the tracked White Brick Wall
	-- resized to the grid), not independent models. Install source:
	-- ServerStorage.StructureExpansionCandidates.<id>; sourceRef is provenance.
	-- Studio install pending.
	{
		id = "structure_floor_oak_01",
		displayName = "Light Oak Floor",
		collections = { "cozy", "retro", "1980s", "winter", "futuristic" },
		sourceRef = "ServerStorage.StudioBuilderTemplates.structure_floor_01",
		structure = { kind = "floor" },
	},
	{
		id = "structure_floor_walnut_01",
		displayName = "Dark Walnut Floor",
		collections = { "cozy", "retro", "1980s", "winter", "futuristic" },
		sourceRef = "ServerStorage.StudioBuilderTemplates.structure_floor_01",
		structure = { kind = "floor" },
	},
	{
		id = "structure_floor_concrete_01",
		displayName = "Concrete Floor",
		collections = { "cozy", "retro", "1980s", "winter", "futuristic" },
		sourceRef = "ServerStorage.StudioBuilderTemplates.structure_floor_01",
		structure = { kind = "floor" },
	},
	{
		id = "structure_floor_slate_01",
		displayName = "Slate Floor",
		collections = { "cozy", "retro", "1980s", "winter", "futuristic" },
		sourceRef = "ServerStorage.StudioBuilderTemplates.structure_floor_01",
		structure = { kind = "floor" },
	},
	{
		id = "structure_wall_wood_01",
		displayName = "Wood Panel Wall",
		collections = { "cozy", "retro", "1980s", "winter", "futuristic" },
		sourceRef = "ServerStorage.StudioBuilderTemplates.structure_wall_01",
		structure = { kind = "wall" },
	},
	{
		id = "structure_wall_brick_01",
		displayName = "White Brick Wall",
		collections = { "cozy", "retro", "1980s", "winter", "futuristic" },
		sourceRef = "ServerStorage.NextCatalogInspection.White Brick Wall",
		structure = { kind = "wall" },
	},
	{
		id = "structure_ceiling_dark_01",
		displayName = "Dark Studio Ceiling",
		collections = { "cozy", "retro", "1980s", "winter", "futuristic" },
		sourceRef = "ServerStorage.StudioBuilderTemplates.structure_ceiling_01",
		structure = { kind = "ceiling" },
	},
	{
		id = "structure_window_black_01",
		displayName = "Black Frame Window Wall",
		collections = { "cozy", "retro", "1980s", "winter", "futuristic" },
		sourceRef = "ServerStorage.StudioBuilderTemplates.structure_window_wall_01",
		structure = { kind = "window_wall" },
	},
	{
		id = "structure_doorway_wide_01",
		displayName = "Wide Open Doorway",
		collections = { "cozy", "retro", "1980s", "winter", "futuristic" },
		sourceRef = "ServerStorage.StudioBuilderTemplates.structure_doorway_01",
		structure = { kind = "doorway" },
	},
	-- Futuristic furniture (2026-10-26): 2 batch 02 pieces visually reviewed and
	-- static-checked by Codex (docs/assets/Futuristic_Furniture_Registration_2026-10-26.json).
	-- Source: free Creator Store model by SebbyTheGODKid. Install source:
	-- ServerStorage.StudioBuilderPreparedAssets.<id>; Studio install pending.
	-- Decorative only: the speaker has no playback, and neither has a Light.
	{
		id = "future_speaker_01",
		displayName = "Neon Studio Speaker",
		collections = { "futuristic" },
		type = "audio",
		sourceRef = "ServerStorage.StudioBuilderPreparedAssets.future_speaker_01",
	},
	{
		id = "future_layered_coffee_table_01",
		displayName = "Layered Neon Coffee Table",
		collections = { "futuristic" },
		type = "tables",
		sourceRef = "ServerStorage.StudioBuilderPreparedAssets.future_layered_coffee_table_01",
	},
	-- Tufted leather sofa (2026-10-26): batch 02 H02_11, visually reviewed and
	-- static-checked by Codex (docs/assets/Tufted_Leather_Sofa_Registration_2026-10-26.json).
	-- Source: free Creator Store model by leutxiz; mesh yaw corrected to identity.
	-- Install source: ServerStorage.StudioBuilderPreparedAssets.<id>; Studio install pending.
	-- Decorative only: it has no Seat, so nobody can sit on it.
	{
		id = "cozy_tufted_leather_sofa_01",
		displayName = "Tufted Leather Sofa",
		collections = { "cozy", "retro", "1980s", "winter" },
		type = "seating",
		sourceRef = "ServerStorage.StudioBuilderPreparedAssets.cozy_tufted_leather_sofa_01",
	},
	-- Batch 03 structure pieces (2026-10-26): 2 adapted free assets, visually
	-- reviewed and static-checked by Codex, resized to the grid module
	-- (docs/assets/Batch03_Structure_Registration_2026-10-26.json).
	-- Install source: ServerStorage.StudioBuilderPreparedAssets.<id>; Studio install pending.
	-- The glass partition is a fixed glass wall: no opening, no door behaviour.
	{
		id = "structure_glass_partition_01",
		displayName = "Grid Glass Partition",
		collections = { "cozy", "retro", "1980s", "winter", "futuristic" },
		sourceRef = "ServerStorage.StudioBuilderPreparedAssets.structure_glass_partition_01",
		structure = { kind = "window_wall" },
	},
	{
		id = "structure_ceiling_acoustic_01",
		displayName = "Acoustic Tile Ceiling",
		collections = { "cozy", "retro", "1980s", "winter", "futuristic" },
		sourceRef = "ServerStorage.StudioBuilderPreparedAssets.structure_ceiling_acoustic_01",
		structure = { kind = "ceiling" },
	},
	-- Industrial wall (2026-10-26): batch 02 H02_03, the Straight Wall from a
	-- free modular wall pack, rotated and normalized to the 16 x 15 x 1 module by
	-- Codex (docs/assets/Industrial_Wall_Registration_2026-10-26.json).
	-- Install source: ServerStorage.StudioBuilderPreparedAssets.<id>; Studio install pending.
	-- Its imported PointLight is disabled; no lighting behaviour.
	{
		id = "structure_industrial_wall_01",
		displayName = "Industrial Concrete Wall",
		collections = { "futuristic", "1980s" },
		sourceRef = "ServerStorage.StudioBuilderPreparedAssets.structure_industrial_wall_01",
		structure = { kind = "wall" },
	},
	-- Acoustic wall (2026-10-26): batch 02 H02_10. One grooved tile from a free
	-- acoustic panel set, laid out by Codex as an 8 x 7 checkerboard on an added
	-- 16 x 15 backing (docs/assets/Acoustic_Wall_Registration_2026-10-26.json).
	-- Install source: ServerStorage.StudioBuilderPreparedAssets.<id>; Studio install pending.
	-- Looks like acoustic foam only; it does not change any sound.
	{
		id = "structure_acoustic_wall_01",
		displayName = "Acoustic Foam Wall",
		collections = { "retro", "1980s", "futuristic" },
		sourceRef = "ServerStorage.StudioBuilderPreparedAssets.structure_acoustic_wall_01",
		structure = { kind = "wall" },
	},
	-- Drawer cabinet (2026-10-26): batch 02 H02_18 Future Dresser from the free
	-- Futuristic Furniture pack, normalized and re-coloured by Codex
	-- (docs/assets/Drawer_Cabinet_Registration_2026-10-26.json).
	-- Install source: ServerStorage.StudioBuilderPreparedAssets.<id>; Studio install pending.
	-- Decorative only: the drawers do not open and it stores nothing.
	{
		id = "future_drawer_cabinet_01",
		displayName = "Three-Drawer Cabinet",
		collections = { "futuristic" },
		type = "storage",
		sourceRef = "ServerStorage.StudioBuilderPreparedAssets.future_drawer_cabinet_01",
	},
	-- Water dispenser (2026-10-26): extracted by Codex from the existing
	-- Conference Room (docs/assets/Water_Dispenser_Registration_2026-10-26.json);
	-- the room itself is unchanged. Install source:
	-- ServerStorage.StudioBuilderPreparedAssets.<id>; Studio install pending.
	-- Decorative only: it dispenses nothing and the taps don't move.
	{
		id = "studio_water_dispenser_01",
		displayName = "Water Dispenser",
		collections = { "cozy", "1980s" },
		type = "decor",
		sourceRef = "ServerStorage.StudioBuilderPreparedAssets.studio_water_dispenser_01",
	},
	-- Tall floor plant (2026-10-26): extracted by Codex from the existing
	-- Conference Room (docs/assets/Tall_Floor_Plant_Registration_2026-10-26.json);
	-- the room itself is unchanged. Install source:
	-- ServerStorage.StudioBuilderPreparedAssets.<id>; Studio install pending.
	-- Decorative only: the leaves don't sway.
	{
		id = "studio_tall_floor_plant_01",
		displayName = "Tall Floor Plant",
		collections = { "cozy", "retro", "1980s" },
		type = "plants",
		sourceRef = "ServerStorage.StudioBuilderPreparedAssets.studio_tall_floor_plant_01",
	},
	-- Conference table (2026-10-26): extracted by Codex from the existing
	-- Conference Room (docs/assets/Conference_Table_Registration_2026-10-26.json);
	-- the room itself is untouched. Install source:
	-- ServerStorage.StudioBuilderPreparedAssets.<id>; Studio install pending.
	-- Decorative only: no chairs come with it and it has no seats.
	{
		id = "studio_conference_table_01",
		displayName = "White Conference Table",
		collections = { "cozy", "1980s", "futuristic" },
		type = "tables",
		sourceRef = "ServerStorage.StudioBuilderPreparedAssets.studio_conference_table_01",
	},
	-- Red flower pot (2026-10-26): extracted by Codex from the existing
	-- Conference Room (docs/assets/Flower_Pot_Registration_2026-10-26.json);
	-- the room itself is unchanged. Install source:
	-- ServerStorage.StudioBuilderPreparedAssets.<id>; Studio install pending.
	-- Decorative only: no sway and no interactions.
	{
		id = "studio_flower_pot_01",
		displayName = "Red Flower Pot",
		collections = { "cozy", "retro", "1980s", "winter" },
		type = "plants",
		sourceRef = "ServerStorage.StudioBuilderPreparedAssets.studio_flower_pot_01",
	},
	-- Black office chair (2026-10-26): one chair extracted by Codex from the
	-- existing Conference Room's chair group
	-- (docs/assets/Office_Chair_Registration_2026-10-26.json); the room is
	-- unchanged. Install source: ServerStorage.StudioBuilderPreparedAssets.<id>;
	-- Studio install pending. Decorative only: it has no Seat, and it doesn't
	-- roll or swivel.
	{
		id = "studio_office_chair_01",
		displayName = "Black Office Chair",
		collections = { "cozy", "1980s", "futuristic" },
		type = "seating",
		sourceRef = "ServerStorage.StudioBuilderPreparedAssets.studio_office_chair_01",
	},
	-- Steaming coffee mug (2026-10-26): extracted by Codex from the current,
	-- project-modified Conference Room mug
	-- (docs/assets/Coffee_Mug_Registration_2026-10-26.json). Install source:
	-- ServerStorage.StudioBuilderPreparedAssets.<id>; Studio install pending.
	-- Decorative only: the steam is a particle effect, and the mug can't be
	-- picked up.
	{
		id = "studio_coffee_mug_01",
		displayName = "Steaming Coffee Mug",
		collections = { "cozy", "retro", "1980s", "winter", "futuristic" },
		type = "decor",
		sourceRef = "ServerStorage.StudioBuilderPreparedAssets.studio_coffee_mug_01",
	},
	-- Studio presentation board (2026-10-26): extracted by Codex from the
	-- current, project-branded Conference Room board
	-- (docs/assets/Presentation_Board_Registration_2026-10-26.json). Install
	-- source: ServerStorage.StudioBuilderPreparedAssets.<id>; Studio install
	-- pending. A static decorative screen: no drawing, video or clickable UI.
	{
		id = "studio_presentation_board_01",
		displayName = "Studio Presentation Board",
		collections = { "cozy", "1980s", "futuristic" },
		type = "screens",
		sourceRef = "ServerStorage.StudioBuilderPreparedAssets.studio_presentation_board_01",
	},
	-- Studio softbox (2026-10-26): extracted by Codex from the project-modified
	-- Broadcast Set and re-oriented upright
	-- (docs/assets/Studio_Softbox_Registration_2026-10-26.json). Install source:
	-- ServerStorage.StudioBuilderPreparedAssets.<id>; Studio install pending.
	-- Decorative only: its SpotLight is disabled and nothing in the builder
	-- turns it on.
	{
		id = "studio_softbox_01",
		displayName = "Studio Softbox",
		collections = { "cozy", "1980s", "futuristic" },
		type = "lighting",
		sourceRef = "ServerStorage.StudioBuilderPreparedAssets.studio_softbox_01",
	},
}

-- Furniture types, in chooser order. Each furniture item has exactly one.
Catalog.FurnitureTypes = {
	{ id = "seating", displayName = "Seating" },
	{ id = "tables", displayName = "Tables" },
	{ id = "storage", displayName = "Storage" },
	{ id = "microphones", displayName = "Microphones" },
	{ id = "audio", displayName = "Audio" },
	{ id = "lighting", displayName = "Lighting" },
	{ id = "screens", displayName = "Screens" },
	{ id = "plants", displayName = "Plants" },
	{ id = "decor", displayName = "Decor" },
}
local furnitureTypeIds = {}
for _, t in ipairs(Catalog.FurnitureTypes) do
	furnitureTypeIds[t.id] = t
end

-- Returns ok, errors (list of strings). Pure; used by tests and server startup.
function Catalog.validateData(collections, items)
	local errors = {}
	local function fail(message)
		errors[#errors + 1] = message
	end

	local collectionIds = {}
	if Validate.sequenceLength(collections, 64) == nil then
		fail("collections must be a sequence")
		collections = {}
	end
	for i, c in ipairs(collections) do
		if type(c) ~= "table" or not Validate.isBoundedString(c.id, 32, Catalog.COLLECTION_ID_PATTERN) then
			fail("collection #" .. i .. " has an invalid id")
		elseif collectionIds[c.id] then
			fail("duplicate collection id " .. c.id)
		else
			collectionIds[c.id] = true
			if not Validate.isBoundedString(c.displayName, 32) then
				fail("collection " .. c.id .. " needs a displayName")
			end
			if c.entitlement ~= nil then
				local e = c.entitlement
				if type(e) ~= "table" or not Validate.isBoundedString(e.kind, 32, "^[%a_]+$") then
					fail("collection " .. c.id .. " has malformed entitlement metadata")
				end
			end
		end
	end

	local itemIds = {}
	if Validate.sequenceLength(items, 1000) == nil then
		fail("items must be a sequence")
		items = {}
	end
	for i, item in ipairs(items) do
		if type(item) ~= "table" or not Validate.isBoundedString(item.id, Config.MaxCatalogIdLength, Catalog.ITEM_ID_PATTERN) then
			fail("item #" .. i .. " has an invalid id")
		elseif itemIds[item.id] then
			fail("duplicate item id " .. item.id)
		else
			itemIds[item.id] = true
			if not Validate.isBoundedString(item.displayName, 48) then
				fail("item " .. item.id .. " needs a displayName")
			end
			local tags = item.collections
			local n = Validate.sequenceLength(tags, 16)
			if n == nil or n == 0 then
				fail("item " .. item.id .. " needs at least one collection tag")
			else
				local seen = {}
				for _, tag in ipairs(tags) do
					if type(tag) ~= "string" or not collectionIds[tag] then
						fail("item " .. item.id .. " has unknown collection tag " .. tostring(tag))
					elseif seen[tag] then
						fail("item " .. item.id .. " repeats collection tag " .. tag)
					end
					seen[tag] = true
				end
			end
			if item.structure == nil then
				if type(item.type) ~= "string" or furnitureTypeIds[item.type] == nil then
					fail("item " .. item.id .. " needs a furniture type")
				end
			elseif item.type ~= nil then
				fail("item " .. item.id .. " is a structure piece and must not have a furniture type")
			end
			if item.structure ~= nil then
				local s = item.structure
				local onlyKind = type(s) == "table"
				if onlyKind then
					for key in pairs(s) do
						if key ~= "kind" then
							onlyKind = false
						end
					end
				end
				if not onlyKind or type(s.kind) ~= "string" or StructureGrid.Kinds[s.kind] == nil then
					fail("item " .. item.id .. " has invalid structure metadata")
				end
			end
		end
	end

	return #errors == 0, errors
end

function Catalog.validate()
	return Catalog.validateData(Catalog.Collections, Catalog.Items)
end

local itemsById = {}
local collectionsById = {}
for _, c in ipairs(Catalog.Collections) do
	collectionsById[c.id] = c
end
for _, item in ipairs(Catalog.Items) do
	itemsById[item.id] = item
end

-- Lookups accept untrusted values; anything that is not a known string ID is nil.
function Catalog.getItem(id)
	if type(id) ~= "string" then
		return nil
	end
	return itemsById[id]
end

function Catalog.getCollection(id)
	if type(id) ~= "string" then
		return nil
	end
	return collectionsById[id]
end

function Catalog.getCollectionsSorted()
	local list = {}
	for _, c in ipairs(Catalog.Collections) do
		list[#list + 1] = c
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	return list
end

function Catalog.getFurnitureType(typeId)
	if type(typeId) ~= "string" then
		return nil
	end
	return furnitureTypeIds[typeId]
end

-- Structure filters for the drawer's Structure mode, in display order. Each maps
-- to exactly one StructureGrid kind (corners and standalone frames deferred).
Catalog.StructureFilters = {
	{ id = "floor", displayName = "Floors" },
	{ id = "wall", displayName = "Walls" },
	{ id = "doorway", displayName = "Doors" },
	{ id = "ceiling", displayName = "Ceilings" },
	{ id = "window_wall", displayName = "Windows" },
}

function Catalog.isStructure(item)
	return type(item) == "table" and type(item.structure) == "table"
end

-- Furniture (non-structure) items tagged with collectionId: the style filters.
function Catalog.getFurnitureTagged(collectionId)
	local list = {}
	for _, item in ipairs(Catalog.getItemsTagged(collectionId)) do
		if not Catalog.isStructure(item) then
			list[#list + 1] = item
		end
	end
	return list
end

-- Furniture in collectionId of one type, in declaration order.
function Catalog.getFurnitureByType(collectionId, typeId)
	local list = {}
	for _, item in ipairs(Catalog.getFurnitureTagged(collectionId)) do
		if item.type == typeId then
			list[#list + 1] = item
		end
	end
	return list
end

-- The type chooser for a collection: { id, displayName, count } in
-- FurnitureTypes order, only types with at least one item.
function Catalog.getFurnitureTypeCounts(collectionId)
	local counts = {}
	for _, item in ipairs(Catalog.getFurnitureTagged(collectionId)) do
		counts[item.type] = (counts[item.type] or 0) + 1
	end
	local list = {}
	for _, t in ipairs(Catalog.FurnitureTypes) do
		if (counts[t.id] or 0) > 0 then
			list[#list + 1] = { id = t.id, displayName = t.displayName, count = counts[t.id] }
		end
	end
	return list
end

-- Structure items of one kind, in declaration order.
function Catalog.getStructureItems(kind)
	local list = {}
	for _, item in ipairs(Catalog.Items) do
		if Catalog.isStructure(item) and item.structure.kind == kind then
			list[#list + 1] = item
		end
	end
	return list
end

-- Items tagged with collectionId, in declaration order (a filter, not ownership).
-- Includes structure items; the drawer's style filters use getFurnitureTagged.
function Catalog.getItemsTagged(collectionId)
	local list = {}
	for _, item in ipairs(Catalog.Items) do
		for _, tag in ipairs(item.collections) do
			if tag == collectionId then
				list[#list + 1] = item
				break
			end
		end
	end
	return list
end

return Catalog
