-- Named presets persist across servers; immutable share codes are explicitly created by the host.
--[[
	STUDIO BUILDER PATCH (task 5) — replaces ServerScriptService.StudioPresets.
	Based on the live source read 2026-10-25. Only M.Save changed:
	* the UpdateAsync transform comes from StudioBuilder's PresetSlotGuard: it
	  refuses (writes nothing) to overwrite a corrupt profile, a slot whose
	  Build section is newer or unreadable, or a slot whose Build would be
	  dropped by a snapshot without one; it is pure and retry-safe, never
	  mutates `old`, and reports the refusal of the last invocation;
	* a refusal raises a visible error (with a position prefix so the
	  Director's existing ":%d+: (.+)$" extraction shows the message).
	List, Load, Share, LoadCode, the 5 slots, the 250000-byte cap, the
	DataStore name, keys and entry Version 1 are unchanged. Not run against
	a real DataStore in this environment.
]]
local M={}
local function store() return game:GetService("DataStoreService"):GetDataStore("PodcastStudioPresets_v1") end
local Http=game:GetService("HttpService")
local Text=game:GetService("TextService")
local SlotGuard=require(game:GetService("ServerScriptService"):WaitForChild("StudioBuilder"):WaitForChild("Core"):WaitForChild("PresetSlotGuard"))
local function cleanName(value,userId)
 if type(value)~="string" then return nil end
 value=value:gsub("[%c]"," "):gsub("^%s+",""):gsub("%s+$","")
 local n=utf8.len(value);if not n or n<1 or n>32 then return nil end
 return Text:FilterStringAsync(value,userId,Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
end
local function validSlot(slot) return type(slot)=="number" and slot%1==0 and slot>=1 and slot<=5 end
local function key(userId) return "user:"..userId end
function M.List(userId)
 local profile=store():GetAsync(key(userId)) or {Slots={}}
 local result={}
 for i=1,5 do local entry=profile.Slots and profile.Slots[tostring(i)];result[i]=entry and {Name=entry.Name,Scene=entry.Data.Settings.SceneSet,Updated=entry.Updated} or {Name="Empty slot"} end
 return result
end
function M.Save(userId,slot,name,snapshot)
 assert(validSlot(slot),"Choose a slot from 1 to 5.")
 name=cleanName(name,userId);assert(name,"Use a preset name with 1–32 characters.")
 assert(#Http:JSONEncode(snapshot)<250000,"This preset is too large.")
 local entry={Name=name,Data=snapshot,Owner=userId,Updated=os.time(),Version=1}
 -- BUILDER PATCH: guarded, retry-safe transform (was: mutate old and return it).
 local transform,refusal=SlotGuard.transform(slot,entry)
 store():UpdateAsync(key(userId),transform)
 if refusal() then error(SlotGuard.message(refusal())) end
 return name
end
function M.Load(userId,slot)
 assert(validSlot(slot),"Choose a slot from 1 to 5.")
 local profile=store():GetAsync(key(userId));local entry=profile and profile.Slots and profile.Slots[tostring(slot)]
 assert(entry and entry.Version==1,"That save slot is empty.")
 return entry
end
function M.Share(userId,slot)
 local entry=M.Load(userId,slot)
 local code=Http:GenerateGUID(false):gsub("-",""):sub(1,16):upper()
 store():UpdateAsync("share:"..code,function(old) assert(old==nil,"Please retry creating a share code.");return entry end)
 return code
end
function M.LoadCode(code)
 assert(type(code)=="string","Enter a share code.")
 code=code:gsub("%s",""):upper();assert(#code==16 and code:match("^%x+$"),"Use a 16-character share code.")
 local entry=store():GetAsync("share:"..code);assert(entry and entry.Version==1,"Share code not found.")
 return entry
end
return M
