#!/bin/bash

# The path to your WoW directory
WOW_DIR="/home/bob-smith/Games/World of Warcraft"

# -------------
# END OF CONFIG
# -------------
# Do not change anything below here!

PBM_DIR="Interface/AddOns/PetBattleMusic"
MUSIC_DIR="$PBM_DIR/Music"

FULL_MUSIC_PATH="$WOW_DIR/$MUSIC_DIR"
FULL_LUA_PATH="$WOW_DIR/$PBM_DIR/music.lua"

read -r -d '' MUSIC_HEADER < "$WOW_DIR/$PBM_DIR/ScriptParts/music_header.txt"
read -r -d '' MUSIC_FOOTER < "$WOW_DIR/$PBM_DIR/ScriptParts/music_footer.txt"

echo $MUSIC_HEADER > "$FULL_LUA_PATH" # > overwrites the existing file content.

count=0

cd "$FULL_MUSIC_PATH"
shopt -s nullglob

for filename in *.mp3
do
	filelength=$(mp3info -p %S "$filename")
	relpath="$MUSIC_DIR/$filename"
	
	echo "Processing $filename..."

	echo -e "\t\"$relpath\", $filelength," >> "$FULL_LUA_PATH" # >> appends to the existing file content.
	let count+=1
done

echo "Finished processing $count files."

echo $MUSIC_FOOTER >> "$FULL_LUA_PATH"