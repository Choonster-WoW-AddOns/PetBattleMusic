$wowPath = 'C:\Users\Public\Games\World of Warcraft'

# -------------
# END OF CONFIG
# -------------
# Do not change anything below here!

# Get the index of the length property
# http://stackoverflow.com/questions/1674134/detecting-the-version-and-company-name-of-an-exe-using-jscript
# http://www.kixtart.org/forums/ubbthreads.php?ubb=showflat&Number=160880&page=1
$osVersion = (Get-WmiObject Win32_OperatingSystem).Version # Get the OS version (i.e. the version of NT)

Function isVer  # Quick helper function that takes an arbitrary number of version strings and checks if any of them match $osVersion
{
	foreach ($arg in $args)
	{
		if ( $osVersion.StartsWith($arg + ".") ) # Add a dot to the end of the string to make sure "6.1" doesn't match "6.10.XXXX" (just in case MS ever uses a double digit NT subversion)
		{
			return $true
		}
	}
	return $false
}
	

if ( isVer "6.2" "6.1" "6.0" ) # Windows 8/Server 2012 (NT 6.2) [Thanks to user_151079 of Curse for this index], Windows 7/Server 2008 R2 (NT 6.1) and Windows Vista/Server 2008 (NT 6.0)
{
	$lengthIndex = 27 # Length
}
elseif ( isVer "5.2" "5.1" ) # Windows XP (NT 5.2/5.1), Windows Server 2003 R1/R2 (NT 5.2)
{
	$lengthIndex = 21 # Duration
}
elseif ( isVer "5.0" ) # Windows 2000 (NT 5.0)
{
	$lengthIndex = 33 # Play Length
}
else
{
	[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
	[System.Windows.Forms.MessageBox]::Show((
@"
		`n`nUnknown Windows version. This script only supports Windows 8, 7, Vista, XP and 2000 as well as Windows Server 2012, 2008 and 2003.`n
		If you want support added for your version of Windows, please run the included GetlengthIndex_Windows.js script and click OK until the popup shows something like Length, Duration or Play Length (i.e. the length of an audio file) as the Property Name.`n
		Once you get to this popup, leave a comment on Curse or WoW Interface with its contents.`n
		If the script generates an error instead of a series of popups, leave a comment on Curse or WoW Interface with the error and which version of Windows you're using.`n
"@
	).Replace("`t", ""))
	exit
}

$addonPath = 'Interface\AddOns\PetBattleMusic'
$fullAddOnPath = Join-Path $wowPath $addonPath
$luaPath = Join-Path $fullAddOnPath 'music.lua'
$fullMusicPath = Join-Path $fullAddOnPath 'Music'
$fullScriptPartsPath = Join-Path $fullAddOnPath 'ScriptParts'

$directories = ( "General", "Wild", "Trainer", "Player", "Victory", "Defeat" )

# Credit to Tobias Weltner of PowerShell.com for the Shell.Application code that is used here to get the length of each mp3 file:
# http://powershell.com/cs/blogs/tobias/archive/2011/01/07/organizing-videos-and-music.aspx

$shell = New-Object -COMObject Shell.Application

$stream = New-Object System.IO.StreamWriter $luapath, $false, ([System.Text.Encoding]::UTF8)

$include = ( "*.mp3", "*.ogg" )

Function AddFiles ($findpath)
{
	$folder = Split-Path $findpath
	$shellfolder = $shell.Namespace($folder)
	
	$name = $folder.Replace($fullMusicPath + '\', '')
	"`nProcessing $name Music:`n"
	
	$count = 0
	
	foreach ($file in Get-ChildItem -Path $findpath -Include $include)
	{
		$fullname = $file.FullName
		$filename = Split-Path $fullname -Leaf
		$shellfile = $shellfolder.ParseName($filename)
		$lengthStr = $shellfolder.GetDetailsOf($shellfile, $lengthIndex)
		$hours, $mins, $secs = [double[]] ($lengthStr -Split ':')
		
		$invalidLength = $false
		
		$length = ($hours * 60 * 60) + ($mins * 60) + $secs
		
		if ($length -eq 0)
		{
			$length = 1
			$invalidLength = $true
		}
		
		$filepath = $fullname.Replace($wowPath + '\', '')
		$outstring = "`t[[$filepath]], $length,"
		"Processing: $filename..."
		
		if ($invalidLength)
		{
			$stream.WriteLine($outstring + ' -- Warning: This file has an invalid or zero length!')
			"Warning: This file has an invalid or zero length!"
		}
		else
		{
			$stream.WriteLine($outstring)
		}
		
		$count++
	}
	
	"`nFinished processing $count files.`n"
}

for ($i = 0; $i -le 5; $i++)
{
	$part = (New-Object System.IO.StreamReader (Join-Path $fullScriptPartsPath "music_part$i.lua")).ReadToEnd()
	$stream.Write($part)
	
	AddFiles (Join-Path (Join-Path $fullMusicPath $directories[$i]) "*")
}

$music_footer = (New-Object System.IO.StreamReader (Join-Path $fullAddOnPath "ScriptParts\music_footer.lua")).ReadToEnd()
$stream.Write($music_footer)

$stream.Close()

if ($Host.Name -eq "ConsoleHost") # Only pause if we're running in the console, not the ISE. This probably won't recognise alternative implementations of PS, but that's not likely to be an issue.
{
	"Press any key to continue . . ."
	Read-Host
}
