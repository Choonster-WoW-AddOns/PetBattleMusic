// ---------------
// START OF CONFIG
// ---------------

// The path to your WoW folder (using double backslashes as directory separators)
var WOW_DIR = "C:\\Users\\Public\\Games\\World of Warcraft"

// ---------------
//  END OF CONFIG
// ---------------
// Do not change anything below here!

if (typeof WScript === "undefined")
{
	throw new Error("Unsupported environment. Make sure you're running this script with Microsoft(R) Windows Based Script Host.")
}

// Get the OS version
// http://stackoverflow.com/questions/351282/find-os-name-version-using-jscript
var wbemFlagReturnImmediately = 0x10
var wbemFlagForwardOnly = 0x20
var objWMIService = GetObject("winmgmts:\\\\.\\root\\CIMV2")
var colItems = objWMIService.ExecQuery("SELECT * FROM Win32_OperatingSystem", "WQL", wbemFlagReturnImmediately | wbemFlagForwardOnly)

var enumItems = new Enumerator(colItems)
var objItem = enumItems.item()

var OSVER = objItem.Version
// End OS version code

// Get the index of the length property
// http://stackoverflow.com/questions/1674134/detecting-the-version-and-company-name-of-an-exe-using-jscript
// http://www.kixtart.org/forums/ubbthreads.php?ubb=showflat&Number=160880&page=1
var LENGTH_INDEX

function isVer() // Quick helper function that takes an arbitrary number of version strings and checks if any of them match OSVER
{
	for (var i = 0; i < arguments.length; i++)
	{
		if (OSVER.indexOf(arguments[i] + ".") === 0) // Add a dot to the end of the string to make sure "6.1" doesn't match "6.10.XXXX" (just in case MS ever uses a double digit NT subversion)
			return true
	}
	return false
}	

if ( isVer("10.0", "6.3", "6.2", "6.1", "6.0") ) // Windows 10 (NT 10.0) [Thanks to badjujumojo of Curse for this index], Windows 8.1/Server 2012 R2 (NT 6.3), Windows 8/Server 2012 (NT 6.2) [Thanks to user_151079 of Curse for this index], Windows 7/Server 2008 R2 (NT 6.1) and Windows Vista/Server 2008 (NT 6.0)
{
	LENGTH_INDEX = 27 // Length
}
else if ( isVer("5.2", "5.1") ) // Windows XP (NT 5.2/5.1), Windows Server 2003 R1/R2 (NT 5.2)
{
	LENGTH_INDEX = 21 // Duration
}
else if ( isVer("5.0") ) // Windows 2000 (NT 5.0)
{
	LENGTH_INDEX = 33 // Play Length
}
else
{
	throw new Error(
		(
		"\n\nUnknown Windows version. This script only supports Windows 10, 8/8.1, 7, Vista, XP and 2000 as well as Windows Server 2012, 2008 and 2003.\n\n\
		If you want support added for your version of Windows, please run the included GetLengthIndex_Windows.js script and click OK until the popup shows something like Length, Duration or Play Length as the Property Name.\n\n\
		Once you get to this popup, leave a comment on Curse or WoW Interface with its contents.\n\n\
		If the script generates an error instead of a series of popups, leave a comment on Curse or WoW Interface with the error and which version of Windows you're using.\n"
		).replace(/\t+/g, "") // Remove tabs from string.
	)
}
// End length index code

// Iterate over the files in the music folder

var PBM_DIR = WOW_DIR + "\\Interface\\AddOns\\PetBattleMusic"
var FULL_MUSIC_DIR = PBM_DIR + "\\Music"
var FULL_SCRIPTPARTS_DIR = PBM_DIR + "\\ScriptParts"

var DIRECTORIES = [ "General", "Wild", "Trainer", "Player", "Victory", "Defeat" ]

var ForReading = 1
var ForWriting = 2
var TriStateFalse = 0

var fso = new ActiveXObject("Scripting.FileSystemObject")
var musicLua = fso.OpenTextFile(PBM_DIR + "\\music.lua", ForWriting, false, TriStateFalse)

var shell = new ActiveXObject("Shell.Application")

var isConsole = WScript.FullName.search(/CScript\.exe/i) > -1

function echo(str)
{
	if (isConsole){ WScript.Echo(str) }
}

var mp3Regex = /\.mp3$/, oggRegex = /\.ogg$/
function getAudioFileExtension(file)
{
	var fileName = file.Name	
	
	if (mp3Regex.test(fileName) || oggRegex.test(fileName))
	{
		return fileName.substring(fileName.length - 3)
	}
	else
	{
		return null
	}
}

function getMP3Length(folder, file)
{
	var lengthArray = folder.GetDetailsOf(file, LENGTH_INDEX).split(":").reverse() // We reverse the array so the seconds are first, the minutes second, etc.
	var length = 0.0
	
	for (var ind = 0; ind <= lengthArray.length; ind++)
	{
		if (typeof lengthArray[ind] != "undefined")
		{
			var num = parseInt(lengthArray[ind], 10) // Always specify radix otherwise numbers starting with 0 will be treated as octal
			length += (num * Math.pow(60, ind))
		}
	}
	
	return length
}

var lengthRegex = /Playback length: (\d+)m:(\d+)\.?\d*/
var oggInfoPath = '"' + PBM_DIR + '\\ogginfo\\ogginfo.exe" "'
var wsShell = WScript.CreateObject("WScript.Shell")

function getOggLength(file)
{
	var result = wsShell.Exec(oggInfoPath + file.Path + '"')
	var output = result.StdOut.ReadAll()
	
	var matches = lengthRegex.exec(output)
	
	if (matches === null)
	{
		echo(output)
		return 0
	}
	
	if (matches.length < 3)	return 0
	
	var minutes = matches[1], seconds = matches[2]
	return minutes * 60 + seconds
}

// JScript doesn't include any sort of sprintf (C) or string.format (Lua) function (or access to .NET, which does have one), so we have to use a whole lot of concatenation.
function AddFiles(path)
{	
	var folder = shell.Namespace(path)
	var files = folder.Items()
	
	var count = 0
	
	for (var i = 0; i < files.Count; i++)
	{
		var file = files.Item(i)
		
		var extension = getAudioFileExtension(file)
		if ( extension !== null ){
			var length
			
			if (extension === "mp3")
			{
				length = getMP3Length(folder, file)
			}
			else
			{
				length = getOggLength(file)
			}			
			
			var invalidLength = false
			
			if ( isNaN(length) || length === 0 )
			{
				length = 1
				invalidLength = true
			}
			
			var path = file.Path.replace(WOW_DIR, "").slice(1)
			
			echo("Processing " + file.Name + "...")
			
			if (invalidLength) WScript.Echo("Warning: " + path + " has an invalid or zero length!")
			
			musicLua.WriteLine("\t[[" + path + "]], " + length + "," + (invalidLength ? " -- Warning: This file has an invalid or zero length!" : "") )
			
			count++
		}
	}
	
	echo("\nFinished processing " + count + " files.\n")
	
	return count
}

var addedStr = ""
var addedTotal = 0

for (var i = 0; i <= 5; i++)
{
	var part = fso.OpenTextFile(FULL_SCRIPTPARTS_DIR + "\\music_part" + i + ".lua", ForReading, false, TriStateFalse).ReadAll()
	musicLua.Write(part)
	
	var dir = DIRECTORIES[i]
	echo("\nProcessing " + dir + " Music:\n")
	
	var added = AddFiles(FULL_MUSIC_DIR + "\\" + dir)
	addedTotal += added
	
	var sep = (i != 5) ? ", " : ""
	addedStr += ( added + " " + dir + sep )
}

var MUSIC_FOOTER = fso.OpenTextFile(FULL_SCRIPTPARTS_DIR + "\\music_footer.lua", ForReading, false, TriStateFalse).ReadAll()
musicLua.WriteLine(MUSIC_FOOTER)
musicLua.Close()

WScript.Echo("Added " + addedTotal + " music files to music.lua (" + addedStr + ")")

if (isConsole)
{
	echo("\n\nPress any key to continue . . .")
	WScript.StdIn.ReadLine() // Pause before exiting so the user has time to read the output.
}