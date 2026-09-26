--------------------------------------------------------------------------------
--	Script file guard
--	Examine its value to see how many times the script was run.
--------------------------------------------------------------------------------
 if (guardConverterFunctions == undefined) then
 (
 	global guardConverterFunctions = 0
 )

 guardConverterFunctions += 1

 --------------------------------------------------------------------------------------
 --- Functions Proper
 --------------------------------------------------------------------------------------

Fn Day2Night =
(
	if (getFiles ((getdir #maxroot) + "gamepacks\\BAT\\Outputfiles\\" + (getfilenamefile gSC4ModelName) + "\\*.fsh")).count != 0 then
	(
		local fshpath = (getdir #maxroot) + "gamepacks\\BAT\\Outputfiles\\" + (getfilenamefile gSC4ModelName)
		local oldTGIs = getfiles ((getdir #maxroot) + "gamepacks\\BAT\\Outputfiles\\" + (getfilenamefile gSC4ModelName) + "\\*.TGI")
		for f in oldTGIs do
				(
					deleteFile f
				)

				FSHs = getfiles (fshpath + "\\*.fsh")
				for f in FSHs do
					(
						FSHname = getFilenameFile f
						FSHnameString = FSHname as stringstream
						nachalo = readChars FSHnameString (FSHname.count-4)
						drop = readChar FSHnameString
						konec = readChars FSHnameString 3

						newNite = nachalo as string + "8" + konec as string
						newName = getFilenamePath f as string + newNite as string + getFilenameType f as string
						renameFile f newName


						local TGIname = getFilenameFile newName
						local streamTGI = createfile ( fshpath + "\\" + TGIname + ".fsh.TGI")
						TGInameStream = TGIname as stringstream
						format "%\n" (readdelimitedstring TGInameStream "_") to: streamTGI
						format "%\n" (readdelimitedstring TGInameStream "_") to: streamTGI
						format "%\n" (readdelimitedstring TGInameStream "_") to: streamTGI
						flush streamTGI
						close streamTGI
					)
	messageBox "truNite FSHs were created. \n\nPress OK to insert."
	)

	else
	(
		messagebox "Nothing to convert. \n\nRun export first, or imput Existing SC4Model file name"
	)
)

--------------------------------------------------------------------------------------
-- NOTE: This function is named 'nightInsert' to match the call site in
--       CPTB2MainUI.ms (Night Export button). The previous version was named
--       'niteInsert', which made the Night Export button throw
--       "type error: call needs function or class, got: undefined".
--------------------------------------------------------------------------------------
fn nightInsert =
(

local outputfilepath = (getdir #maxroot) + "gamepacks\\BAT\\Outputfiles\\" + (getfilenamefile gSC4ModelName) + "\\*.fsh"
local srcpluginpath = gSC4PluginPath + gSC4ModelName
local DATCmdpath = (getdir #maxroot) + "gamepacks\\BAT\\datcmd.exe"

insertFSHstream = createFile ((getdir #maxroot) + "gamepacks\\BAT\\Outputfiles\\" + (getfilenamefile gSC4ModelName)+"\\" +(getfilenamefile gSC4ModelName) +"_truNite.bat")
format "%"  ("\"" +DATCmdpath + "\" -src \"" + srcpluginpath + "\" -ins \"" + outputfilepath + "\" -noconfirm") to:insertFSHstream

flush insertFSHstream
close insertFSHstream

local FSH_bat = ((getdir #maxroot) + "gamepacks\\BAT\\Outputfiles\\" + (getfilenamefile gSC4ModelName)+"\\" +(getfilenamefile gSC4ModelName) +"_truNite.bat")
dosCommand ("\"" + FSH_bat  + "\"")
messageBox "truNite FSHs were inserted.\n\n\nCongratulations!\nNight export has successfully completed!"
)
