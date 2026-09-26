--------------------------------------------------------------------------------
--	Script file guard															
--	Examine its value to see how many times the script was run.	
--------------------------------------------------------------------------------
if (guardTB2Main == undefined) then
 (
 	global guardTB2Main = 0
 )	

 guardTB2Main += 1

--------------------------------------------------------------------------------
--	Make sure TB2 starup was executed first.							
--------------------------------------------------------------------------------
 if (guardTB2Startup == undefined) then
 (
 	global guardTB2Startup = 0
 	FileIn ((getDir #startupScripts) + "\\CPTB2Startup.ms")
 )

-----------------------------------------------------------------------------------------
--	Glogal variables used throughout all scripts						
-----------------------------------------------------------------------------------------

global gCurrentPluginVers 		= 4211
global gErrorNotify				= true
global gAALevel					= 3
global gPreviewAALevel			= 1
global gAADiameter				= 1.5
global gAABlur						= 0.0
global gWindowOpacityRelMin	= 0.3
global gWindowOpacityRelMax	= 0.5
global gThumbnailBgColor		= white
global gCurRendererID
-----------------------------------------------------
--CP  ADDED THE FOLLOWING GLOBAL VARIABLES
global gTempPathCP
global gNightMatPathCP
global gRenderTypeCP = 0
global gAlphaSeedCP
global gGroupIDCP
global gInstanceIDCP
global gDayLibFlagCP = false
global gNightLibFlagCP = false
global gAlphaLibFlagCP = false
global gDayLibNameCP = ""
global gNightLibNameCP = ""
global gAlphaLibNameCP = ""
global gDayLibTempNameCP = (getdir #matlib) + "\\BatforMax_TempD.mat"
global gNightLibTempNameCP = (getdir #matlib) + "\\BatforMax_TempN.mat"
global gAlphaLibTempNameCP = (getdir #matlib) + "\\BatforMax_TempA.mat"
global gNightAlphaLibTempNameCP = (getdir #matlib) + "\\BatforMax_TempB.mat"
global gNightLibTempCP
global gOrigMaterialsCP
global gmaterialname
global gstreamBATCP
global gmatscount
global gLumPixels
-----------------------------------------------------
global gDestPath
global gExportExt
global gCamLightsPath
global gCamLightsFolder
global gSC4PluginPath
global gSC4Modelname
global gAutoexecute

global gTB2SystemInit



-----------------------------------------------------------------------------------------
--	System initialization													
-----------------------------------------------------------------------------------------


---------------------------------------------------
--	Function: 	FnInitErrorNotify							
---------------------------------------------------
fn	FnInitErrorNotify	errorMsg errorCode =	
(
	errorMsg += "\n\n[error # " + (errorCode as string) + "]"
	
	MessageBox errorMsg
	
	return errorCode
)


------------------------
-- fn AutoSet automatically /w Query sets folders and Night Windows
------------------------
fn AutoSet =
(
	
local thisMax = (maxVersion())[1]
	
if gINIfile != undefined do
		(
			if getINIsetting gINIfile "configuration" "UseNightWindows" == "" do
			(
				if thisMax<8000 then
				(
					setINIsetting gINIfile "configuration" "UseNightWindows" "True"
				)
				else
				(
					setINIsetting gINIfile "configuration" "UseNightWindows" "False"
					messageBox "Night Windows are incompatible with your version of 3ds Max and were disabled"
				)
			)
				
			if getINISetting gINIFile "Configuration" "DestPath" == "" do
				setINISetting gINIFile "Configuration" "DestPath" ((getDir #maxroot) + "gamepacks\\BAT\\OutputFiles\\")
			
			if getINISetting gINIFile "Configuration" "TempPath" == "" do
				setINISetting gINIFile "Configuration" "TempPath" ((getDir #maxroot) + "gamepacks\\BAT\\Temp\\")
				
			if gINIFile != undefined do
			(
				if getINISetting gINIFile "Configuration" "SC4PluginPath" == "" do
				(
					messagebox "Please select your Simcity4 Plugins folder\n\nYou only have to do this once"
					local PluginsPath = undefined
					while PluginsPath == undefined do
					(
						PluginsPath = getSavePath caption:"Select Plugins Folder" initialDir:"C:\\"
						if PluginsPath == undefined then
						if querybox "Plugin Folder was NOT selected!\nUntil it's done you woulnd't be able to export\n\n\nclick YES to select it later\n\nclick NO to return to Folder Selection Window" do	
							exit with messagebox "The path can be set here next time you start up 3dsMax, or by manualy editing SC4PluginPath entry in Bat4Max.ini file"
						else
							setINISetting gINIFile "Configuration" "SC4PluginPath" (PluginsPath + "\\")
					)
					
				)
				
			)
			
		)
	)
AutoSet()

---------------------------------------------------
--	Function: 	FnTB2SystemInit							
---------------------------------------------------
fn	FnTB2SystemInit	=	
(
	local errorMsg	
	
	try
	(
		if gTB2SystemInit != undefined then
			(
				return gTB2SystemInit
			)
			
			gTB2SystemInit	= -100 --	Reset for the rmaining initializations
		
		--	Get export directory
		if gINIFile != undefined then
			(
				gDestPath	= (getINISetting gINIFile "Configuration" "DestPath")
			)
			
		if (gDestPath == undefined or gDestPath == "") then
			(
				gDestPath = (getDir #maxroot) + "gamepacks\\bat"+ "\\OutputFiles\\"
			)
			
		if (gDestPath == undefined or gDestPath == "") then
			(
				errorMsg = "Undefined export directory."
				return FnInitErrorNotify errorMsg -5
			)
				
----------------------------------		
--CP ADDED THE FOLLOWING SECTION 		
		
		if gINIFile != undefined then
		(
			gTempPathCP	= (getINISetting gINIFile "Configuration" "TempPath")
		)

		if (gTempPathCP == undefined or gTempPathCP == "") then
			(
				gTempPathCP = (getDir #maxroot) + "gamepacks\\bat" + "\\Temp\\"
				 
			)
			
		if (gTempPathCP == undefined or gTempPathCP == "") then
			(
				errorMsg = "Undefined temporary directory."
				return FnInitErrorNotify errorMsg -7
			)
			
		if gINIFile != undefined then
			(
				gNightMatPathCP	= (getdir #maxroot) + (getINISetting gINIFile "Configuration" "NightMats")
			)
			
		if (gNightMatPathCP == undefined or gNightMatPathCP == "") then
			(
				gNightMatPathCP = (getDir #maxroot) + "gamepacks\\BAT\\Maps\\NightWindows\\"
				 
			)
			
		if (gNightMatPathCP == undefined or gNightMatPathCP == "") then
			(
				errorMsg = "Undefined Night Materials Directory."
				return FnInitErrorNotify errorMsg -9
			)

--RN SC4 Plugin Path

		if gINIFile != undefined then
			(
				gSC4PluginPath	= (getINISetting gINIFile "Configuration" "SC4PluginPath")
			)
		
		if (gSC4PluginPath == undefined or gSC4PluginPath == "") then
			(
				gSC4PluginPath = ""
				 
			)
			
		if gINIFile != undefined then
			(
				gAutoexecute	= ((getINISetting gINIFile "Configuration" "Autoexecute")=="true")
				--	messagebox ("Autoexecute is config as " + gAutoexecute as string)
			)

-------------------------------------
		
		
		--	Get export extension

		if gINIFile != undefined then
		(
			gExportExt	= (getINISetting gINIFile "Configuration" "ExportExt")
		)

		if (gExportExt == undefined or gExportExt == "") then
		(
			gExportExt = ".SC4Model"
		)
		
		--	Find Cam & Lights Rig
		
		if gINIFile != undefined then
		(
			local relRigPath 		= (getINISetting gINIFile "Configuration" "CamerasAndLights")
			local relRigFolder 	= (getINISetting gINIFile "Configuration" "CamerasAndLightsFolder")
			
			if (relRigPath != undefined and relRigPath.count > 0) then
			(
				gCamLightsPath	= (getDir #maxroot) + relRigPath
			)
			
			if (relRigFolder != undefined and relRigFolder.count > 0) then
			(
				gCamLightsFolder	= (getDir #maxroot) + relRigFolder
			)
		)
		
		if (gCamLightsPath == undefined or gCamLightsPath == "") then
		(
			gCamLightsPath	= (getDir #maxroot) + "gamepacks\\BAT\\scenes\\CamLightRigs\\TB2_CameraLightRig.max"
		)
		
		if (gCamLightsFolder == undefined or gCamLightsFolder == "") then
		(
			gCamLightsFolder	= (getDir #maxroot) + "gamepacks\\BAT\\scenes\\CamLightRigs\\"
		)
		
		if (not (doesFileExist gCamLightsPath)) then
		(
			errorMsg 		= "Cameras and Light file \n\"" + gCamLightsPath + "\"\ncould not be found"
			gCamLightsPath = ""
			return FnInitErrorNotify errorMsg -6
		)
		
		--	Find AA level
		
		if gINIFile != undefined then
		(
			local aaLev = (getINISetting gINIFile "Configuration" "AALevel")
			
			if (aaLev == undefined or aaLev == "") then
			(
				gAALevel = aaLev as integer
			)
			
		)
		
		gTB2SystemInit = -1	--	-1 signifies successful initialization	
	)
	catch
	(
		-- messagebox "We are in the catch section in gtb2systeminit. Testing Try-return-catch"
		errorMsg = "Unknown SC4 initialization error!"
		
		return FnInitErrorNotify errorMsg -100
	)
	
	return gTB2SystemInit
)

-----------------------------------------------------------------------------------------
-- Run initialization function											
-----------------------------------------------------------------------------------------
gTB2SystemInit = FnTB2SystemInit()


-----------------------------------------------------------------------------------------
-- Script library includes													
-----------------------------------------------------------------------------------------
FnTB2FileInOnce "CPScriptUtils.ms"		guardScriptUtils
FnTB2FileInOnce "CPBuildingMill.ms"	guardBuildingMill
FnTB2FileInOnce "CPTB2MainUI.ms"		guardTB2MainUI
--ALN temp fix hopefully, need to load it a second time after everything else
-- filein ((getdir #maxroot) + "gamepacks\\BAT\\scripts\\CPBuildingMill.ms")
-- filein ((getdir #maxroot) + "gamepacks\\BAT\\scripts\\CPTB2MainUI.ms")
--FnTB2FileInOnce "RNTB2MainUI.ms"		guardRN2MainUI

---------------------------------------------------
--	Function: 	FnTB2PostloadSystemCheck							
---------------------------------------------------
fn	FnTB2PostloadSystemCheck	=
(
	if (gTB2SystemInit == 0) then
	(
		return 0
	)


	if (gTB2SystemInit != -1) then
	(
		return gTB2SystemInit
	)
	
	
	if guardBuildingMill == undefined then
	(
		errorMsg = "Failed to load \"CPBuildingMill.ms\""

		return FnInitErrorNotify errorMsg -102
	)
	
	if guardCameraRig == undefined then
	(
		errorMsg = "Failed to load \"CPCameraRig.ms\""

		return FnInitErrorNotify errorMsg -103
	)
	
	if guardFileUtils == undefined then
	(
		errorMsg = "Failed to load \"CPFileUtils.ms\""

		return FnInitErrorNotify errorMsg -104
	)
	
	
	if guardModelNames == undefined then
	(
		errorMsg = "Failed to load \"CPModelNames.ms\""

		return FnInitErrorNotify errorMsg -102
	)
	
	if guardScriptUtils == undefined then
	(
		errorMsg = "Failed to load \"CPScriptUtils.ms\""

		return FnInitErrorNotify errorMsg -101
	)
	
	if guardStringUtils == undefined then
	(
		errorMsg = "Failed to load \"CPStringUtils.ms\""

		return FnInitErrorNotify errorMsg -102
	)
	
	if guardTB2MainUI == undefined then
	(
		errorMsg = "Failed to load \"CPTB2MainUI.ms\""

		return FnInitErrorNotify errorMsg -102
	)
	
	return 0
)

-----------------------------------------------------------------------------------------
-- Run initialization function											
-----------------------------------------------------------------------------------------
gTB2SystemInit = FnTB2PostloadSystemCheck()



