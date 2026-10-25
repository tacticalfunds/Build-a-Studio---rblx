-- Server bootstrap for the Studio Builder. Scripts only run in Play/live
-- servers, so the editor copy of the asset yard is kept while editing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("StudioBuilder"):WaitForChild("Config"))
local AssetYardGuard = require(script.Parent:WaitForChild("Bootstrap"):WaitForChild("AssetYardGuard"))
local BuilderService = require(script.Parent:WaitForChild("Runtime"):WaitForChild("BuilderService"))

AssetYardGuard.run(Workspace, Config.AssetYardName)
BuilderService.start()
