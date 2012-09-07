// Echoes the name of each file property
//
// OS name code from here:
//		http://stackoverflow.com/questions/351282/find-os-name-version-using-jscript
// File properties code from here:
//		http://stackoverflow.com/questions/1674134/detecting-the-version-and-company-name-of-an-exe-using-jscript

var wbemFlagReturnImmediately = 0x10;
var wbemFlagForwardOnly = 0x20;
var objWMIService = GetObject("winmgmts:\\\\.\\root\\CIMV2");
var colItems = objWMIService.ExecQuery("SELECT * FROM Win32_OperatingSystem", "WQL", wbemFlagReturnImmediately | wbemFlagForwardOnly);

var enumItems = new Enumerator(colItems);
var objItem = enumItems.item();

var OSNAME = objItem.Caption;

var oShell = new ActiveXObject("Shell.Application");
var oFolder = oShell.Namespace("C:");

for (var i = 0; i < 300 /* some large number*/; i++)
  WScript.Echo("OS Name: " + OSNAME + "\n\nProperty Name: " + oFolder.GetDetailsOf(null, i) + "\n\nIndex: " + i);