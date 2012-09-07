// The path to your WoW folder (using double backslashes as directory separators)
var WOW_DIR = "C:\\Users\\Public\\Games\\World of Warcraft";

// The exact text that appears in the Type column of Windows Explorer for MP3 files.
var MP3_TYPE = "MPEG Layer-3 Audio";

// -------------
// END OF CONFIG
// -------------
// Do not change anything below here!

if (typeof WScript == "undefined")
{
	throw new Error("Unsupported environment. Make sure you're running this script with Microsoft(R) Windows Based Script Host.");
}

// Get the OS version
// http://stackoverflow.com/questions/351282/find-os-name-version-using-jscript
var wbemFlagReturnImmediately = 0x10;
var wbemFlagForwardOnly = 0x20;
var objWMIService = GetObject("winmgmts:\\\\.\\root\\CIMV2");
var colItems = objWMIService.ExecQuery("SELECT * FROM Win32_OperatingSystem", "WQL", wbemFlagReturnImmediately | wbemFlagForwardOnly);

var enumItems = new Enumerator(colItems);
var objItem = enumItems.item();

var OSVER = objItem.Version;
// End OS version code

// Get the index of the length property
// http://stackoverflow.com/questions/1674134/detecting-the-version-and-company-name-of-an-exe-using-jscript
// http://www.kixtart.org/forums/ubbthreads.php?ubb=showflat&Number=160880&page=1
var LENGTH_INDEX;

// For some reason string.search returns -1 if the search fails (which means we have to compare the return to -1 to get a boolean)
if (OSVER.search(/^6\.1\./) > -1 || OSVER.search(/^6\.0\./) > -1) // Windows 7 (NT 6.1), Server 2008 R2 (NT 6.1), Vista (NT 6.0) and Server 2008 (NT 6.0)
{
	LENGTH_INDEX = 27; // Length
}
else if (OSVER.search(/^5\.2\./) > -1 || OSVER.search(/^5\.1\./) > -1) // Windows XP (NT 5.2/5.1), Server 2003 R2 (NT 5.2), Server 2003 (NT 5.2)
{
	LENGTH_INDEX = 21; // Duration
}
else if (OSVER.search(/^5\.0\./) > -1) // Windows 2000 (NT 5.0)
{
	LENGTH_INDEX = 33; // Play Length
}
else
{
	throw new Error(
		"Unknown Windows version. This script only supports 7, Vista, Server 2008, XP, Server 2003 and 2000.\n\n\
		If you want support added for your version of Windows, please run the included GetLengthIndex_Windows.js script and click OK until the popup shows something like Length, Duration or Play Length as the Property Name.\n\n\
		Once you get to this popup, leave a comment on Curse or WoW Interface with its contents.\n\n\
		If the script generates an error instead of a series of popups, leave a comment on Curse or WoW Interface with the error and which version of Windows you're using."
	);
}
// End length index code

// Iterate over the files in the music folder

var PBM_DIR = "Interface\\AddOns\\PetBattleMusic"
var MUSIC_DIR = PBM_DIR + "\\Music";

var ForReading = 1;
var ForWriting = 2;
var TriStateFalse = 0;

var fso = new ActiveXObject("Scripting.FileSystemObject");

var musicHeaderFile = fso.OpenTextFile(WOW_DIR + "\\" + PBM_DIR + "\\ScriptParts\\music_header.lua", ForReading, false, TriStateFalse);
var MUSIC_HEADER = musicHeaderFile.ReadAll();
var musicFooterFile = fso.OpenTextFile(WOW_DIR + "\\" + PBM_DIR + "\\ScriptParts\\music_footer.lua", ForReading, false, TriStateFalse);
var MUSIC_FOOTER = musicFooterFile.ReadAll();

var musicLua = fso.OpenTextFile(WOW_DIR + "\\" + PBM_DIR + "\\music.lua", ForWriting, false, TriStateFalse);
musicLua.WriteLine(MUSIC_HEADER);

var shell = new ActiveXObject("Shell.Application");
var musicFolder = shell.Namespace(WOW_DIR + "\\" + MUSIC_DIR);
var musicFiles = musicFolder.Items();

var count = 0;

for (i = 0; i <= musicFiles.Count; i++)
{
	var file = musicFiles.Item(i);
	if (typeof file != "undefined" && file != null && file.Type == MP3_TYPE ){
		var lengthArray = musicFolder.GetDetailsOf(file, LENGTH_INDEX).split(":").reverse() // We reverse the array so the seconds are first, the minutes second, etc.
		var length = 0.0;

		for (ind = 0; ind <= lengthArray.length; ind++)
		{
			if (typeof lengthArray[ind] != "undefined")
			{
				var num = parseInt(lengthArray[ind])
				length += (num * Math.pow(60, ind));
			}
		}

		var path = file.Path.replace(WOW_DIR, "").slice(1);
		musicLua.WriteLine("\t[[" + path + "]], " + length + ",");
		count++
	}
}

musicLua.WriteLine(MUSIC_FOOTER);
musicLua.Close();

WScript.Echo("Added " + count + " music files to music.lua.");
