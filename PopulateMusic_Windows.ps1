$wowpath = 'C:\Users\Public\Games\World of Warcraft'

# -------------
# END OF CONFIG
# -------------
# Do not change anything below here!

# Get the index of the length property
# http://stackoverflow.com/questions/1674134/detecting-the-version-and-company-name-of-an-exe-using-jscript
# http://www.kixtart.org/forums/ubbthreads.php?ubb=showflat&Number=160880&page=1
$osversion = (Get-WmiObject Win32_OperatingSystem).Version # Get the OS version (i.e. the version of NT)

if ($osversion.StartsWith("6.1") -or $osversion.StartsWith("6.0")) # Windows 7 (NT 6.1), Server 2008 R2 (NT 6.1), Vista (NT 6.0) and Server 2008 (NT 6.0)
{
	$lengthindex = 27 # Length
}
elseif ($osversion.StartsWith("5.2.") -or $osversion.StartsWith("5.1.")) # Windows XP (NT 5.2/5.1), Server 2003 R2 (NT 5.2), Server 2003 (NT 5.2)
{
	$lengthindex = 21 # Duration
}
elseif ($osversion.StartsWith("5.0.")) # Windows 2000 (NT 5.0)
{
	$lengthindex = 33 # Play Length
}
else
{
	[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
	[System.Windows.Forms.MessageBox]::Show((
@"
		Unknown Windows version. This script only supports 7, Vista, Server 2008, XP, Server 2003 and 2000.`n
		If you want support added for your version of Windows, please run the included GetLengthIndex_Windows.js script and click OK until the popup shows something like Length, Duration or Play Length (i.e. the length of an audio file) as the Property Name.`n
		Once you get to this popup, leave a comment on Curse or WoW Interface with its contents.`n
		If the script generates an error instead of a series of popups, leave a comment on Curse or WoW Interface with the error and which version of Windows you're using.
"@
	).Replace("`t", ""))
	exit
}

$addonpath = 'Interface\AddOns\PetBattleMusic'
$fulladdonpath = Join-Path $wowpath $addonpath
$luapath = Join-Path $fulladdonpath 'music.lua'
$musicpath = Join-Path $addonpath 'Music'
$fullmusicpath = Join-Path $fulladdonpath 'Music'

$fullpath = Join-Path $fullmusicpath 'somefile.txt'
$findpath = Join-Path $fullmusicpath '*'

# Credit to Tobias Weltner of PowerShell.com for the Shell.Application code that is used here to get the length of each mp3 file:
# http://powershell.com/cs/blogs/tobias/archive/2011/01/07/organizing-videos-and-music.aspx

$shell = New-Object -COMObject Shell.Application
$folder = Split-Path $fullpath
$shellfolder = $shell.Namespace($folder)

$stream = New-Object System.IO.StreamWriter $luapath, $false, ([System.Text.Encoding]::UTF8)

$music_header = (New-Object System.IO.StreamReader (Join-Path $fulladdonpath "ScriptParts\music_header.lua")).ReadToEnd()
$music_footer = (New-Object System.IO.StreamReader (Join-Path $fulladdonpath "ScriptParts\music_footer.lua")).ReadToEnd()

$stream.Write($music_header)

foreach ($file in Get-ChildItem -Path $findpath -Include '*.mp3'){
    $filename = Split-Path $file.fullname -Leaf
    $shellfile = $shellfolder.ParseName($filename)
    $lengthStr = $shellfolder.GetDetailsOf($shellfile, $lengthindex)
    $hours, $mins, $secs = [double[]] ($lengthStr -Split ':')
    
    $length = ($hours * 60 * 60) + ($mins * 60) + $secs
    
    $filepath = Join-Path $musicpath $filename
    $outstring = "`t[[{0}]], {1}," -f $filepath, $length
    'Processing: [[{0}]] (length {1}s)' -f $filepath, $length
    $stream.WriteLine($outstring)
}

$stream.Write($music_footer)

$stream.Close()