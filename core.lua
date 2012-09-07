--- Pet Battle Music is an AddOn that plays custom music during pet battles.
-- All functions with return values return nil plus an error on failure.
-- PBM_API.VERSION contains the current version string.
--
-- Each track is represented internally by two indices, one for the index of its path and the other for the index of its length.
-- Functions that return an index will always return the path index. Functions that take an index argument accept either index.
-- You can use PBM_PBMAPI:IndicesAreSameTrack(index1, index2) to test if two indices correspond to the same track.

--[[-----------------
-- START OF CONFIG --
--]]-----------------

local MAX_TRIES = 10 -- The number of times the AddOn will try to select a random track different to the previous one before using the last selection anyway
local DELAY = 0 -- The number of seconds to wait between a track ending and a new one being played.

-- Known Issue: (Beta Build 16030 and Live Build 16016 - 2012-09-02) If DELAY is greater than 0, the current track will start to repeat itself before the next one is played.
-- (DELAY = 0 means the next track is played before this can happen)
-- This happens even when the Sound_ZoneMusicNoDelay CVar is set to 0 (i.e. the "Loop Music" option disabled).

--[[---------------
-- END OF CONFIG --
--]]---------------

local random = math.random
local tinsert = table.insert
local tremove = table.remove

local addon, ns = ...

local VERSION = GetAddOnMetadata(addon, "X-Curse-Packaged-Version") or GetAddOnMetadata(addon, "Version")

local PBM = CreateFrame("Frame")
PBM:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)

LibStub("AceTimer-3.0"):Embed(PBM)

--[[-------
-- Music --
--]]-------

-- local MUSIC_LOOP_CVAR = "Sound_ZoneMusicNoDelay"
-- local MUSIC_LOOP_VALUE;

local IS_PLAYING = false
local PREVIOUS_TRACK_INDEX = 0
local CURRENT_TIMER;

local WARN = false

if type(ns.MUSIC[1]) == "table" then -- ns.MUSIC is in the old (1.0) format, update it to the new one
	WARN = true
	
	local tinsert = table.insert
	local unpack = unpack
	local oldMusic = ns.MUSIC
	local newMusic = {}
	
	for i = 1, #oldMusic do
		local trackInfo = oldMusic[i]
		if type(trackInfo) == "table" then
			local path, length = unpack(trackInfo)
			tinsert(newMusic, path)
			tinsert(newMusic, length)
		else
			tinsert(newMusic, trackInfo)
		end
	end
	
	ns.MUSIC = newMusic
end

local MUSIC = ns.MUSIC
local NUM_TRACKS = #MUSIC / 2
local errors = {}

for i = 1, #MUSIC do
	local entry = MUSIC[i]
	local entryType = type(entry)
	
	if i % 2 ~= 0 and entryType ~= "string" then -- Odd index, this should be a path
		tinsert(errors, ("Expected file path at index %d of ns.MUSIC, got %s (type %s)."):format(i, tostring(entry), entryType))
	elseif i % 2 == 0 and entryType ~= "number" then -- Even index, this should be a length
		tinsert(errors, ("Expected file length at index %d of ns.MUSIC, got %s (type %s)."):format(i, tostring(entry), entryType))
	end
end	

local function UpdateMusic()
	NUM_TRACKS = #MUSIC / 2
end

PBM:RegisterEvent("PET_BATTLE_OPENING_START") -- Fired when the pet battle starts
PBM:RegisterEvent("PET_BATTLE_OVER") -- Fired at the end of the pet battle (before PET_BATTLE_CLOSE, which seems to fire multiple times)
PBM:RegisterEvent("PLAYER_ALIVE")

function PBM:PlayNextTrack()
	local trackIndex, trackPath, trackLength;
	local tries = 0
	
	repeat
		tries = tries + 1
		trackIndex = random(NUM_TRACKS) * 2 -- random(#MUSIC / 2) * 2 will always return an even index, which should point to the length of a track
		trackLength = MUSIC[trackIndex]
		trackPath = MUSIC[trackIndex - 1] -- The corresponding track path will always be at the index before the length
	until (trackPath and trackLength and trackIndex ~= PREVIOUS_TRACK_INDEX) or tries > MAX_TRIES -- Select a random track, but make sure it's not the current one (only try this MAX_TRIES times then break)
	
	if trackPath and trackLength then
		PlayMusic(trackPath)
		-- We schedule the next timer to go off DELAY seconds after the current track ends
		CURRENT_TIMER = self:ScheduleTimer("PlayNextTrack", trackLength + DELAY)
		PREVIOUS_TRACK_INDEX = trackIndex
		IS_PLAYING = true
	else
		CURRENT_TIMER = nil -- We couldn't find a track to play
		IS_PLAYING = false
	end
end

function PBM:CancelCurrentTimer()
	if CURRENT_TIMER then
		self:CancelTimer(CURRENT_TIMER)
		CURRENT_TIMER = nil
	end
end

function PBM:StopMusic()
	if IS_PLAYING then
		StopMusic()
	end
	self:CancelCurrentTimer()
	IS_PLAYING = false
end

function PBM:PET_BATTLE_OPENING_START()
	-- MUSIC_LOOP_VALUE = GetCVar(MUSIC_LOOP_CVAR)
	-- SetCVar(MUSIC_LOOP_CVAR, "0")
	self:PlayNextTrack()
end

function PBM:PET_BATTLE_OVER()
	self:StopMusic()
	-- SetCVar(MUSIC_LOOP_CVAR, MUSIC_LOOP_VALUE)
end

function PBM:PLAYER_ALIVE()
	if NUM_TRACKS > 0 then
		print(("PetBattleMusic: Found %d music tracks."):format(NUM_TRACKS))
		if WARN then
			print("PetBattleMusic: music.lua is in the old (version 1.0) format. You should change it to the new (version 1.01) format.")
		end
	else
		print("PetBattleMusic: No music was found. Edit music.lua to add some.")
		self:UnregisterAllEvents()
	end
	
	if #errors > 0 then
		print("PetBattleMusic: Encountered errors while processing the music table:")
		print(table.concat(errors, "\n"))
		errors = nil
	end
end

--[[------------
-- Public API --
--]]------------

local function GetPathAndLength(index)
	local entry = MUSIC[index]
	local entryType = type(entry)
	if not entry then return nil, "invalid index" end
	
	local path, length;
	if entryType == "string" then -- This is a path, the length will be at the next index
		path = entry
		length = MUSIC[index + 1]
	elseif entryType == "number" then -- This is a length, the path will be at the previous index
		path = MUSIC[index - 1]
		length = entry
	else
		return nil, nil, ("invalid entry %s (type %s) at index %d (expected number or string)"):format(tostring(entry), entryType, index)
	end
	
	return path, length
end

PBMAPI = {}
PBMAPI.VERSION = VERSION

--- Adds a track to the track list.
-- @param path (string) The path to a music file
-- @param length (number) The length of the music file in seconds
-- @return index (number) The index of the track, can be passed to :RemoveTrack to remove the track from the track list.
function PBMAPI:AddTrack(path, length)
	local lengthNum = tonumber(length)
	if type(path) ~= "string" then return nil, "bad argument #1 to 'AddTrack' (string expected, got " .. type(path) .. ")" end
	if not lengthNum then return nil, "bad argument #2 to 'AddTrack' (number expected, got " .. type(length) .. ")" end
	
	tinsert(MUSIC, path)
	tinsert(MUSIC, lengthNum)
	UpdateMusic()
	
	return #MUSIC - 1
end

--- Removes a track from the list.
-- @param index (number) The index of the track to remove
-- @return path (string) The path of the track that was removed
-- @return length (number) The length of the track that was removed
function PBMAPI:RemoveTrack(index)
	local indexNum = tonumber(index)
	if not indexNum then return nil, "bad argument #1 to 'RemoveTrack' (number expected, got " .. type(index) .. ")" end
	
	local path, length;
	local entry = MUSIC[index]
	if type(entry) == "string" then -- This is a path, the length will move down to index when we remove it
		path = tremove(MUSIC, index)
		length = tremove(MUSIC, index)
	else -- This is a length, we remove the path from index-1
		path = tremove(MUSIC, index - 1)
		length = tremove(MUSIC, index - 1)
	end
	return path, length
end

--- Plays a random track.
function PBMAPI:PlayRandomTrack()
	PBM:CancelCurrentTimer()
	PBM:PlayNextTrack()
end

--- Plays the track at a specified index
-- @param index (number) The index of the track to play
-- @return path (string) The path of the track that was played
-- @return length (number) The length of the track that was played
function PBMAPI:PlaySpecificTrack(index)
	local path, length, err = GetPathAndLength(index)
	
	if err then
		return nil, err
	elseif path and length then
		PlayMusic(path)
		-- We schedule the next timer to go off DELAY seconds after the current track ends
		CURRENT_TIMER = PBM:ScheduleTimer("PlayNextTrack", length + DELAY)
		PREVIOUS_TRACK_INDEX = index
		IS_PLAYING = true
		return path, length
	elseif not path then
		return nil, "no path found"
	elseif not length then
		return nil, "no length found"
	end
end

--- Stops the current track.
function PBMAPI:StopMusic()
	PBM:StopMusic()
end

--- Returns whether or not a track is currently playing.
-- @return isPlaying (boolean) true if a track is playing, false if not
function PBMAPI:IsPlaying()
	return IS_PLAYING
end

--- Returns the index, path and length of the current track or nil if no track is playing.
-- @return index (number) The index of the track that's playing
-- @return path (string) The path to track that's playing
-- @return length (number) The length of the track that's playing
function PBMAPI:GetCurrentTrack()
	if IS_PLAYING then
		return PREVIOUS_TRACK_INDEX - 1, MUSIC[PREVIOUS_TRACK_INDEX - 1], MUSIC[PREVIOUS_TRACK_INDEX]
	else
		return nil
	end
end

--- Returns the index first track with the specified path
-- @param path (string) The path to search for
-- @return index (number) The index of the track
function PBMAPI:GetTrackIndexByPath(path)
	if type(path) ~= "string" then return nil, "bad argument #1 to 'GetTrackIndexByPath' (string expected, got " .. type(path) .. ")" end
	
	path = path:lower()
	for i = 1, #MUSIC do
		local entry = MUSIC[i]
		if type(entry) == "string" and entry:lower() == path then
			return i
		end
	end
	
	return nil, "path not found"
end

--- Returns the path and length of the track at index
-- @param index (number) The track index to return information for
-- @return path (string) The path to the track
-- @return length (number) The length of the track
function PBMAPI:GetTrackInfo(index)
	local path, length, err = GetPathAndLength(index)
	
	if err then
		return nil, err
	elseif path and length then
		return path, length
	elseif not path then
		return nil, "path not found"
	elseif not length then
		return nil, "length not found"
	end
end

--- Returns whether or not the two indices represent the same track.
-- @param index1 (number) A track index
-- @param index2 (number) A track index
-- @return sameTrack (boolean) true if the two indices represent the same track (or are the same), false if they represent different tracks or if either index does not correspond to a track
function PBMAPI:IndicesAreSameTrack(index1, index2)
	if index1 == index2 then
		return true
	elseif math.abs(index1 - index2) > 1 then -- The indices are more than 1 unit apart, so they can't be the same track
		return false
	end
	
	local entry1, entry2 = MUSIC[index1], MUSIC[index2]
	local entry1Type, entry2Type = type(entry1), type(entry2)
	
	if entry1Type == "string" and entry2Type == "number" then -- entry1 is a path, entry2 is a length; if they're the same track then index2 will be 1 more than index1
		return index2 - index1 == 1
	elseif entry1Type == "number" and entry2Type == "string" then -- entry2 is a path, entry1 is a length; if they're the same track then index1 will be 1 more than index2
		return index1 - index2 == 1
	else
		return false
	end
end	

--- Returns the path index of the track at the given index
-- @param index (number) A track index (path or length)
-- @return pathIndex (number) The corresponding path index
function PBMAPI:ToPathIndex(index)
	local entryType = type(MUSIC[index])
	if entryType == "string" then
		return index
	elseif entryType == "number" then
		return index - 1
	else
		return nil, "invalid index"
	end
end

--[[---------------------
-- Announcements (NYI) --
--]]---------------------

--[[ -- This part isn't complete yet.

PBM:RegisterEvent("PET_BATTLE_HEALTH_CHANGED") -- Fired when a pet's health changes (due to damage or healing)

local PET_FACTIONS = {
	[LE_BATTLE_PET_WEATHER] = "Weather",
	[LE_BATTLE_PET_ALLY] = "Ally",
	[LE_BATTLE_PET_ENEMY] = "Enemy",
}
	
	

function PBM:PET_BATTLE_HEALTH_CHANGED(dest, source, amount)
	local eventType;
	if amount > 0 then
		eventType = "heal"
	else
		eventType = "damage"
	end
	
	local sourceStr = PET_FACTIONS[source]
	local destStr = PET_FACTIONS[dest]
	local actionStr = amount > 0 and "Damaged" or "Healed"
	
	local methodName = sourceStr .. actionStr .. destStr
	self[methodName](self, amount)
end

--]]