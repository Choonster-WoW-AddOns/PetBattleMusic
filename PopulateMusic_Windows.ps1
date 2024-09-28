using namespace System
using namespace System.IO
using namespace System.Text

# -------------
# START OF CONFIG
# -------------

[string] $wowPath = 'C:\Program Files (x86)\World of Warcraft\_retail_'

# -------------
# END OF CONFIG
# -------------
# Do not change anything below here!

$ErrorActionPreference = 'Stop'

# Get the index of the length property
# http://stackoverflow.com/questions/1674134/detecting-the-version-and-company-name-of-an-exe-using-jscript
# http://www.kixtart.org/forums/ubbthreads.php?ubb=showflat&Number=160880&page=1
[string] $osVersion = (Get-WmiObject Win32_OperatingSystem).Version # Get the OS version (i.e. the version of NT)

# Quick helper function that takes an arbitrary number of version strings and checks if any of them match $osVersion
function Test-OsVersion {
	foreach ($arg in $args) {
		# Add a dot to the end of the string to make sure "6.1" doesn't match "6.10.XXXX" (just in case MS ever uses a double digit NT subversion)
		if ($osVersion.StartsWith($arg + ".")) {
			return $true
		}
	}

	return $false
}

if (Test-OsVersion "10.0" "6.3" "6.2" "6.1" "6.0") {
	# Windows 10 (NT 10.0) [Thanks to badjujumojo of Curse for this index]
	# Windows 8.1/Server 2012 R2 (NT 6.3),
	# Windows 8/Server 2012 (NT 6.2) [Thanks to user_151079 of Curse for this index]
	# Windows 7/Server 2008 R2 (NT 6.1)
	# Windows Vista/Server 2008 (NT 6.0)

	[int] $lengthIndex = 27 # Length
}
elseif (Test-OsVersion "5.2" "5.1") {
	# Windows XP (NT 5.2/5.1)
	# Windows Server 2003 R1/R2 (NT 5.2)

	[int] $lengthIndex = 21 # Duration
}
elseif (Test-OsVersion "5.0") {
	# Windows 2000 (NT 5.0)

	[int] $lengthIndex = 33 # Play Length
}
else {
	[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
	[System.Windows.Forms.MessageBox]::Show(@"
		`n`nUnknown Windows version. This script only supports Windows 10, 8/8.1, 7, Vista, XP and 2000 as well as Windows Server 2012, 2008 and 2003.`n
		If you want support added for your version of Windows, please run the included GetlengthIndex_Windows.js script and click OK until the popup shows something like Length, Duration or Play Length (i.e. the length of an audio file) as the Property Name.`n
		Once you get to this popup, leave a comment on Curse or WoW Interface with its contents.`n
		If the script generates an error instead of a series of popups, leave a comment on Curse or WoW Interface with the error and which version of Windows you're using.`n
"@.Replace("`t", ""))
	exit
}

[string] $addonPath = 'Interface\AddOns\PetBattleMusic'
[string] $fullAddOnPath = Join-Path $wowPath $addonPath
[string] $luaPath = Join-Path $fullAddOnPath 'music.lua'
[string] $fullMusicPath = Join-Path $fullAddOnPath 'Music'
[string] $fullScriptPartsPath = Join-Path $fullAddOnPath 'ScriptParts'

[string[]] $directories = ( "General", "Wild", "Trainer", "Player", "Victory", "Defeat" )

# Credit to Tobias Weltner of PowerShell.com for the Shell.Application code that is used here to get the length of each mp3 file:
# http://powershell.com/cs/blogs/tobias/archive/2011/01/07/organizing-videos-and-music.aspx

[__ComObject] $shell = New-Object -COMObject Shell.Application

[StreamWriter] $stream = [StreamWriter]::new($luapath, $false, [Encoding]::UTF8)

function Get-MP3Length {
	param (
		[Parameter(Mandatory)]
		[__ComObject]
		$shellFolder,
		[Parameter(Mandatory)]
		[string]
		$fileName
	)

	$shellFile = $shellFolder.ParseName($fileName)
	$lengthStr = $shellfolder.GetDetailsOf($shellFile, $lengthIndex)
	$hours, $mins, $secs = [double[]] ($lengthStr -Split ':')
	$length = ($hours * 60 * 60) + ($mins * 60) + $secs

	return $length
}

[string] $oggInfoPath = Join-Path $fullAddOnPath 'ogginfo\ogginfo.exe'
[regex] $lengthRegex = 'Playback length: (?<minutes>\d+)m:(?<seconds>\d+)\.?\d*'

function Get-OggLength {
	param(
		[Parameter(Mandatory)]
		[string]
		$fullName
	)

	$output = & "$oggInfoPath" "$fullName" 2>&1
	$match = $output -match $lengthRegex # Find the matching line in the output

	$length = 0

	if ($match) {
		# Extract the timestamp from the matching line into the $Matches variable
		$match[0] -match $lengthRegex

		$length = [int] $Matches['minutes'] * 60 + [int] $Matches['seconds']
	}

	if ($length -eq 0) {
		Write-Host "`n`n" $output "`n`n"
	}

	return $length
}

function Add-Files {
	param(
		[Parameter(Mandatory)]
		[string]
		$findPath
	)

	$folder = Split-Path $findPath
	$shellFolder = $shell.Namespace($folder)

	$name = $folder.Replace($fullMusicPath + '\', '')
	Write-Host "`nProcessing $name Music:`n"

	$count = 0

	foreach ($file in Get-ChildItem -Path $findPath -Include ("*.mp3", "*.ogg")) {
		$fullName = $file.FullName
		$fileName = Split-Path $fullName -Leaf

		Write-Host "Processing: $fileName..."

		$length = 0

		if ($fileName.EndsWith(".mp3")) {
			$length = Get-MP3Length $shellFolder $fileName
		}
		else {
			$length = Get-OggLength $fullName
		}

		$invalidLength = $false

		if ($length -eq 0) {
			$length = 1
			$invalidLength = $true
		}

		$filePath = $fullName.Replace($wowPath + '\', '')
		$outString = "`t[[$filePath]], $length,"

		if ($invalidLength) {
			$stream.WriteLine($outString + ' -- Warning: This file has an invalid or zero length!')
			Write-Host 'Warning: This file has an invalid or zero length!'
		}
		else {
			$stream.WriteLine($outstring)
		}

		$count++
	}

	Write-Host "`nFinished processing $count files.`n"
}

for ($i = 0; $i -le 5; $i++) {
	[string] $part = Get-Content -LiteralPath (Join-Path $fullScriptPartsPath "music_part$i.lua") -Raw
	$stream.Write($part)

	Add-Files (Join-Path (Join-Path $fullMusicPath $directories[$i]) "*")
}

[string] $music_footer = Get-Content -LiteralPath (Join-Path $fullScriptPartsPath "music_footer.lua") -Raw
$stream.Write($music_footer)

$stream.Close()

Write-Host	'Press any key to continue ...'
Read-Host
