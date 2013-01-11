--- Pet Battle Music is an AddOn that plays custom music during pet battles.
-- All functions with return values return nil plus an error on failure.
-- PBM_API.VERSION contains the current version string.
--
-- Each track is represented internally by two indices, one for the index of its path and the other for the index of its length.
-- Functions that return an index will always return the path index. Functions that take an index argument accept either index.
-- You can use PBM_PBMAPI:IndicesAreSameTrack(index1, index2) to test if two indices correspond to the same track.

-- Known Issue: (Beta Build 16030 and Live Build 16016 - 2012-09-02) If DELAY is greater than 0, the current track will start to repeat itself before the next one is played.
-- (DELAY = 0 means the next track is played before this can happen)
-- This happens even when the Sound_ZoneMusicNoDelay CVar is set to 0 (i.e. the "Loop Music" option disabled).

--@debug@
local function debug(...)
	print("PBM_DEBUG:", ...)
end
--@end-debug@

-- GLOBALS: GetCVar, SetCVar, StopSound, StopMusic

local _; -- Localise the underscore to prevent global leakage and GlyphUI taint

local _G = _G
local print, type, tostring, tonumber = print, type, tostring, tonumber
local abs, random, max = math.abs, math.random, math.max
local tinsert, tremove = table.insert, table.remove

local IsInBattle = C_PetBattles.IsInBattle
local IsWildBattle = C_PetBattles.IsWildBattle
local IsPlayerNPC = C_PetBattles.IsPlayerNPC

local LE_BATTLE_PET_ALLY = LE_BATTLE_PET_ALLY
local LE_BATTLE_PET_ENEMY = LE_BATTLE_PET_ENEMY

local addon, ns = ...

local VERSION = GetAddOnMetadata(addon, "X-Curse-Packaged-Version") or GetAddOnMetadata(addon, "Version")

local PBM = CreateFrame("Frame")
PBM:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)

local Timer = AnimTimerFrame:CreateAnimationGroup("PetBattleMusic_MusicTimerGroup") -- Controls the playing of the next track.
local TimerAnimation = Timer:CreateAnimation("Animation")

Timer:SetScript("OnFinished", function(self)
	PBM:PlayNextTrack(self.scheduleNext)
end)


local MuteTimer = AnimTimerFrame:CreateAnimationGroup("PetBattleMusic_MuteTimerGroup") -- Controls the unmuting of music when the battle ends.
local MuteTimerAnimation = MuteTimer:CreateAnimation("Animation")

MuteTimer:SetScript("OnFinished", function(self)
	local EnableMusic = self.EnableMusic
	
	--@debug@
	debug("MuteTimer:OnFinished", EnableMusic)
	--@end-debug@

	if EnableMusic then
		self.EnableMusic = nil
		_G.SetCVar("Sound_EnableMusic", EnableMusic)
	end
end)

--[[-------
-- Music --
--]]-------

-- Configuration variables
local MAX_TRIES = ns.MAX_TRIES
local DELAY = ns.DELAY
local MUSIC_CHANNEL = ns.MUSIC_CHANNEL
local MUTE_MUSIC = MUSIC_CHANNEL ~= "Music" and ns.MUTE_MUSIC

-- Music tables
local GENERAL_MUSIC  = ns.GENERAL_MUSIC
local WILD_MUSIC     = ns.USE_WILD_MUSIC     and ns.WILD_MUSIC     or GENERAL_MUSIC
local TRAINER_MUSIC  = ns.USE_TRAINER_MUSIC  and ns.TRAINER_MUSIC  or GENERAL_MUSIC
local PLAYER_MUSIC   = ns.USE_PLAYER_MUSIC   and ns.PLAYER_MUSIC   or TRAINER_MUSIC
local VICTORY_MUSIC  = ns.USE_VICTORY_MUSIC  and ns.VICTORY_MUSIC  
local DEFEAT_MUSIC   = ns.USE_DEFEAT_MUSIC   and ns.DEFEAT_MUSIC   

local MUSIC;
local NUM_TRACKS;

-- Important variables
local FirstLoad = true
local IsPlaying = false
local PreviousTrackIndex;
local CurrentSoundHandle;

--@debug@
local MusicTables = {
	general = GENERAL_MUSIC,
	wild = WILD_MUSIC,
	trainer = TRAINER_MUSIC,
	player = PLAYER_MUSIC,
	victory = VICTORY_MUSIC,
	defeat = DEFEAT_MUSIC,
}

local ReverseMusicTables = {}

for k, v in pairs(MusicTables) do
	ReverseMusicTables[v] = k
end
--@end-debug@

local errors = {}

local function checkMusicTable(key)
	local music = ns[key]
	if not music then return end
	
	for i = 1, #music do
		local entry = music[i]
		local entryType = type(entry)
		
		if i % 2 ~= 0 and entryType ~= "string" then -- Odd index, this should be a path
			tinsert(errors, ("Expected file path at index %d of ns.%s, got %s (type %s)."):format(i, key, tostring(entry), entryType))
		elseif i % 2 == 0 and entryType ~= "number" then -- Even index, this should be a length
			tinsert(errors, ("Expected file length at index %d of ns.%s, got %s (type %s)."):format(i, key, tostring(entry), entryType))
		end
	end
end

for k, v in pairs(ns) do -- Check that the music tables are formatted properly
	if type(v) == "table" then
		checkMusicTable(k)
	end
end

local function SetMusicTable(musicTable)
	--@debug@
	debug("SetMusicTable", ReverseMusicTables[musicTable])
	--@end-debug@
	
	MUSIC = musicTable
	NUM_TRACKS = musicTable and max(#musicTable, 1) or 1
	PreviousTrackIndex = nil
end

local function PlayTrack(path, length, index, scheduleNext)
	--@debug@
	debug("PlayTrack!", "Path:", path, "Length:", length, "Index:", index, "ScheduleNext:", scheduleNext) -- DEBUG!
	--@end-debug@
	
	if MUSIC_CHANNEL == "Music" then
		_G.PlayMusic(path)
	else
		_, CurrentSoundHandle = _G.PlaySoundFile(path, MUSIC_CHANNEL)
	end
	
	if scheduleNext then
		TimerAnimation:SetDuration(length + DELAY) -- We schedule the next timer to go off DELAY seconds after the current track ends
		Timer.scheduleNext = scheduleNext
		Timer:Play()
	end
	
	PreviousTrackIndex = index
	IsPlaying = true
end

PBM:RegisterEvent("PET_BATTLE_OPENING_START") -- Fired when the pet battle starts
PBM:RegisterEvent("PET_BATTLE_FINAL_ROUND")   -- Fired just before the end of the pet battle. arg1 is the winner (LE_BATTLE_PET_(ALLY/ENEMY))
PBM:RegisterEvent("PET_BATTLE_OVER")          -- Fired at the end of the pet battle (before PET_BATTLE_CLOSE, which seems to fire multiple times)
PBM:RegisterEvent("PLAYER_ENTERING_WORLD")    -- Fired at login.

function PBM:PlayNextTrack(scheduleNext)
	if not MUSIC then return end
	
	local trackIndex, trackPath, trackLength;
	local tries = 0
	
	repeat
		tries = tries + 1
		trackIndex = random(NUM_TRACKS) * 2 -- random(#MUSIC / 2) * 2 will always return an even index, which should point to the length of a track
		trackLength = MUSIC[trackIndex]
		trackPath = MUSIC[trackIndex - 1] -- The corresponding track path will always be at the index before the length
	until (trackPath and trackLength and trackIndex ~= PreviousTrackIndex) or tries > MAX_TRIES -- Select a random track, but make sure it's not the current one (only try this MAX_TRIES times then break)
	
	if trackPath and trackLength then
		PlayTrack(trackPath, trackLength, trackIndex, scheduleNext)
		return trackLength
	else
		-- We couldn't find a track to play
		IsPlaying = false
	end
end

function PBM:StopMusic()
	if IsPlaying then
		if MUSIC_CHANNEL == "Music" then
			_G.StopMusic()
		elseif CurrentSoundHandle then
			_G.StopSound(CurrentSoundHandle)
		end
	end
	Timer:Stop()
	IsPlaying = false
	PreviousTrackIndex = nil
end

function PBM:PET_BATTLE_OPENING_START()
	if IsPlaying then
		self:StopMusic()
	end
	
	if MUTE_MUSIC then
		MuteTimer.EnableMusic = _G.GetCVar("Sound_EnableMusic")
		_G.SetCVar("Sound_EnableMusic", 0)
		
		--@debug@
		debug("MuteTimer.EnableMusic", MuteTimer.EnableMusic)
		--@end-debug@
	end
	
	if IsWildBattle() then
		SetMusicTable(WILD_MUSIC)
	elseif IsPlayerNPC(LE_BATTLE_PET_ENEMY) then
		SetMusicTable(TRAINER_MUSIC)
	else
		SetMusicTable(PLAYER_MUSIC)
	end
	
	self:PlayNextTrack(true)
end

function PBM:PET_BATTLE_FINAL_ROUND(winner)
	SetMusicTable(winner == LE_BATTLE_PET_ALLY and VICTORY_MUSIC or DEFEAT_MUSIC)

	self:StopMusic()
	
	local trackLength = self:PlayNextTrack(false) -- Only play victory/defeat music once
	MuteTimerAnimation:SetDuration((trackLength or 0) + 0.5)
	-- Unmute the game music 0.5 seconds after the victory/defeat track finishes or 0.5 seconds from now if we didn't play a track
	-- The extra 0.5 seconds allows time for the game's pet battle music to stop
end

function PBM:PET_BATTLE_OVER()
	MuteTimer:Play()
	
	--@debug@
	debug("PBM: PET_BATTLE_OVER!") -- DEBUG
	--@end-debug@
end

function PBM:PLAYER_ENTERING_WORLD()
	if FirstLoad then
		FirstLoad = false
		local numGeneral = #GENERAL_MUSIC / 2
		local numWild = #WILD_MUSIC / 2
		local numPlayer = #PLAYER_MUSIC / 2
		local numVictory = VICTORY_MUSIC and #VICTORY_MUSIC / 2 or 0
		local numDefeat = DEFEAT_MUSIC and #DEFEAT_MUSIC / 2 or 0
		local total = numGeneral + numWild + numPlayer + numVictory + numDefeat
		
		if total > 0 then
			print(("PetBattleMusic: Found a total of %d music tracks. %d General, %d Wild, %d Player, %d Victory and %d Defeat"):format(total, numGeneral, numWild, numPlayer, numVictory, numDefeat))
		else
			print("PetBattleMusic: No music was found. Edit music.lua to add some.")
			self:UnregisterAllEvents()
		end
		
		if #errors > 0 then
			print(("PetBattleMusic: Encountered %d errors while processing the music tables. Use /pbmerrors to display them."):format(#errors))
			
			SLASH_PBMERRORS1 = "/pbmerrors"
			SlashCmdList.PBM_ERRORS = function()
				print("PetBattleMusic: Encountered errors while processing the music tables.")
				print(table.concat(errors, "\n"))
			end
		end
	end
	
	self:PET_BATTLE_OVER()
	if IsInBattle() then
		self:PET_BATTLE_OPENING_START()
	end
end

--[[------------
-- Public API --
--]]------------

--- Music Tables
-- @class table
-- @name MusicTables
-- @field general The general music table
-- @field wild The wild music table
-- @field trainer The trainer music table
-- @field player The player music table
-- @field victory The victory music table
-- @field defeat The defeat music table
local MusicTables = {
	general = GENERAL_MUSIC,
	wild = WILD_MUSIC,
	trainer = TRAINER_MUSIC,
	player = PLAYER_MUSIC,
	victory = VICTORY_MUSIC,
	defeat = DEFEAT_MUSIC,
}

local ReverseMusicTables = {}

for k, v in pairs(MusicTables) do
	ReverseMusicTables[v] = k
end

local function GetPathAndLength(musicTable, index)
	local music;
	if musicTable then
		music = MusicTables[musicTable]
		if not music then return nil, nil, "invalid music table" end
	else
		music = MUSIC
		if not music then return nil, nil, "no music table has been set" end
	end
	
	local entry = music[index]
	local entryType = type(entry)
	if not entry then return nil, nil, "invalid index" end
	
	local path, length;
	if entryType == "string" then -- This is a path, the length will be at the next index
		path = entry
		length = music[index + 1]
	elseif entryType == "number" then -- This is a length, the path will be at the previous index
		path = music[index - 1]
		length = entry
	else
		return nil, nil, ("invalid entry %s (type %s) at index %d (expected number or string)"):format(tostring(entry), entryType, index)
	end
	
	return path, length
end

PBMAPI = {}
PBMAPI.VERSION = VERSION

--- Adds a track to the track list.
-- @param musicTable (string) The music table to add the track to
-- @param path (string) The path to a music file
-- @param length (number) The length of the music file in seconds
-- @return index (number) The index of the track, can be passed to :RemoveTrack to remove the track from the track list.
function PBMAPI:AddTrack(musicTable, path, length)
	local music = MusicTables[musicTable]
	if not music then return nil, "invalid music table" end
	
	local lengthNum = tonumber(length)
	if type(path) ~= "string" then return nil, "bad argument #2 to 'AddTrack' (string expected, got " .. type(path) .. ")" end
	if not lengthNum then return nil, "bad argument #3 to 'AddTrack' (number expected, got " .. type(length) .. ")" end
	
	tinsert(music, path)
	tinsert(music, lengthNum)
	
	return #music - 1
end

--- Removes a track from the list.
-- @param musicTable (string) The music table to remove the track from
-- @param index (number) The index of the track to remove
-- @return path (string) The path of the track that was removed
-- @return length (number) The length of the track that was removed
function PBMAPI:RemoveTrack(musicTable, index)
	local music = MusicTables[musicTable]
	if not music then return nil, "invalid music table" end
	
	local indexNum = tonumber(index)
	if not indexNum then return nil, "bad argument #2 to 'RemoveTrack' (number expected, got " .. type(index) .. ")" end
	
	local path, length;
	local entry = music[index]
	if type(entry) == "string" then -- This is a path, the length will move down to index when we remove it
		path = tremove(music, index)
		length = tremove(music, index)
	else -- This is a length, we remove the path from index-1
		path = tremove(music, index - 1)
		length = tremove(music, index - 1)
	end
	return path, length
end

--- Plays a random track.
-- @param musicTable (string/nil) The music table to play a track from. If this is nil, the current music table will be used.
-- @param scheduleNext (boolean) If true, random tracks will continue to be played after this one.
function PBMAPI:PlayRandomTrack(musicTable, scheduleNext)
	if musicTable then
		local music = MusicTables[musicTable]
		if not music then return nil, "invalid music table" end
		SetMusicTable(music)
	end

	PBM:StopMusic()
	PBM:PlayNextTrack(scheduleNext)
end

--- Plays the track at a specified index
-- @param musicTable (string/nil) The music table to play a track from. If this is nil, the current music table will be used.
-- @param index (number) The index of the track to play
-- @param scheduleNext (boolean) If true, random tracks will continue to be played after this one.
-- @return path (string) The path of the track that was played
-- @return length (number) The length of the track that was played
function PBMAPI:PlaySpecificTrack(musicTable, index, scheduleNext)
	local path, length, err = GetPathAndLength(musicTable, index)
	
	if err then
		return nil, err
	elseif path and length then
		PlayTrack(path, length, index, scheduleNext)
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
	return IsPlaying
end

--- Returns the current music table as well as the index, path and length of the current track.
-- Returns nil if no track is playing.
-- @return musicTable (string/nil) The name of the current music table. This will be nil if no music table has been set yet.
-- @return index (number) The index of the track that's playing
-- @return path (string) The path to track that's playing
-- @return length (number) The length of the track that's playing
function PBMAPI:GetCurrentTrack()
	if IsPlaying then
		return ReverseMusicTables[MUSIC], (PreviousTrackIndex or 0) - 1, MUSIC[PreviousTrackIndex - 1], MUSIC[PreviousTrackIndex]
	else
		return nil
	end
end

--- Returns the index of first track with the specified path
-- @param musicTable (string/nil) The music table to search in. If this is nil, the current music table will be used.
-- @param path (string) The path to search for
-- @return index (number) The index of the track
function PBMAPI:GetTrackIndexByPath(musicTable, path)
	local music = MusicTables[musicTable]
	if not music then return nil, "invalid music table" end
	
	local pathType = type(path)
	if pathType ~= "string" then return nil, "bad argument #2 to 'GetTrackIndexByPath' (string expected, got " .. pathType .. ")" end
	
	path = path:lower()
	for i = 1, #music do
		local entry = music[i]
		if type(entry) == "string" and entry:lower() == path then
			return i
		end
	end
	
	return nil, "path not found"
end

--- Returns the path and length of the track at index
-- @param musicTable (string/nil) The music table to search in. If this is nil, the current music table will be used.
-- @param index (number) The track index to return information for
-- @return path (string) The path to the track
-- @return length (number) The length of the track
function PBMAPI:GetTrackInfo(musicTable, index)
	local path, length, err = GetPathAndLength(musicTable, index)
	
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
-- @param musicTable (string) The music table to search in
-- @param index1 (number) A track index
-- @param index2 (number) A track index
-- @return sameTrack (boolean) true if the two indices represent the same track (or are the same), false if they represent different tracks or if either index does not correspond to a track
function PBMAPI:IndicesAreSameTrack(musicTable, index1, index2)
	if index1 == index2 then
		return true
	elseif abs(index1 - index2) > 1 then -- The indices are more than 1 unit apart, so they can't be the same track
		return false
	end
	
	local music = MusicTables[musicTable]
	if not music then return nil, "invalid music table" end
	
	local entry1, entry2 = music[index1], music[index2]
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
function PBMAPI:ToPathIndex(musicTable, index)
	local music = MusicTables[musicTable]
	if not music then return nil, "invalid music table" end
	
	local entryType = type(music[index])
	if entryType == "string" then
		return index
	elseif entryType == "number" then
		return index - 1
	else
		return nil, "invalid index"
	end
end

--- Returns the value of an option set in config.lua
-- Can't be used to get a music table, all music table manipulation must be done using the API.
-- @param option (string) The name of the option
function PBMAPI:GetOptionValue(option)
	local value = ns[option]
	
	return type(value) ~= "table" and value or nil
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