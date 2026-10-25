--[[
	STUDIO BUILDER PATCH (task 5) for PodcastDirector — NOT a standalone
	script. Three edits to the live Director (source of snapshot(),
	restoreSnapshot() and persistentAction() read 2026-10-25). Everything not
	marked BUILDER is copied unchanged from that source; persistentAction() is
	NOT changed (Save/Load/Share/LoadCode keep its busy flag, 2 s cooldown,
	layoutBusy and feedback handling).

	(1) Add next to the existing `presets` require:
	(2) Replace snapshot() with the version below (only the last line differs).
	(3) Replace restoreSnapshot(p, data) with the version below:
	    a. the Build section is validated and staged BEFORE the yielding text
	       filtering and before any mutation (corrupt/newer -> error, nothing
	       changed);
	    b. after the existing host re-check, the build is applied
	       transactionally BEFORE the room is touched (lock, host + epoch
	       re-checks, rollback/recovery inside the builder; failure -> error,
	       build and room unchanged);
	    c. the existing room restore runs unchanged inside a pcall; if it
	       errors, the build load is reverted and the error is re-raised.
	A preset without a Build section (legacy) leaves the builder untouched.
]]

-- (1) BUILDER: next to `local presets = require(...)`
local builderPersistence = require(game:GetService("ServerScriptService"):WaitForChild("StudioBuilder"):WaitForChild("Runtime"):WaitForChild("BuilderService")).getPersistence()

-- (2) snapshot(): unchanged except the BUILDER line at the end.
local function snapshot()
 local data={Version=1,Settings={},Fixtures={},Items={}}
 for key in defaults do if key~="Phase" and (not groupKeys[key] or key:sub(1,#(settings:GetAttribute("SceneSet") or "Custom")+1)==(settings:GetAttribute("SceneSet") or "Custom").."_") then data.Settings[key]=settings:GetAttribute(key) end end
 data.Settings.CustomLighting=settings:GetAttribute("CustomLighting")==true
 local scene=settings:GetAttribute("SceneSet") or "Custom"
 for _,record in lighting.GetFixtures(scene) do
  local values={};for key,attribute in fixtureAttributes do values[key]=record.Light:GetAttribute(attribute) end;data.Fixtures[record.Id]=values
 end
 for _,record in customization.GetItems(scene) do
  local values={};for key,attribute in itemAttributes do values[key]=record.Object:GetAttribute(attribute) end;data.Items[record.Id]=values
 end
 -- BUILDER: additive Build section; errors (visible failed save) if the builder can't capture now.
 return builderPersistence:attachBuild(data)
end

-- (3) restoreSnapshot(): unchanged except the BUILDER lines and the pcall around the room restore.
local function restoreSnapshot(p,data)
 assert(type(data)=="table" and data.Version==1 and type(data.Settings)=="table","Unsupported studio preset.")
 local values=data.Settings;local scene=values.SceneSet
 assert(type(scene)=="string" and (scene=="Custom" or RS.PodcastRooms:FindFirstChild(scene)),"This room is unavailable.")
 -- BUILDER (a): validate + stage the Build section before any yield or mutation.
 local stagedBuild=builderPersistence:prepareLoad(p.UserId,data)
 local filtered={}
 for key in textLengths do if type(values[key])=="string" then
  filtered[key]=TextService:FilterStringAsync(values[key],p.UserId,Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
 end end
 assert(p.Parent and p.UserId==settings:GetAttribute("HostUserId"),"Host controls changed while loading.")
 -- BUILDER (b): apply the build transactionally before the room is touched.
 local buildToken=builderPersistence:commitLoad(p.UserId,stagedBuild)
 -- BUILDER (c): existing room restore, unchanged, inside a pcall so a failure reverts the build.
 local roomOk,roomError=pcall(function()
  rememberLighting(settings:GetAttribute("SceneSet") or "Custom")
  for key,default in defaults do
   local value=values[key]
   if key~="Phase" and type(value)==type(default) and (type(value)~="number" or finite(value)) then
    if textLengths[key] then value=filtered[key]
    elseif bounds[key] then value=math.clamp(value,bounds[key][1],bounds[key][2])
    elseif layoutBounds[key] then value=math.clamp(value,layoutBounds[key][1],layoutBounds[key][2])
    elseif atmosphereBounds[key] then value=math.clamp(value,atmosphereBounds[key][1],atmosphereBounds[key][2])
    elseif key=="Ambience" and value~="Off" and value~="Rain" and value~="Air" then value="Off" end
    if value~=nil then settings:SetAttribute(key,value) end
   end
  end
  for _,key in atmosphereKeys do if values[key]==nil then settings:SetAttribute(key,defaults[key]) end end
  settings:SetAttribute("CustomLighting",values.CustomLighting==true)
  applyAll()
  for _,record in lighting.GetFixtures(scene) do
   lighting.ResetFixtureOverrides(record.Light)
   local patch=type(data.Fixtures)=="table" and data.Fixtures[record.Id]
   if type(patch)=="table" then
    for key,attribute in fixtureAttributes do
     local value=patch[key]
     if (key=="Enabled" and type(value)=="boolean") or ((key=="Intensity" or key=="Range") and finite(value)) or (key=="Color" and type(value)=="string" and #value==6 and value:match("^%x+$")) then record.Light:SetAttribute(attribute,value) end
    end
   end
  end
  for _,record in customization.GetItems(scene) do
   customization.Reset(record.Object)
   local patch=type(data.Items)=="table" and data.Items[record.Id]
   if type(patch)=="table" then
    for key,limit in itemBounds do if finite(patch[key]) then record.Object:SetAttribute(itemAttributes[key],math.clamp(patch[key],limit[1],limit[2])) end end
    if type(patch.Visible)=="boolean" then record.Object:SetAttribute(itemAttributes.Visible,patch.Visible) end
   end
  end
  customization.Apply(scene);lighting.Apply(studio,getState());applyDecor(getState())
 end)
 if not roomOk then
  builderPersistence:revertLoad(p.UserId,buildToken)
  error(roomError,0)
 end
end
