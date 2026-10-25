--[[
	Protocol: the closed vocabulary between the builder client and server.

	Requests go through ReplicatedStorage.StudioBuilder.Remotes.BuilderRequest
	(RemoteFunction) as a single table. The server accepts only the ops below
	and only the listed fields for each; any other key is rejected.

		{ op = "Place",     itemId = "<catalog id>", transform = { x, y, z, yaw } }
		{ op = "Move",      id = "i12", transform = { x, y, z, yaw } }
		{ op = "Rotate",    id = "i12", direction = 1 | -1 }   -- direction optional, default 1
		{ op = "Duplicate", id = "i12" }
		{ op = "Delete",    id = "i12" }

	Transforms are local to the sandbox origin: studs, yaw in degrees (a
	multiple of Config.RotationStep). Responses:
		{ ok = true,  id = "i12", buildRevision = n }
		{ ok = false, code = "<Code>", buildRevision = n }
]]

local Protocol = {}

Protocol.Ops = {
	Place = "Place",
	Move = "Move",
	Rotate = "Rotate",
	Duplicate = "Duplicate",
	Delete = "Delete",
}

-- Fields each op may carry besides `op`, and whether they are required.
Protocol.OpFields = {
	Place = { itemId = true, transform = true },
	Move = { id = true, transform = true },
	Rotate = { id = true, direction = false },
	Duplicate = { id = true },
	Delete = { id = true },
}

Protocol.Codes = {
	BadRequest = "BadRequest",
	UnknownOp = "UnknownOp",
	RateLimited = "RateLimited",
	NotHost = "NotHost",
	AuthorityLost = "AuthorityLost",
	Busy = "Busy",
	Unavailable = "Unavailable",
	UnknownItem = "UnknownItem",
	NotInstalled = "NotInstalled",
	NotEntitled = "NotEntitled",
	BadTransform = "BadTransform",
	OutOfBounds = "OutOfBounds",
	ItemCap = "ItemCap",
	NotFound = "NotFound",
	NotOwner = "NotOwner",
	ApplyFailed = "ApplyFailed",
	Internal = "Internal",
}

Protocol.Messages = {
	BadRequest = "That request wasn't understood.",
	UnknownOp = "That request wasn't understood.",
	RateLimited = "Slow down a little and try again.",
	NotHost = "Only the host can build.",
	AuthorityLost = "Host changed before the edit finished; nothing was changed.",
	Busy = "Still applying the last change. Try again.",
	Unavailable = "The build area isn't set up.",
	UnknownItem = "That item isn't in the catalog.",
	NotInstalled = "That item isn't installed yet.",
	NotEntitled = "That collection isn't unlocked.",
	BadTransform = "Couldn't place the item there.",
	OutOfBounds = "That spot is outside the build area.",
	ItemCap = "The item limit has been reached.",
	NotFound = "That item no longer exists.",
	NotOwner = "That item belongs to someone else.",
	ApplyFailed = "The change couldn't be applied; nothing was changed.",
	Internal = "Something went wrong.",
}

function Protocol.message(code)
	return Protocol.Messages[code] or Protocol.Messages.Internal
end

return Protocol
