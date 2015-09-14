## 1.6
- Update Windows scripts to work with Windows 10
	- Thanks to badjujumojo of Curse for the index
- Update to 6.2

## 1.5
- Stop mute timer when starting a new battle before the previous battle's victory/defeat music has finished
	- Fixes music stopping completely and game music being left off in the middle of a battle

## 1.4
- Change PopulateMusic_Windows to use ogginfo for Ogg files
- Update unsupported OS message in Windows scripts

## 1.3
- Update to 6.0
    - Replace animation timers with new C_Timer system
- Add Windows 8.1 support to PopulateMusic_Windows scripts
- Add pause to end of shell script
- Replace %d with %.0f in format patterns
	- ogginfo can return non-integer file lengths, which don't work with %d.
- Stop using -r option to sed
	- -r is a GNU extension, not portable to all platforms
- Add option to use backslashes in PM_Unix.sh
	- Move `then` and `do` to same line as `if` and `for`
- Change PopulateMusic_Windows.js to compare file types instead of file extensions (which are only included in the name when they're shown in Windows explorer).
	- Move file type checks into the isAudioFile function to make the logic easier to change in future.
- Replace all == with === in PM_Windows.js
- Add a missing backslash in the main comment of ScriptParts\music_part0.lua and music.lua

## 1.2
- Victory/defeat music will now stop playing when you enter a new battle.
- Updated music.lua with the new instructions.
- Removed libraries from TOC/.pkgmeta
	- We're using animation objects instead of AceTimer now
- Added support for Ogg files to the scripts.
- Replaced README.txt with README.md (for GitHub)
- Updated TOC Interface number.
- Added support for separate music tables
	- Most public API functions now take a music table name as their first argument.
    - The script part files are now numbered to support easy construction of music.lua using for loops.
- Moved settings from core.lua to a new config.lua file.
	- Added a :GetOptionValue() method to the API to get the value of options set in config.lua
- More documentation changes
- Changed .docmeta format

## 1.1
- Added manual LICENCE.txt output
- Re-added the .docmeta and .pkgmeta files
- Added public API, removed debugging code
- Commented out CVar stuff