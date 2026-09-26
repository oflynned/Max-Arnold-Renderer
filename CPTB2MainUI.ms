--------------------------------------------------------------------------------
--	Script file guard
--	Examine its value to see how many times the script was run.
--------------------------------------------------------------------------------
if ( guardTB2MainUI == undefined ) then
(
	global guardTB2MainUI = 0
)	

guardTB2MainUI += 1

--------------------------------------------------------------------------------
--	Make sure TB2 starup was executed first.
--------------------------------------------------------------------------------
if ( guardTB2Startup == undefined ) then
(
	global guardTB2Startup = 0
	FileIn ( ( getDir #startupScripts ) + "\\CPTB2Startup.ms" )
)

-----------------------------------------------------------------------------------------
-- Script library includes
-----------------------------------------------------------------------------------------
FnTB2FileInOnce "CPScriptUtils.ms" guardScriptUtils
FnTB2FileInOnce "CPBuildingMill.ms" guardBuildingMill
FnTB2FileInOnce "CPCameraRig.ms" guardCameraRig
FnTB2FileInOnce "arnold_ConverterFunctions.ms" guardConverterFunctions
FnTB2FileInOnce "arnold_Functions.ms" guardLtbL_functions
FnTB2FileInOnce "arnold_BatPreview.ms" guardPreview

global ddlrandomoffSelected = 0

----------------------------------------------------------------------------------------
-- Unitility Functions
----------------------------------------------------------------------------------------

-- Normalize a hex ID token (e.g. "0xcedf3d91" or "cedf3d91" or "30000") to a
-- lowercased 8-hex-digit string with no "0x" prefix.
-- The old SplitModelNameIDs did "00000000" + bit.intAsHex(HexStrToInt ...) then
-- substring-sliced. That overflowed MAXScript's signed 32-bit int for 8-hex-digit
-- group IDs (e.g. 0xcedf3d91 -> negative -> mangled/wrong-length string) and had
-- a fragile substring parse ("Call needs function or class, got: 13"). Working on
-- the hex string directly is exact and avoids both.
fn FnNormalizeHexID id =
(
	local s = id
	if (s.count >= 2) and ((substring s 1 2) == "0x") do s = substring s 3 -1
	s = toLower s
	while s.count < 8 do s = "0" + s
	if s.count > 8 do s = substring s (s.count - 7) -1
	return s
)

fn SplitModelNameIDs ModelName =
(
	local splitid = filterString ModelName "_. -"
	local results = false


	if splitid.count >= 5 then
	(
		local IDinstance = splitid[splitid.count - 1]
		local IDGroup = splitid[splitid.count - 2]

		if ( ( verifyhex IDGroup ) and ( verifyhex IDinstance ) ) then
		(
			gInstanceIDCP = FnNormalizeHexID IDinstance
			gGroupIDCP = FnNormalizeHexID IDGroup
		) else
		results = true
	) else
	results = true

	return results
)

fn checkexistbatchfsh =
(
	local batchcmd = ( getDir #maxroot ) + "gamepacks\\bat\\" + ( getfilenamefile gSC4ModelName ) + ".bat"

	if not ( FnExistFile batchcmd ) then
	(
		messagebox ( "The batch program file is created by the Export command above. Please export your model before clicking on this button." )
		return false
	)

	return true
)

-------------------------------------------------------------------------
-- Function to remove selected output
-------------------------------------------------------------------------
fn removeOutput = 
(
	if gSC4Modelname != undefined then
	(
		local dirClear = ( getdir #maxroot ) + "gamepacks\\BAT\\Outputfiles\\" + ( getfilenamefile gSC4ModelName )
		local dirClearPath = getDirectories dirClear
		local Bat2Remove = ( getdir #maxroot ) + "gamepacks\\BAT\\" + ( getfilenamefile gSC4ModelName ) + ".bat"
		if dirClearPath[1] != undefined do 
		if queryBox "This will delete output files for currently selected model.\n\n\nProcede?" do
		(
			dosCommand ( "rmdir \"" + dirClearPath[1] + "\" /S /Q" )
			deleteFile Bat2Remove
		)
	)
	else
	(
		messagebox ( "No files have been deleted since you haven't specify a model file." )
	)
	
)

------------------------------------------------------------------------
-- Function to remove ALL output
------------------------------------------------------------------------	
fn remove_ALL_Output = 
(
	local allDirClear = ( getdir #maxroot ) + "gamepacks\\BAT\\Outputfiles\\*" 
	local allDirClearPath = getDirectories allDirClear
	local Bats2Remove = getFiles ( ( getdir #maxroot ) + "gamepacks\\BAT\\*.bat" )
	if queryBox "This will delete output files for ALL models found.\n\n\nProcede?" do
	(
		for i = 1 to allDirClearPath.count do 
		(
			dosCommand ( "rmdir \"" + allDirClearPath[i] + "\" /S /Q" )
		)
		for j = 1 to Bats2Remove.count do 
		(
			deleteFile Bats2Remove[j]
		)
	)
	
	
)

------------------------------------------------------------------------
-- Function to check presence of DatCMD.exe
------------------------------------------------------------------------
fn checkexistDatCmd =
(
	local DATCmdpath = ( getdir #maxroot ) + "gamepacks\\BAT\\datcmd.exe"

	if not ( FnExistFile DATCmdpath ) then
	(
		messagebox ( "This function requires the DatCmd program to exist in the " + ( getdir #maxroot ) + "gamepacks\\BAT directory.\nPlease locate and copy DatCmd.exe into this directory." )
		return false
	) 

	return true
)

------------------------------------------------------------------------
-- Function to Check if FSH files had been created
------------------------------------------------------------------------
fn checkexistFshFiles =
(
	if gSC4ModelName != undefined then
	(
		local outputfilepath = ( getdir #maxroot ) + "gamepacks\\BAT\\Outputfiles\\" + ( getfilenamefile gSC4ModelName ) + "\\*.fsh"
		if not ( FnExistFile outputfilepath ) then
		(
			messagebox ( "The fsh files are created by the FSH Batch Build after rendering the model." )
			return false
		)
		
		return true
	)
	
	else
	(
		messageBox "Select SC4Model in Export roll-out first! "
		return false
	)
	
	
)

-----------------------------------------------------------------------
-- Function to create batch file for DayRender FSHs insertion
-----------------------------------------------------------------------
fn injectFshStreamToFile = (
	local outputfilepath = ( getdir #maxroot ) + "gamepacks\\BAT\\Outputfiles\\" + ( getfilenamefile gSC4ModelName ) + "\\*.fsh"
	local srcpluginpath = gSC4PluginPath + gSC4ModelName
	local DATCmdpath = ( getdir #maxroot ) + "gamepacks\\BAT\\datcmd.exe"

	insertFSHstream = createFile ( ( getdir #maxroot ) + "gamepacks\\BAT\\Outputfiles\\" + ( getfilenamefile gSC4ModelName ) + "\\" + ( getfilenamefile gSC4ModelName ) + ".bat" )
	format "%" ( "\"" + DATCmdpath + "\" -src \"" + srcpluginpath + "\" -del fsh -ins \"" + outputfilepath + "\" -noconfirm" ) to:insertFSHstream

	flush insertFSHstream
	close insertFSHstream

	local FSH_bat = ( ( getdir #maxroot ) + "gamepacks\\BAT\\Outputfiles\\" + ( getfilenamefile gSC4ModelName ) + "\\" + ( getfilenamefile gSC4ModelName ) + ".bat" )
	--shellLaunch FSH_bat ""
	doscommand ( "\"" + FSH_bat + "\"" )
	messageBox "FSHs were inserted.\n\n\nCongratulations!\nDayExport has been successfully completed!"
)

-----------------------------------------------------------------------
-- function to create Custom LOD3
-----------------------------------------------------------------------
fn createCustomLOD3 = (
	local LODs_Layer = layerManager.getLayerFromName "LODs 3-5"
	
	if	LODs_Layer != undefined then
	(
		LODs_Layer.current = true
		LODs_Layer.isHidden = false
	)
	else 
	(
		LODs_Layer = LayerManager.newLayerFromName "LODs 3-5"
		LODs_Layer.current = true
		LODs_Layer.isHidden = false
	)
	
	FnCreateSceneBoundingBox name:"LOD3"
	( LayerManager.getLayer 0 ).current = true
	
	select $LOD3
	modPanel.addModToSelection ( UVW_Mapping_Clear()) ui:off
	macros.run "Modifier Stack" "Convert_to_Poly"
	
)

----------------------------------------------------------------------------
-- function to recreate LODs 4 & 5 from Custom created LOD3
----------------------------------------------------------------------------
fn generateLODsFromLOD3 = (
	if ( $LOD5 != undefined ) do delete $LOD5
	if ( $LOD4 != undefined ) do delete $LOD4
	if ( $LOD3 != undefined ) then
	(
		local LODs_Layer = layerManager.getLayerFromName "LODs 3-5"
		LODs_Layer.current = true

		local lod4 = copy $LOD3
		lod4.name = "LOD4"
		lod4.isHidden = true
		
		local lod5 = copy $LOD3
		lod5.name = "LOD5"
		lod5.isHidden = true
		
		local lod3 = $LOD3
		lod3.isHidden = true
		
		( LayerManager.getLayer 0 ).current = true
		
	)
	else messageBox "LOD3 is not found\n\nPress Custom LOD button to create LOD3 first"
)

fn exportLODs = (

	while maxFileName == "" do
	(
		messageBox "Name and Save you scene first"
		max file saveAs
	)

	TestArray = #( )

	Append TestArray $LOD3
	Append TestArray $LOD4
	Append TestArray $LOD5

	If TestArray[1] == undefined then 
	(
		messageBox "LOD3 was not found recreate LODs"
	)
	else
	(
		if TestArray[2] == undefined then 
		(
			messageBox "LOD4 was not found recreate LODs"
		)
		else 
		(
			if TestArray[3] == undefined then
			(
				messageBox "LOD5 was not found recreate LODs"
			)
			else
			(
				
				select $LOD*
				modPanel.addModToSelection ( UVW_Mapping_Clear()) ui:off
				macros.run "Modifier Stack" "Convert_to_Poly"
				exportfile ( "C:\\gmax\\gamepacks\\BAT\\" + getfilenamefile ( maxfilename ) + ".3DS" ) #noPrompt selectedonly:true
				messageBox "Lods were exported"
				
			)
		)
	)
)
-----------------------------------------------------------------------
-- Function to Check if SC4Model File exists in Plugin (specified in BATFORMAX.INI) folder
-----------------------------------------------------------------------
fn checkexistsrcplugin fileModelName =
(
	local srcpluginpath = gSC4PluginPath + fileModelName

	if not ( FnExistFile srcpluginpath ) then
	(
		if ( gSC4PluginPath == "" ) then
		(
			messagebox ( "Model File Not Found!!\n\nThe SC4 Plugin Path (SC4PluginPath=) must be stated in the BATFORMAX.INI file." )
		) else
		(
			messagebox ( fileModelName + " cannot be found in the plugin directory " + gSC4PluginPath + ".\n\n Please check the path SC4PluginPath= in the BATFORMAX.INI and the Model Filename is correct." )
		)
		return false
	)
	
	return true
)

----------------------------------------------------------------------------------------------------
-- checks that the model name is valid and updates the file properties
----------------------------------------------------------------------------------------------------
fn FnChkModelName text = (
	if ( ( text != "" ) and ( checkexistsrcplugin text ) ) then 
	(
		if ( filterstring text " " ).count > 1 then
		(
			messagebox "Model name cannot contain spaces\n\nRename the model before exporting, removing all spaces"
			text = gSC4ModelName
			return false
		)
		if ( SplitModelNameIDs text ) then
		(
			messagebox ( text + " is an invalid SC4Model Name.\n\nPlease use the Model Name created by the BAT during the rendering of the LODS.\n\nValid Names are in the form of ABCDEF-0x00000000_0x00000000_0x00000000.SC4Model\nwhere the three Hex values are type, group and instance respectively\nand the ABCDEF prefix is the name of your gMax model." )
			text = gSC4ModelName
			return false
		)
		else
		(
			gSC4ModelName = text
			fileProperties.deleteProperty #custom "ModelName"
			fileProperties.addProperty #custom "ModelName" gSC4ModelName
			fileProperties.deleteProperty #custom "GroupID"
			fileProperties.addProperty #custom "GroupID" gGroupIDCP
			fileProperties.deleteProperty #custom "InstanceID"
			fileProperties.addProperty #custom "InstanceID" gInstanceIDCP
			fileProperties.deleteProperty #custom "Model ID"
			return true
		)
	)	
	else
	(
		return false
	)
)


--- Roll-Outs definitions	

----------------------------------------------------------------------------------------
-- Let There Be Light roll-out
----------------------------------------------------------------------------------------
rollout letThereBeLight "Bat4Max" (
	label rigSetters "Scene"

	button btn_Setup "Setup"
	-- button btn_setSky "Create sky"	
	----
	-- label lightSetters "Set rig scene"
	button btn_SetDay "Day"
	-- button btn_setNightMaxis "Maxis Night"
	-- button btn_setNightDark "Dark Night"
	----
	-- label nightAdjustment "Set night light"
	-- button btn_darkenNight "Darken"
	-- button btn_brightenNight "Brighten"
	-- button btn_glare "Add glare"
	-----
	-- label troubleshooting "Troubleshooting"
	-- button btn_deleteRigLighting "Delete rig lights"
	-- button btn_resetScene "Reset lights & cameras"

	-- on btn_setSky pressed do heavens()
	
	on btn_Setup pressed do Setup()

	on btn_SetDay pressed do SetDay()
	
	-- on btn_setNightMaxis pressed do SetMaxisNite()
	
	-- on btn_setNightDark pressed do SetDarkNite()
	
	-- on btn_darkenNight pressed do DarkenTheNite()
	
	-- on btn_brightenNight pressed do BrightenTheNite()
	
	-- on btn_glare pressed do Glare()
	
	-- on btn_deleteRigLighting pressed do ClearRig()
	
	-- on btn_resetScene pressed do
	-- (
	-- 	setWaitCursor()
	-- 	local fixResult = gCameraRig.AutoCheckAndFixXRef()
	-- 	setArrowCursor()
	-- 	case fixResult of
	-- 	(
	-- 		0:	messageBox "Camera and lights set successfully."
	-- 		1: messageBox "Camera and lights have been automatically set using the best option availible.\nFor better results it may be necessary to custom create a camera and lighting rig that is unique to this model."
	-- 		( -1 ):	messageBox "Unknown Camera and Lights Rig error!"
	-- 		( -2 ): messageBox "Camera and Lights Rig file not found!"
	-- 	)
	-- )
	
)


-----------------------------------------------------------------------------------------
-- LODs Roll-out
-----------------------------------------------------------------------------------------
rollout rolloutLODs "LODs" width:162 height:380
(
	local inclNtWdws = execute ( getINISetting gINIFile "Configuration" "UseNightWindows" )
	local y = if not inclNtWdws then [0, -248] else [0, 0]
	-- UI elements LODs
	GroupBox grpCustomLod "custom LODs" pos:[6, 6] width:150 height:50 
	button btnCustomLod "LOD3" pos:[12, 24] width:66 height:24 enabled:true toolTip:"Create Simple LOD3 and makes it visible for custom edtitig"
	button btnLOD4_5Recreate "LODs 4&5" pos:[82, 24] width:66 height:24 enabled:true toolTip:"re-creates LODs 4 & 5. Press it once you've finished editing LOD3"
	button btnAutoLODs "Automatic LODs" pos:[12, 60] width:138 height:18 toolTip:"Creates simple scene bounding Box type of LODs and places them on LODS 3-5 Layer"
	
	/*groupBox Heaven_n_Earth "Heavens'n'Earth:" pos:[6,85] width:150 height:38*/
	-- button btn_SetSky "Sky" width:68 height:18 pos:[12,99]
	-- button btn_SetGroundPlane "Ground" width:138 height:18 pos:[12, 85]
	
	GroupBox grpShowHide "show / hide" pos:[6, 105] width:150 height:38
	checkbutton btnLOD3 "LOD3" pos:[12, 118] width:44 height:18 enabled:true toolTip:"LOD3 On/Off"
	checkbutton btnGeom "Hi Res Geo" pos:[59, 118] width:91 height:18 enabled:true toolTip:"Hi-res Geometry On/Off"
	
	--UI NightWindows
	GroupBox grpNightWindows "Night Windows" pos:([6, 143] + y ) width:150 height:215 visible: inclNtWdws 
	spinner spnWindowOpacity "Global Intensity" pos:([24, 163] + y ) width:120 height:16 range:[0, 1, 1] scale:0.1 visible: inclNtWdws 
	dropdownList ddlWindowSets "" pos:([12, 185] + y ) width:138 height:21 items:( filterstring ( GetNightWindowSets()) ";" ) visible: inclNtWdws 
	GroupBox grp3 "Selection" pos:([12, 210] + y ) width:138 height:110 visible: inclNtWdws 
	checkbox chkNightWindow "Enabled" pos:([24, 230] + y ) width:60 height:18 triState:2 visible: inclNtWdws 
	spinner spnSelIntensity "Intensity" pos:([30, 250] + y ) width:84 height:16 range:[0, 1, 1] indeterminate:true visible: inclNtWdws 
	dropdownList ddlRandomOff "Random Lights Off (%)" pos:([18, 270] + y ) width:127 height:40 items:#( "0", "10", "20", "30", "40", "50", "60", "70", "80", "90", "100" ) visible: inclNtWdws 
	
	local kUPKeyNightWindow =	"NightWindow"
	local kUPKeyNightWindowIntensity	=	"NightWindowBrightness"	

	----------------------------------------------------------------------------------------------------
	-- Function:	UpdateGlobalWindowParams 
	----------------------------------------------------------------------------------------------------

	fn UpdateGlobalWindowParams = 
	(
		local globalIntensity	= GetWindowOpacity true
		
		spnWindowOpacity.value = globalIntensity
		
		local windowSet = GetWindowSet()
		
		if ( windowSet != undefined ) then
		(
			local idx = findItem ddlWindowSets.items windowSet
			
			if ( idx > 0 ) then
			(
				ddlWindowSets.selection = idx
			)
		)

		ddlrandomoffSelected = 0
		rolloutLODs.ddlrandomoff.Selected = ddlrandomoffSelected as string
	)
	
	----------------------------------------------------------------------------------------------------
	-- Function:	UpdateWindowParams 
	----------------------------------------------------------------------------------------------------
	fn UpdateWindowParams = 
	(
		if selection.count == 0 then
		(
			chkNightWindow.enabled = false
			spnSelIntensity.enabled = false
			return ok
		)
		
		local globalIntensity	= GetWindowOpacity true	
		local enabledCount = 0
		local disabledCount = 0
		local bCommonIntensity	= true
		local fCommonIntensity
		local node
		
		for node in selection do
		(
			if ( superClassOf node ) != GeometryClass then
			(
				continue
			)
			
			local nightWindowEnabled = getUserProp node kUPKeyNightWindow
			
			if nightWindowEnabled == undefined then
			(
				disabledCount += 1
			)
			else if nightWindowEnabled then
			(
				enabledCount += 1
				
				if fCommonIntensity == undefined then
				(
					local intensity = getUserProp node kUPKeyNightWindowIntensity
					if intensity == undefined then
					(
						fCommonIntensity = globalIntensity
					)
					else
					(
						fCommonIntensity = ( intensity as float )
					)
				)
				
				if bCommonIntensity then
				(
					local intensity = getUserProp node kUPKeyNightWindowIntensity
					
					if intensity == undefined then
					(
						if fCommonIntensity != globalIntensity then
						(
							bCommonIntensity = false
						)
					)
					else if fCommonIntensity != ( intensity as float ) then
					(
						bCommonIntensity = false
					)
				)
			)
			else
			(
				disabledCount += 1
			)
		)
		
		if disabledCount == 0 and enabledCount == 0 then
		(
			chkNightWindow.enabled = false
			spnSelIntensity.enabled = false
			return ok
		)
		
		chkNightWindow.enabled = true

		--	Prior to max 5 spinner and checkbox controls did not have indetermined state.
		--	Therefore, we show indetermined checkbox as disabled, and indtermined
		--	intensity is set to gloabal intensity.

		
		if disabledCount == 0 then
		(
			chkNightWindow.checked = ( enabledCount > 0 )
		)
		else
		(
			chkNightWindow.checked = false
		)	
		
		spnSelIntensity.enabled = chkNightWindow.checked
		
		--	Set common intensity value
		
		if bCommonIntensity then
		(
			if fCommonIntensity == undefined then
			(
				fCommonIntensity = globalIntensity
			)
		)
		else
		(
			fCommonIntensity = globalIntensity
		)
		
		spnSelIntensity.value = fCommonIntensity 

		
		return ok
	)
	----------------------------------------------------------------------------------------------------
	-- Function:	UpdateLodButtons 
	----------------------------------------------------------------------------------------------------
	
	fn UpdateLodButtons = 
	(
		local vis3 = false
		local curNode
		
		curNode = $LOD3
		if ( curNode != undefined ) do 
		(
			vis3 = ( curNode.isHidden != true )
		)
		btnLOD3.checked = vis3
	)
	
	----------------------------------------------------------------------------------------------------
	-- Function:	UpdateLodButtons 
	----------------------------------------------------------------------------------------------------
	
	fn ShowLOD level show = 
	(
		local lod = FnFindLOD level 
		if lod != undefined then
		(
			if show then
			unhide lod 
			else
			hide lod 
		)
	)


	----------------------------------------------------------------------------------------------------------
	--- Actions
	----------------------------------------------------------------------------------------------------------
	on rolloutLODs open do
	(
		UpdateLodButtons()
		
		callbacks.addscript #selectionSetChanged	"rolloutLODs.UpdateWindowParams()" id:#rolloutLODs
	)
	on rolloutLODs close do
	(
		callbacks.removescripts id:#rolloutLODs
	)
	
	on btnGeom changed state do
	(
		-- apply new state to everything
		if ( state ) then 
		(
			unhide $geometry
			unhide $shapes
			hide $LOD3
			hide $LOD4
			hide $LOD5
		)
		else 
		(
			hide $geometry
			hide $shapes
			hide $LOD3
			hide $LOD4
			hide $LOD5
		)
	)
	
	on btnLOD3 changed state do
	(
		if ( state ) then
		(
			unhide $LOD3
		)
		else
		(
			hide $LOD3
		)
	)
	
	on btnAutoLODs pressed do
	(
		local doRefit = true
		if geometry.count == 0 then
		(
			messageBox "The scene is empty. No LOD will be created."
			doRefit = false
		)
		else if $LOD*.count > 0 then
		(
			doRefit = queryBox "The scene already conatins LODs. They will be destroyed in the process.\nAre you sure you want to continue?"
		)
		if doRefit then 
		(
			delete $LOD*
			FnCreateLOD_3_4_5()
		)
	)
	
	on btnCustomLod pressed do
	(
		local goCustom = true
		if geometry.count == 0 then
		(
			messageBox "The scene is empty. No LOD will be created."
			goCustom = false
		)
		else if $LOD*.count > 0 then
		(
			goCustom = queryBox "The scene already conatins LODs. They will be destroyed in the process.\nAre you sure you want to continue?"
		)
		if goCustom then
		(
			delete $LOD*
			createCustomLOD3()
		)
		
	)
	
	on btnLOD4_5Recreate pressed do 
	(
		generateLODsFromLOD3()
	)
	
	
	on btn_SetGroundPlane pressed do earth()
	
	
	on spnWindowOpacity changed val do
	(
		SetWindowOpacity spnWindowOpacity.value
	)
	on ddlWindowSets selected sel do
	(
		SetWindowSet ddlWindowSets.selected
	)
	on ddlrandomoff selected sel do
	(
		ddlrandomoffSelected = ddlrandomoff.selected
		--		messagebox ddlrandomoffselected as string
	)
	
	on chkNightWindow changed state do
	(
		local node
		
		for node in selection do
		(
			if ( superClassOf node ) == GeometryClass then
			(
				setUserProp node kUPKeyNightWindow state
			)
		)
		
		spnSelIntensity.enabled = state
	)
	on spnSelIntensity changed val do
	(
		local node
		
		for node in selection do
		(
			if ( superClassOf node ) == GeometryClass then
			(
				setUserProp node kUPKeyNightWindowIntensity val
			)
		)
	)
)


-----------------------------------------------------------------------------------------
-- Preview rollout
-----------------------------------------------------------------------------------------
rollout tb2RolloutPreview "Preview" width:162 height:300
(
	-- local vairables
	local radioXLate = #( 1, 2, 3, 4 ) -- maps radio button indicies to rotation #s
	local DefState = #( 146, 292 ) -- sets the zoom of the Z5camera
	
	-- UI elements
	GroupBox grpNavigation "Navigation" pos:[6, 6] width:150 height:132
	radiobuttons rdoRotation "Rotation" pos:[25, 24] width:68 height:46 labels:#( "S", "E", "N", "W" ) default:1 --columns:4
	slider sldZoom "Zoom" pos:[25, 70] width:125 height:25 enabled:true range:[0, 4, 4] type:#integer /*orient:#vertical*/ ticks:5
	label lblZ1 "1" pos:[30, 118] width:11 height:13
	label lblZ2 "2" pos:[55, 118] width:11 height:13
	label lblZ3 "3" pos:[80, 118] width:11 height:13
	label lblZ4 "4" pos:[104, 118] width:11 height:13
	label lblZ5 "5" pos:[128, 118] width:11 height:13
	GroupBox grpDefSelection "Zoom 5 quality:" pos:[6, 140] width:150 height:40
	radiobuttons SdHd pos:[15, 157] labels:#( "SD", "HD" ) default:1 columns:2
	button btnPreview "Preview" pos:[6, 187] width:150 height:24 enabled:true toolTip:"Preview"
	
	on rdoRotation changed stat do
	(
		gCameraRig.SetCam ( sldZoom.value + 1 ) radioXLate[stat] updateViewport:true 
	)
	
	on sldZoom changed val do
	(
		gCameraRig.SetCam ( val + 1 ) radioXLate[rdoRotation.state] updateViewport:true
	)
	
	on SdHd changed stat do
	(
		sfhd = DefState[stat]
		if sfhd == 146 then
		fileIn "CPCameraRig.ms"
		else
		fileIn "arnold_CameraRig_HD.ms"
	)
	
	on btnPreview pressed do
	(
		Bat_Preview()
	)

)


----------------------------------------------------------------------------------------
-- Clear Output rollout
----------------------------------------------------------------------------------------
rollout clearOutputFiles "Clear Output Files" width:188 
(
	button btnDeleteCurrent "Clear Current" width:138 height:24 toolTip:"Delete current model output files and directories"
	button btnDeleteAll "Clear All" width:138 height:24 toolTip:"Delete all output files and directories"
	
	on btnDeleteCurrent pressed do removeOutput()
	on btnDeleteAll pressed do remove_ALL_output()
)


-----------------------------------------------------------------------------------------
-- Export Sequence Roll-out
-----------------------------------------------------------------------------------------
rollout tb2RolloutExport "Export Sequence" --width:188 height:278
(
	button btnLodExport "Export LODs" width:138 height:24 tooltip:"exports LODs to your GMAX\\BAT folder in order to generate SC4File. Once File is created you can proceed with Export Sequence."
	button btnGetModel "(1) Select target model" width:138 height:24 toolTip:"selects Model from Plugin Folder into which you'll render"
	label lbl1 "SC4Model Name:" pos:[7, 65] width:162 height:20
	edittext txtModelName pos:[2, 82] width:155 height:17
	button btnExport "(2) Export day" width:138 height:24 toolTip:"Export Renderings and alpha - night also if night materials or night lights exist"
	button btnNightExport "(3) Export night" width:138 height:24 --pos:[12,243]

	----------------------------------------------------------------------------------------------------
	-- Event:	Export button pressed 
	----------------------------------------------------------------------------------------------------

	label lbl3 "Current Material Libraries:" width:168 height:18 pos:[5, 161]
	label lblLibDay "None" width:172 height:19 pos:[5, 174]
	label lblLibNight "No Night Library Available" width:172 height:19 pos:[5, 189]

	--------------------------------------------------------------------------------------------------------
	--- Function to select Model name from Plugin folder
	--------------------------------------------------------------------------------------------------------

	on btnLodExport pressed do
	(
		exportLODs()
	)
	
	on btnGetModel pressed do
	(
		local bTest = true
		local C4ModelName = GetOpenFilename caption:"Select Model File" Filename: gSC4PluginPath Types: "SC4Model(*.SC4Model)|*.SC4Model"
		if C4ModelName == undefined then 
		bTest = false
		else
		(
			if FnChkModelName ( FileNameFromPath C4ModelName ) then
			txtmodelname.text = FileNameFromPath C4ModelName
		)
		if not bTest do MessageBox "No Model File Selected"
	)
	
	on txtModelName entered text do
	(
		if not FnChkModelName txtmodelname.text then 
		(
			gSC4ModelName = ""
			txtmodelname.text = ""
		)
	)
	
	
	----------------------------------------------------------------------------------------------------
	-- CP ADDED Function:	UpdateLibLabels 
	----------------------------------------------------------------------------------------------------

	fn UpdateLibLabels = 
	(
		local nocharsCP = 4
		local CurMatLibNameCP = ( fileNameFromPath ( GetMatLibFileName()) )
		local LibPathCP = ( getFileNamePath ( GetMatLibFileName()) )
		suffidxCP = ( findstring CurMatLibNameCP "-day" )

		if suffidxCP == undefined do
		(
			suffidxCP = ( findstring CurMatLibNameCP "_day" )
		)
		if suffidxCP == undefined do
		(
			suffidxCP = ( findstring CurMatLibNameCP "-night" )
			nocharsCP = 6
		)
		if suffidxCP == undefined do
		(
			suffidxCP = ( findstring CurMatLibNameCP "_night" )
		)
		if suffidxCP != undefined then
		(
			searchNiNameCP = ( LibPathCP + ( replace CurMatLibNameCP suffidxCP nocharsCP "-night" ) )
			searchNi2NameCP = ( LibPathCP + ( replace CurMatLibNameCP suffidxCP nocharsCP "_night" ) )
			if ( getfiles searchNiNameCP ).count != 0 then
			(
				gNightLibFlagCP = true
				lblLibDay.caption = ( fileNameFromPath searchNiNameCP )
				lblLibNight.caption = ( "Night library will be used" )
				gNightLibNameCP = searchNiNameCP
			)
			else
			(
				if ( getfiles searchNi2NameCP ).count != 0 then
				(
					gNightLibFlagCP = true
					lblLibDay.caption = ( fileNameFromPath searchNi2NameCP )
					lblLibNight.caption = ( "Night library will be used" )
					gNightLibNameCP = searchNi2NameCP
				)
				else
				(
					gNightLibFlagCP = false
					lblLibDay.caption = "No Library Found"
				)
			)

		)
		else
		(
			gDayLibFlag = false
			lblLibDay.caption = "Library not loaded."
			gNightLibFlagCP = false
			lblLibNight.caption = "Night library will not be used"
		)
	)
	
	on tb2RolloutExport open do
	(
		callbacks.addscript #MatLibPostOpen "tb2RolloutExport.UpdateLibLabels()" id:#tb2RolloutExport
		callbacks.addscript #MatLibPostSave "tb2RolloutExport.UpdateLibLabels()" id:#tb2RolloutExport
		tb2RolloutExport.updateLibLabels()
	)

	on btnExport pressed do
	(
		local bExport = checkForSave()
		local kUPKeyNightWindow =	"NightWindow"
		local kUPKeyNightWindowIntensity	=	"NightWindowBrightness"
		local olddestpath = gDestPath
		
		if bExport then 
		(
			bExport = queryBox ( "Are you sure you want to render the 20 views of the model?" )
		)
		
		if bExport then
		(
			gRenderTypeCP = 0 -- CP Render Daytime - and nighttime if "night_" materials or "nitelite" lights exist
			local node

			--CP added the following section
			--------------------------------------
			seed ( timestamp())
			for node in geometry do
			(
				if ( ( superClassOf node ) == GeometryClass ) do
				(
					local randDigitCP = random 0 9
					--CP MAY WANT TO EXPAND THIS TO TEST FOR OBJECT AND GLOBAL INTENSITIES OF 0					
					if ( getUserProp node kUPKeyNightWindow != undefined ) then
					(
						if ( getUserProp node kUPKeyNightWindow ) then
						(
							node.gbufferchannel = 8
							gRenderTypeCP = 1
						)
						else
						(
							node.gbufferchannel = 0
						)
					)
					else
					(
						node.gbufferchannel = 0
					)
					if ( node.material != undefined ) do
					(
						if ( ( ( matchpattern node.material.name pattern:"win*" ) or ( matchpattern node.material.name pattern:"doo*" ) or ( matchpattern node.material.name pattern:"gar*" ) ) and gNightLibFlagCP ) do
						(
							node.gbufferchannel = 4
						)
					)
					--					if (rolloutLODs.ddlRandomOff.selected == undefined) then
					--					(
					--						rolloutLODs.ddlRandomOff.selected = "0"
					--					)
					if randDigitCP < ( ( ( ddlRandomOffselected as float ) / 10 ) as integer ) do
					(
						node.gbufferchannel += 1
					)
					if ( node.gbufferchannel == 1 ) do
					(
						node.gbufferchannel = 0
					)
					--objects prefixed with "exclude" will be forcibly removed from the night alpha
					if ( ( substring node.name 1 7 ) == "exclude" ) do 
					(
						node.gbufferchannel = 1
					)
					local globalintensity = GetWindowOpacity true
					local fCommonIntensity
					if ( ( node.gbufferchannel == 8 ) or ( node.gbufferchannel == 9 ) ) do
					(
						local randIAdj = random -2 0
						if ( getUserProp node kUPKeyNightWindowIntensity == undefined ) then
						(
							fCommonIntensity = globalIntensity
						)
						else
						(
							fCommonIntensity = ( ( getUserProp node kUPKeyNightWindowIntensity ) as float )
						)
						if ( fCommonIntensity != 0.0 ) do
						(
							local gbuffint = ( ( fCommonIntensity * 10 ) + randIAdj )
							if gbuffint > 9 do
							(
								gbuffint = 9
							)
							if gbuffint > 0 do
							(
								node.gbufferchannel = ( node.gbufferchannel + ( ( gbuffint * 10 ) as integer ) )
							)
						)
					)
				)
			)

			if gNightLibFlagCP do (
				gRenderTypeCP += 4
			)
			---------------------------------------

			gDestPath = ( gDestPath + ( getfilenamefile gSC4ModelName ) + "\\" )

			-- create a working directory and ignore the error if any
			makedir gDestPath
			FnExportAllZoomsAndRotations gDestPath
			gDestPath = olddestpath
			
			------------- Test
			executebatchfsh()
			messageBox "Daytime FSH were created.\n\nPress OK to insert."
			injectFshStreamToFile()
		)
	)
	
	------NightRender-------
	on btnNightExport pressed do
	(
		local MaxisNighteSky = getNodeByName "IES Sky | Maxis night"
		local DarkNightSky = getNodeByName "IES Sky | Dark night"
		local olddestpath = gDestPath
		local bExport = checkForSave()
		if MaxisNightSky == undefined and DarkNightSky == undefined then
		(
			bExport = queryBox ( "This isn't a night Scene.\n\nDo you still want to proceed?" )
		)
		
		if bExport then 
		(
			bExport = queryBox ( "Are you sure you want to render the 20 views of the model?" )
		)
		seed ( timestamp())
		if bExport then
		(
			gDestPath = ( gDestPath + ( getfilenamefile gSC4ModelName ) + "\\" )
			-- create a working directory and ignore the error if any
			makedir gDestPath
			FnExportAllZoomsAndRotations gDestPath
			gDestPath = olddestpath
			executebatchfsh()
			Day2Night()
			nightInsert()
		)
	)
)

---------------------------------------------------------------------------------------
--	Create Main UI Roll-outs																				
---------------------------------------------------------------------------------------
addrollout letThereBeLight rolledUp:true	
addRollout rolloutLODs rolledUp:true
addRollout tb2RolloutPreview rolledUp:true
addRollout clearOutputFiles rolledUp:true
addRollout tb2RolloutExport rolledUp:true


---------------------------------------------------------------------------------------
--	Function:	CloseTB2MainUI																				
---------------------------------------------------------------------------------------
fn CloseTB2MainUI =
(
	removeRollout letThereBeLight
	removeRollout rolloutLODs
	removeRollout tb2RolloutPreview
	removeRollout clearOutputFiles
	removeRollout tb2RolloutExport 
)