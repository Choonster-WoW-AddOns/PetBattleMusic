local addon, ns = ...


-- Each music file needs to have an entry in this format:
-- "Path\\To\\Music\\File.mp3", XX,
-- 
-- "Path\\To\\Music\\File.mp3" is the path to the music file relative to the main WoW folder. 
-- This can either be wrapped in [[double square brackets]] with \single\backslash\ directory separators or in "quotation marks" ("double" or 'single') with \\double\\backslash\\ directory separators.
-- Both double square brackets and quotation marks can use /single/forward/slashes/ as directory separators in addition to single/double backslashes (it's probably best to just pick one style and use it for every entry).
-- Make sure you use the right directory separators, otherwise it won't work!
--
-- XX is the length of the music file in seconds
--
-- Examples:
--		"Interface\\AddOns\\PetBattleMusic\\Music\\fileone.mp3",  25, 	-- A file that's 25 seconds long
--		"Interface/AddOns/PetBattleMusic/Music/filetwo.mp3",      68,	-- A file that's 68 seconds (1 minute and 8 seconds) long
--	 	[[Interface\AddOns\PetBattleMusic\Music\filethree.mp3]], 125,	-- A file that's 125 seconds (2 minutes and 5 seconds) long
--		[[Interface/AddOns/PetBattleMusic/Music/filefour.mp3]],  164,	-- A file that's 164 seconds (2 minutes and 44 seconds) long
--
--
-- If you're on Windows, you can use the included PopulateMusic_Windows.js or PopulateMusic_Windows.ps1 scripts to automatically add all mp3 files in the PetBattleMusic\Music folder to this file.
-- The PopulateMusic_Windows.ps1 PowerShell script requires you to temporarily set your execution policy to unrestricted before running the script, so it's probably easier to use the JavaScript version (PopulateMusic_Windows.js).
-- Just open the script in a text editor (one with syntax highlighting will make this easier) and change the variable(s) at the top to match your computer's setup.
--
-- If you're on a Unix-like OS (e.g. Linux, Mac), you can use the included PopulateMusic_Unix.sh script instead. You will need to change the variable at the top to point to your WoW directory.
-- Note that this version requires the mp3info program if you have any MP3 files and the ogginfo program from the vorbis-tools package if you have any Ogg files.
-- vorbis-tools should be available from your OS's package manager and mp3info is available from the link below (or possibly your OS's package manager):
-- 		http://ibiblio.org/mp3info/
--
-- IMPORTANT: All three Populate_Music scripts will completely overwrite your existing music.lua file, so back up any changes you've made before running them.

-- General Music
ns.GENERAL_MUSIC = {
-- Put your entries below this line


