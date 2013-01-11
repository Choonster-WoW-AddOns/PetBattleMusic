#!/bin/bash

# The path to your WoW directory
WOW_DIR="/home/coon-pc/Games/World of Warcraft"

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

# m2secs and getogglength code adapted from Chris F.A. Johnson's response here:
# http://www.realgeek.com/forums/mp3-ogg-length-in-bash-339970.html

ms2secs() {
	mins=${1%m:*}
	secs=${1#*m:}
	secs=${secs%s}
	secs=$(echo "$mins * 60 + $secs" | bc)
}


## store a newline character in a variable
NL='
'

getogglength(){
	## store the output of ogginfo in a variable
	pt=`ogginfo ${1}`
	
	if [[ $pt == *ERROR* ]]; # This isn't a valid ogg file.
	then
		invalidFile=true
		filelength=1
	else
		## remove everything up to the playing length
		pt=${pt#*Playback length: }
	
		## remove everything from the first newline
		pt=${pt%%${NL}*}
		ms2secs $pt
	
		filelength=$secs
	fi
}

# End getogglength code

getmp3length(){
	filelength=$(mp3info -p %S "$filename")
	
	if [[ $filelength == 0 ]]
	then
		invalidFile=true		
		filelength=1	
	fi
}

addfiles() {
	cd "$1"
	
	name=${1#$FULL_MUSIC_PATH/}
	printf "\nProcessing $name Music:\n\n"
	
	count=0
	for filename in *.{mp3,ogg}
	do
		invalidFile=false

		case $filename in
			*.ogg) getogglength $filename;;
			*.mp3) getmp3length $filename;;
		esac

		fullpath="$PWD/$filename"
		relpath=${fullpath#$WOW_DIR/} # Strip the WoW directory from the front of the complete path		
		
		echo "Processing $filename..."
		
		if $invalidFile
		then
			printf "\t\"%s\", %.2f, -- Warning: This file has an invalid or zero length!\n" "$relpath" $filelength >> "$FULL_LUA_PATH" # >> appends to the existing file content.
			echo "Warning: This file has an invalid or zero length!"
		else
			printf "\t\"%s\", %f,\n" "$relpath" $filelength >> "$FULL_LUA_PATH" # >> appends to the existing file content.
		fi

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