--------------------------------------------------------------------------------
--	Script file guard
--	Examine its value to see how many times the script was run.
--------------------------------------------------------------------------------
 if (guardScriptUtils == undefined) then
 (
 	global guardScriptUtils = 0
 )	

 guardScriptUtils += 1

--------------------------------------------------------------------------------
--	Make sure TB2 starup was executed first.
--------------------------------------------------------------------------------
 if (guardTB2Startup == undefined) then
 (
	global guardTB2Startup = 0
	FileIn ((getDir #startupScripts) + "\\CPTB2Startup.ms")
 )

----------------------------------------------------------------------------------------------------
--	Includes
----------------------------------------------------------------------------------------------------
FnTB2FileInOnce "CPTextureUtils.ms"	guardTextureUtils
FnTB2FileInOnce "CPStringUtils.ms"		guardStringUtils
FnTB2FileInOnce "CPFileUtils.ms"		guardFileUtils
	
----------------------------------------------------------------------------------------------------
-- global variables that are used across multiple TB2 rollouts
----------------------------------------------------------------------------------------------------


kMaxRendererID			= 0
kPhonyRendererID		= 204778501
kRTRendererID			= 0   --CP 741650287
kGRendererID			= 0   --CP 205229401


----------------------------------------------------------------------------------------------------
-- Function:	FnErrorMessage
-- Desc:			Diagnostic message display function that can put up a dialog or be quiet depending 
--					on the setting of gShowDialogs 
----------------------------------------------------------------------------------------------------
fn FnErrorMessage msgText = 
(
	if gErrorNotify do 
	(
		messageBox msgText
	)
	
	ok
)


----------------------------------------------------------------------------------------------------
--	Function: 	FnPluginIsRightVersion 	
--	Param:		destpath 					
--	Desc:			Make sure we've got the right version of the plugin
----------------------------------------------------------------------------------------------------
fn FnPluginIsRightVersion = 
(
	if (TB2PluginVers == undefined) then
	(
		FnErrorMessage "The SimCity plugin 'Rendlx.dlx' could not be found or it failed to load.\n"
		
		return false
	)
	
	if (TB2PluginVers() != gCurrentPluginVers) then 
	(
		longMessage  = "The SimCity plugin 'Rendlx.dlx' version doesn't match what this script is looking for."
		longMessage += "\n'Rendlx.dlx' version = " + (TB2PluginVers() as string)
		longMessage += "\nScript version       = " + (gCurrentPluginVers as string)
		longMessage += "\nUpdate your tools."
		FnErrorMessage longMessage 
		
		return false
	)
	
	return true
)

--------------------------------------------------
--	Function: 	FnSetCurRenderer
--	Param:		rendID
--------------------------------------------------
fn FnSetCurRenderer rendID =
(
	if (rendID == gCurRendererID) then
	(
		return true
	)
	else if (UseRenderer rendID) then
	(
		gCurRendererID	= rendID
	)
	else
	(
		return false
	)
)

--------------------------------------------------
--	Function: 	FnGetAALevel
--	Param:		level			
--------------------------------------------------
fn FnGetAALevel =
(
	if (gAALevel == undefined) then
	(
		FnSetAALevel 1
	)
	
	return gAALevel
)

--------------------------------------------------
--	Function: 	FnGetAALevel
--	Param:		level			
--------------------------------------------------
fn FnSetAALevel lev =
(
	--if (SetAALevel gINIFile lev) then
	if (SetAALevel lev) then
	(
		gAALevel = lev
	)
	return gAALevel
)

--------------------------------------------------
--	Function: 	FnSetMainOutputPath
--	Param:		path
--------------------------------------------------
fn FnSetMainOutputPath path =
(
	if (path != undefined and path.count > 0) then
	(
		local pathCopy = path
		FnAppendToStr &pathCopy "\\"

		if (gDestPath != pathCopy) then
		(
			gDestPath = pathCopy
			setINISetting gINIFile "Buildings" "DestPath" gDestPath 
			return true
		)	
	)

	return false
)

----------------------------------------------------------------------------------------------------
-- Function:	ExportDATPath
----------------------------------------------------------------------------------------------------
fn ExportDATPath =
(
	return (gDestPath + (getFilenameFile maxFileName) + gExportExt)
)

----------------------------------------------------------------------------------------------------
-- Function:	FnLogMessage
-- Desc:			Just output straight to the log
----------------------------------------------------------------------------------------------------
fn FnLogMessage msgText = 
(
	--format (msgText + "\n") to:gQuietLogStream
	
	ok
)

----------------------------------------------------------------------------------------------------
-- Function:	FnCreateSceneBoundingBox			
-- Desc:			
----------------------------------------------------------------------------------------------------
fn FnCreateSceneBoundingBox name: =
(
	local bb
	
	if geometry.count > 0 then
	(
		local bbDim 	= geometry.max - geometry.min
		local bbCenter = geometry.center
		local bb 		= box width:bbDim.x length:bbDim.y height:bbDim.z
		
		bb.center = bbCenter
		
		if name != unsupplied then
		(
			bb.name = name
		)
	)
	
	return bb
)

----------------------------------------------------------------------------------------------------
-- Function:	FnGetBoxVert			
-- Desc:			
----------------------------------------------------------------------------------------------------
fn	GetBoxVert minPt maxPt vertIdx = 
(
	local vert = Point3 0 0 0
	
	vertIdx = ((mod vertIdx 8) as integer)
	
	if ((bit.and vertIdx 1)>0) then
		vert.x = maxPt.x
	else
		vert.x = minPt.x

	if ((bit.and vertIdx 2)>0) then
		vert.y = maxPt.y
	else
		vert.y = minPt.y

	if ((bit.and vertIdx 4)>0) then
		vert.z = maxPt.z
	else
		vert.z = minPt.z

	return vert
)

----------------------------------------------------------------------------------------------------
-- Function:	FnDebugDumpMesh
-- Desc:			Debuging function when working with meshes. Dumps mesh data to independant text window.
----------------------------------------------------------------------------------------------------
fn FnDebugDumpMesh meshNode = 
(
/*
	local vertIndex, faceIndex, vert, tVert
	local vFace, tvFace
	
	local debugStream
	
	debugStream = newScript()
	
	format "mesh: %\n" meshNode.name to:debugStream
	format "min: % max: %\n" meshNode.min meshNode.max to:debugStream
	format "num faces: %\n" meshNode.mesh.numfaces to:debugStream
	format "num verts: % tverts%\n" meshNode.mesh.numverts meshNode.mesh.numtverts to:debugStream

	for faceIndex in 1 to meshNode.numfaces do (
		vFace = getFace meshNode.mesh faceIndex
		tvFace = getTVFace meshNode.mesh faceIndex 
		
		format "Face %:\n" faceIndex  to:debugStream
		format "V: % % %\n" vFace.x vFace.y vFace.z  to:debugStream
		format "TV: % % %\n" tvFace.x tvFace.y tvFace.z  to:debugStream
	)
	
	format "\n" to:debugStream

	for vrtIndx in 1 to meshNode.mesh.numverts do (
		vert = getVert meshNode.mesh vrtIndx
		tVert = getTVert meshNode.mesh vrtIndx
		
		format "Vert %:\n" vrtIndx to:debugStream
		format "V: % % %\n" vert.x vert.y vert.z  to:debugStream
		format "TV: % % %\n" tVert.x tVert.y tVert.z  to:debugStream
	)
*/
)

----------------------------------------------------------------------------------------------------
-- Function:	FnDebugDumpMesh
-- Desc:			Debugging utility for binary files
----------------------------------------------------------------------------------------------------
fn HexDump filename = 
(
/*
	format "%\n" filename
	
	local binFile = fopen filename "rb"
	
	if (binFile != undefined) do (
		-- the old c trick to get the size of a file
		fseek binFile 0 #seek_end
		
		format "% bytes\n" (ftell binFile)
		fseek binFile 0 #seek_set
		
		local byteCount = 0
		local byte = 0
		
		while (true) do (
			byte = (readByte binFile #unsigned)
			if (byte == undefined) do exit
			
			if (byte < 16) do format "0"
			
			format "% " (bit.intAsHex byte)
			
			byteCount += 1
			if (byteCount == 4) do format " "
			if (byteCount == 8) do (
				format "\n"
				byteCount = 0
			)
		)
		
		fclose binFile
		format "\n"
	)
	
	OK
*/
)

---------------------------------------------------------------------------------------------------
-- Function: FnEnlargeBox2	
--	Param
---------------------------------------------------------------------------------------------------
fn FnEnlargeBox2 &box margin:1 pow2:true = 
(
	box.left 	-= margin
	box.top 		-= margin
	box.right 	+= margin
	box.bottom	+= margin
	
	if pow2 then
	(
		local maxDim = box.w

		if (box.h > box.w) then
		(
			maxDim = box.h
		)

		if (maxDim <= 257) then 
		(
			box.h = pow 2 (ceil ((log (box.h))/(log 2)))
			box.w = pow 2 (ceil ((log (box.w))/(log 2)))
		)
		else
		(
			box.h = 256 * (ceil ((box.h)/256.0) as integer)
			box.w = 256 * (ceil ((box.w)/256.0) as integer)
		)
	)

	return OK
)

--------------------------------------------------------------
-- Enumeration function used by below function
--------------------------------------------------------------
fn FnCheckEnumerate filename nameArray = (
	append nameArray filename 
)

--------------------------------------------------------------
-- Do a check for missing Maps & give warning
--------------------------------------------------------------
fn FnCheck4MissingBitmaps = (
	local nameList = #()
	
	enumerateFiles FnCheckEnumerate nameList #missing
	
	if (nameList.count != 0) then (
		local allNames = ""
		local curName
		
		for curName in nameList do (
			allNames += (curName+"\n")
		)
		
		fnErrorMessage ("Scene has missing files:\n" + allNames )
		return true
	)
	else
		return false
)

--------------------------------------------------------------
-- FnResetMaterialEditor - Does what it says.
-- This is useful because the missing Maps query will tell
-- you about missing maps in the material editor
--------------------------------------------------------------
fn FnResetMaterialEditor = 
(
	local index = 0
	
	for index in 1 to meditmaterials.count do (
		meditmaterials[index] = standardmaterial()
	)
)

--------------------------------------------------------------
-- FnSceneHasMissingMaps just enumerates the missing maps
-- (after resetingthematerialeditor) if it finds any it
-- returns true and appends their name to the array 'list'
--------------------------------------------------------------
fn FnSceneHasMissingMaps list = 
(
	-- clear out the material editor so they wont be included in missing map check
	FnResetMaterialEditor()
	
	local initialCount = list.count
	
	-- list missing maps - direct from MaxScript help
	fn addmap mapfile fileList = 
	( 
		local mapfileN=mapfile as name 
		local index=finditem fileList mapfileN 
		if index == 0 do append fileList mapfileN 
	)
	
	enumeratefiles addmap list #missing
	
	return (list.count != initialCount)
)

--------------------------------------------------------------
-- Find all the biped roots in a scene
-- returns true if it finds any and lists them in the bipArray
-- parameter. Note - this will get confused if the root of one
-- biped is linked to a bone of another, also if you change
-- the name of the root to something that doesn't start with 'bip'
--------------------------------------------------------------
fn FnFindBipeds bipArray = 
(
	local initialCount = bipArray.count
	
	local n
	
	for n in $*bip* do (
		if (((classof n)==Biped_Object)and((classof n.parent)!=Biped_Object)) do (
			append bipArray n
		)
	)
	
	return (bipArray.count != initialCount)
)

--------------------------------------------------------------
-- search a node heirarchy for a node with a particular name
-- this is useful when working with XRef scenes when the normal
-- $path variables won't find objects in the XRef Scenes
--------------------------------------------------------------
fn FnFindChildNode nameStr findRoot = 
(
	local stackArray= #()
	local curNode
	local soughtNode
	local foundIt = false
	
	append stackArray findRoot
	
	while ((stackArray.count > 0) and (not foundIt)) do (
		-- pop node off top of stack
		curNode = stackArray[stackArray.count]
		deleteItem stackArray stackArray.count
		
		-- is this what we're looking for?
		if (curNode.name == nameStr) then (
			soughtNode = curNode
			foundIt = true
		)
		else (
			if (curNode.children.count>0) do (
				-- push children on stack to search them next
				local childIndex
				
				for childIndex in 1 to curNode.children.count do (
					append stackArray curNode.children[childIndex]
				)
			)
		)
	)
	
	soughtNode
)

--------------------------------------------------------------
-- create a collection that includes a node an all it's children
-- this is usefull primarily for saving a heirarchy with saveNodes
--------------------------------------------------------------
fn FnCollectTree treeRoot = 
(
	local stackArray = #()
	local curNode
	local resultCollection = #()
	
	append stackArray treeRoot 
	
	while (stackArray.count > 0) do (
		-- pop node off top of stack
		curNode = stackArray[stackArray.count]
		deleteItem stackArray stackArray.count
		
		append resultCollection curNode
		
		if (curNode.children.count>0) do (
			-- push children on stack to search them next
			local childIndex
			
			for childIndex in 1 to curNode.children.count do (
				append stackArray curNode.children[childIndex]
			)
		)
	)
	
	resultCollection 
)

--------------------------------------------------------------
-- Find a node with a particular name in scene or XRefs
-- this is useful when working with XRef scenes when the normal
-- $path variables won't find objects in the XRef Scenes
--------------------------------------------------------------
fn FnGlobalFindNode nameStr = 
(
	local soughtNode
	local xrefCount = xrefs.getXRefFileCount()

	-- first just see if this is the easy case where the sought node is in the current scene
	soughtNode = FnFindChildNode nameStr rootNode
	
	if ((soughtNode == undefined) and (xrefCount > 0)) do (
		local stackArray= #()
		local curScene
		local foundIt = false
		local xrefIndex
		
		-- seed stack with scene that this scene xrefs
		for xrefIndex in 1 to xrefCount do (
			append stackArray (xrefs.getXRefFile xrefIndex)
		)
		
		while ((stackArray.count > 0) and (not foundIt)) do (
			-- pop next scene off top of stack
			curScene = stackArray[stackArray.count] -- we could make this a breadth first search by replacing
			deleteItem stackArray stackArray.count -- stackArray.count with 1 in both these lines
			
			-- has this scene got what we're looking for?
			soughtNode = FnFindChildNode nameStr curScene.tree
			if (soughtNode != undefined) then (
				foundIt = true
			)
			else (
				xrefCount = xrefs.getXRefFileCount root:curScene
				
				if (xrefCount>0) do (
					-- push children on stack to search them next
					for xrefIndex in 1 to xrefCount do (
						append stackArray (xrefs.getXRefFile xrefIndex root:curScene)
					)
				)
			)
		)
	)
	
	soughtNode
)

--------------------------------------------------------------
-- GEOMETRY & 3D MATH UTILITIES
--------------------------------------------------------------

--------------------------------------------------------------
-- The ray & plane functions associated with the manipulator
-- libraries seem to be unreliable. The following structs
-- replace the functions that I need from those libraries
--------------------------------------------------------------

--------------------------------------------------------------
-- Here's the ray structure I will use
--------------------------------------------------------------
struct stRay3D (
	pos = (point3 0 0 0),
	dir = (point3 0 0 1)
)

--------------------------------------------------------------
-- Here's the plane structure I will use
--------------------------------------------------------------
struct stPlane3D
(
	normal = (point3 0 0 1),
	offset = 0.0,
	
	fn Init nrm pt = (
		normal = nrm
		normalize normal
		offset = -(dot normal pt)
		
		ok
	),
	
	fn Intersection intRay = (
		local divisor = (dot intRay.dir normal)
		
		if (divisor == 0.0) then (
			return undefined
		)
		else (
			local rayDist = - ((dot normal intRay.pos) + offset)/divisor
			
			if (rayDist >=0) then (
				return (intRay.pos + (intRay.dir * rayDist))
			)
			else (
				return undefined
			)
		)
	)
)

--------------------------------------------------------------
-- Transform a point with a matrix.
-- I can't believe it , but MaxScript doesn't define this.
-- Well, actually, I believe it.
--------------------------------------------------------------

fn FnTransformPt pt mat = 
(
	local resultPt = (point3 0 0 0)
	
	resultPt.x = mat.row1.x * pt.x + mat.row2.x * pt.y + mat.row3.x * pt.z + mat.row4.x 
	resultPt.y = mat.row1.y * pt.x + mat.row2.y * pt.y + mat.row3.y * pt.z + mat.row4.y 
	resultPt.z = mat.row1.z * pt.x + mat.row2.z * pt.y + mat.row3.z * pt.z + mat.row4.z 
	
	return resultPt
)

--------------------------------------------------------------
-- Get a ray corresponding to a pixel on the screen
-- only works with ortho cameras
-- Obsolete
--------------------------------------------------------------
fn FnSafeScreenToRay pixelPt = (
	local p0, p1
	local projXform
	local resultRay = stRay3D()
	
	--gw.setTransform (matrix3 1) -- paranoia
	
	projXform = inverse (viewport.getTM()) -- xform takes view space to world
	
	-- get point behind pixel in viewspace
	p0 = mapScreenToView pixelPt 4000.0 -- 4000 was empirically determined to be what mapScreenToWorldRay uses
	-- transform point into world
	resultRay.pos = FnTransformPt p0 projXform 
	
	-- get point a little further behind pixel in viewspace
	p1 = mapScreenToView pixelPt 3990.0
	-- transform point into world
	p1 = FnTransformPt p1 projXform 
	
	resultRay.dir = p1 - resultRay.pos
	
	normalize resultRay.dir
	
	return resultRay
)

--------------------------------------------------------------
-- similar to above, but this one just collects all the names
-- it doesn't load the files or do any processing
-- namelist will be an array of full path strings
--------------------------------------------------------------
fn GetAllMaxFileNamesInTree rootPath namelist = (
	local folderStack = #()
	local curPath = ""
	
	append folderStack rootPath
	
	while (folderStack.count > 0) do (
		local folderList = #()
		
		-- pop node off top of stack
		curPath = folderStack[folderStack.count]
		deleteItem folderStack folderStack.count
		
		-- push child folders onto recursion stack
		folderList = getDirectories (curPath + "*")
		join folderStack folderList
		
		-- now process any max files we find in the current folder
		folderList = getFiles (curPath +"*.max") -- this should mostly be a single file
		
		for curPath in folderList do (
			append namelist curPath
		)
	)
	
	OK
)
