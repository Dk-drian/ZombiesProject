
local CHOICE_TABLE = {
	-- TYPES:
	--		1: Spell
	--		2: Item
	-- [level] = { { type, ID, chance }, ... }
	[2] = {
		{1, 90008, 100},
		{2, 23368, 100},
		{2, 26029, 100}
	},
	[3] = {
		{2, 50055, 100},
		{2, 23368, 100},
		{2, 26029, 100}
	},
	[4] = {
		{1, 90010, 100},
		{2, 23368, 100},
		{2, 26029, 100}
	},
	[5] = {
		{1, 90000, 100},
		{2, 50055, 100},
		{2, 23368, 100}
	},
	[6] = {
		{1, 90011, 100},
		{1, 90009, 100},
		{2, 23368, 33},
		{2, 50055, 33},
		{2, 26029, 33}
	},
	[7] = {
		{1, 90019, 100},
		{2, 23368, 100},
		{2, 26029, 100}
	},
	[8] = {
		{1, 90020, 100},
		{2, 23368, 100},
		{2, 26029, 100}
	}
}

local function PLAYER_EVENT_ON_LEVEL_CHANGE(event, player, oldLevel)
	local t = CHOICE_TABLE[oldLevel + 1]
	if not t then
		return
	end
	local results = {}
	local position = 1
	for i=1,3 do
		local inserted = false
		while not inserted do
			local row = t[position]
			if not row then
				position = 1
			else
				local valid = true
				local _type = row[1]
				local id = row[2]
				local chance = row[3]
				for _,v in pairs(results) do
					if v[1] == _type and v[2] == id then
						valid = false
						break
					end
					if v[1] == 1 and player:HasSpell(v[2]) then
						valid = false
						break
					end
				end
				if valid and math.random(1, 100) <= chance then
					table.insert(results, {_type, id})
					inserted = true
				end
			end
		end
	end
	
	local query = "INSERT INTO `spellselectionsystem` (guid, `level`, type1, option1, type2, option2, type3, option3) VALUES "
		.. "('" .. player:GetGUIDLow() .. "', '" .. (oldLevel + 1) .. "'"
	local message = "LEVELUP-" .. string.format("%02d", oldLevel + 1)
	for i=1,3 do
		query = query .. ", '" .. results[i][1] .. "'"
		message = message .. "-" ..  string.format("%01d", results[i][1])
		query = query .. ", '" .. results[i][2] .. "'"
		message = message .. "-" ..  string.format("%06d", results[i][2])
	end
	
	CharDBQuery(query .. ")")
	
	sendAddonMessage(player, message, 1)
end

RegisterPlayerEvent(13, PLAYER_EVENT_ON_LEVEL_CHANGE)

-----------
----------- receiving
-----------
local _DEBUG = false

-- Prototypes
local functionLookup

-- Handle addon messages
local function onReceiveAddonMsg(event, plr, Type, prefix, msg, receiver)
	if receiver ~= plr then return end
	if not msg or not prefix or not plr then return end
	if _DEBUG then print("[GOT] " .. prefix .. " | " .. msg) end
	local func = functionLookup[prefix]
	if func then
		func(plr, msg)
	end
end

RegisterServerEvent(30, onReceiveAddonMsg)

function SelectLevelReward(plr, msg)
	local option = tonumber(msg)
	if not option or option < 1 or option > 3 then
		return
	end
	local level = plr:GetLevel()
	local result = CharDBQuery("SELECT * FROM `spellselectionsystem` WHERE `guid` = '"..plr:GetGUIDLow().."' AND `level` = '"..level.."'")
	if result then
		local t = result:GetRow()
		if t["selected"] then
			return
		end
		local optionVal = t["option"..tostring(option)]
		local optionType = t["type"..tostring(option)]
		if (optionType == 1) then
			plr:LearnSpell(optionVal)
		elseif (optionType == 2) then
			plr:AddItem(optionVal, 1)
		end
		CharDBQuery("UPDATE `spellselectionsystem` SET `selectedType` = '"..tostring(optionType).."', `selected` = '"..tostring(optionVal).."' WHERE `guid` = '"..plr:GetGUIDLow().."' AND `level` = '"..level.."'")
	end
end

-- function lookup
functionLookup = {
	["SELECT"] = SelectLevelReward
}

--- on delete character

local function PLAYER_EVENT_ON_CHARACTER_DELETE(event, guid)
	if guid then
		CharDBQuery("DELETE FROM `spellselectionsystem` WHERE `guid` = '"..guid.."'")
	end
end

RegisterPlayerEvent(2, PLAYER_EVENT_ON_CHARACTER_DELETE)

---- on first login

local function PLAYER_EVENT_ON_FIRST_LOGIN(event, plr)
	if plr then
		for _,t in pairs(CHOICE_TABLE) do
			for _,r in pairs(t) do
				if r[1] == 2 then
					plr:ForceItemDownPlayersThroat(r[2])
				end
			end
		end
	end
end

RegisterPlayerEvent(30, PLAYER_EVENT_ON_FIRST_LOGIN)