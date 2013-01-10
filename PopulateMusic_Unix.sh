#!/bin/bash

# The path to your WoW directory
WOW_DIR="/home/CoonPC/Games/World of Warcraft"

# -------------
# END OF CONFIG
# -------------
# Do not change anything below here!

PBM_DIR="Interface/AddOns/PetBattleMusic"
MUSIC_DIR="$PBM_DIR/Music"

FULL_MUSIC_PATH="$WOW_DIR/$MUSIC_DIR"
FULL_LUA_PATH="$WOW_DIR/$PBM_DIR/music.lua"
FULL_SCRIPTPARTS_PATH="$WOW_DIR/$PBM_DIR/ScriptParts"

DIRECTORIES=( General Wild Trainer Player Victory Defeat )

shopt -s nullglob

function addfiles {
	cd "$1"
	
	name=${1#$FULL_MUSIC_PATH/}
	printf "\nProcessing $name Music:\n\n"
	
	count=0
	for filename in *.mp3
	do
		filelength=$(mp3info -p %S "$filename")
		fullpath="$PWD/$filename"
		relpath=${fullpath#$WOW_DIR/} # Strip the WoW directory from the front of the complete path		
		
		echo "Processing $filename..."
	
		printf "\t\"%s\", %d,\n" "$relpath" $filelength >> "$FULL_LUA_PATH" # >> appends to the existing file content.
		let count+=1
	done
	printf "\nFinished processing $count files.\n"
}

printf "" > "$FULL_LUA_PATH" # > overwrites the existing file content. We write an empty string just to wipe the existing file content.

for (( i = 0; i <= 5; i++)) # BASH arrays are zero-based!
do
	read -r -d '' part < "$FULL_SCRIPTPARTS_PATH/music_part$i.lua"
	echo "$part" >> "$FULL_LUA_PATH"
	
	printf "\n" >> "$FULL_LUA_PATH"
	addfiles "$FULL_MUSIC_PATH/${DIRECTORIES[i]}"
	printf "\n" >> "$FULL_LUA_PATH"
	
	printf "\n"
done

read -r -d '' MUSIC_FOOTER < "$FULL_SCRIPTPARTS_PATH/music_footer.lua"
echo "$MUSIC_FOOTER" >> "$FULL_LUA_PATH"