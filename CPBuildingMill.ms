--------------------------------------------------------------------------------
--	Script file guard
--	Examine its value to see how many times the script was run.
--------------------------------------------------------------------------------
if (guardBuildingMill == undefined) then
(
	global guardBuildingMill = 0
)
guardBuildingMill += 1

-- ARNOLD CONVERSION: forward-declare as GLOBAL so it is visible to every function
-- in this file regardless of definition order (autoadjust, defined below, calls it).
global FnIsArnoldActive
global FnSwapToScanlineForGBuffer
global FnRestoreRenderer
global FnMeasureRecenterShift
global FnApplyShift
global FnPushExportBg
global FnPopExportBg

--------------------------------------------------------------------------------
--	Make sure TB2 starup was executed first.
--------------------------------------------------------------------------------

If (guardTB2Startup == undefined) then
(
	global guardTB2Startup = 0
FileIn ((getDir #startupScripts) + "\\CPTB2Startup.ms")
)

----------------------------------------------------------------------------------------------------
-- Includes
----------------------------------------------------------------------------------------------------

FnTB2FileInOnce "CPScriptUtils.ms"		guardScriptUtils
FnTB2FileInOnce "CPModelNames.ms" 	guardModelNames
FnTB2FileInOnce "CPCameraRig.ms" 	guardCameraRig

--------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

-- constants to test if a mat is a multimat
kMultiMatClass1 	= 512
kMultiMatClass2 	= 0

-- local constansts - sort of
kNightMaterialID	= 15
-- we're disabling this feature just before Beta
kNightBlurRadius 	= #(0.001, 0.001, 0.001, 0.001, 0.001) 

-- parameters by zoom level for night texture generation
kMaskScaleFactor 	= #(2, 2, 1, 1, 1) -- amount of normal window mask to mix into result alpha
kBlurScaleFactor 	= #(8, 5, 3, 2, 1) -- amount of blured window mask to mix into result alpha

kNigthColor			= (Point3 .501961 .470588 .752941)

kWindowSetStr		= "TB2_WindowSet"

windowTextureMapArray 	= #() -- initialize this at first export

kBuildingTypeStr 		= "TB2_BuildingType"
kLegalBuildingTypes 	= #("building", "foundation")

kWindowOpacityFileProperty = "Window Opacity"
gWindowOpacityMin		= 0.0
gWindowOpacityMax		= 1.0
--CP THE FOLLOWING VARIABLES ADDED BY ME FOR DEBUGGING
gCurStepCP = 0
gfArrayCP
gfidxCP
gpathstrCP
gOKpathCP
gSectionCP
gfaCP
gdCP
gfCP
gFindTestCP
gCPtest		


fn getMaxversion =
(
	local george = maxversion()
	return george[1]
)	
-------------------------------------------------------------------------
-- adjusts the rendered output to the correct position for cutting
-------------------------------------------------------------------------
fn autoadjust image =
(
    -- ARNOLD CONVERSION: this routine was a Mental-Ray workaround for the
    -- region-crop render leaving a black band at the top of the frame -- it
    -- scans down to the first non-black row and shifts the whole image up to
    -- remove that band.
    --
    -- Under Arnold the orthographic camera frames the building correctly with
    -- NO black band at top (verified: the Preview button renders perfectly with
    -- no autoadjust). Running autoadjust anyway finds the building near the top
    -- of the correctly-framed image and shifts everything UP, cropping off the
    -- top of the building and padding black at the bottom. That upward shift is
    -- exactly the "floating higher / closer to camera" offset seen at every
    -- zoom/rotation after export. So under Arnold we must leave the render
    -- untouched.
    if (FnIsArnoldActive()) do return image

    bit_h = image.height
    bit_w = image.width
    image_s = 1

    --search for the first non-black pixel
    --to find where the framing error ends
    for y = 1 to bit_h do
    (
        if (getPixels image [0, y] 1)[1].value != 0 do
        (
            image_s = y
            exit
        )
    )
    
    --print image_s
    setPt = 0
	tempImage = bitmap bit_w bit_h
    -- moves the image from calculated line up to the first line to remove framing problems
    for y = image_s to bit_h + 1 do
    (
        setPixels tempImage [0, setPt] (getPixels image [0, y] bit_w)
        setPt += 1
    )
    copy tempImage image
    return image
)

--------------------------------------------------------------------------------------
-- ARNOLD CONVERSION: recenter helpers
--
-- Under Arnold, the orthographic camera centers the view ~19% lower than the
-- Mental Ray / gmax camera the rig's UV-mapping math was tuned for. The result:
-- the rendered building sits below where the compositing expects it, so the
-- exported tile is offset vertically (and the building can be clipped at top).
--
-- We split recentering into two steps so the SAME shift can be applied to BOTH
-- the beauty render and its alpha (which come from separate targa files but must
-- stay aligned):
--   FnMeasureRecenterShift : measure the building's pixel bbox, return the
--                            integer (shiftX, shiftY) needed to center it.
--   FnApplyShift           : apply a known shift to a bitmap, filling exposed
--                            area with 'bgGray'.
--
-- 'bgGray' is the background to detect (gray 128 for beauty, transparent black
-- for alpha). 'tol' is the per-channel tolerance for "is this a building pixel".
--------------------------------------------------------------------------------------
fn FnMeasureRecenterShift image bgGray:(color 128 128 128) tol:30 =
(
    local bit_w = image.width
    local bit_h = image.height

    local minX = bit_w
    local maxX = 0
    local minY = bit_h
    local maxY = 0
    local found = false
    for yy = 0 to (bit_h - 1) do (
        local row = getPixels image [0, yy] bit_w
        for xx = 1 to bit_w do (
            local p = row[xx]
            -- treat alpha-0 as background for alpha bitmaps
            local isBg = false
            if (classOf p) == ColorValue do (
                if (p.a == 0) then isBg = true
                else if (abs (p.r - bgGray.r) <= tol) and (abs (p.g - bgGray.g) <= tol) and (abs (p.b - bgGray.b) <= tol) do isBg = true
            )
            if (not isBg) do (
                found = true
                if (xx-1) < minX do minX = (xx-1)
                if (xx-1) > maxX do maxX = (xx-1)
                if yy < minY do minY = yy
                if yy > maxY do maxY = yy
            )
        )
    )

    if (not found) do return (point2 0 0)

    local bcx = (minX + maxX) / 2.0
    local bcy = (minY + maxY) / 2.0
    local shiftX = ((bit_w / 2.0) - bcx) as integer
    local shiftY = ((bit_h / 2.0) - bcy) as integer
    return (point2 shiftX shiftY)
)

fn FnApplyShift image shift bgGray:(color 128 128 128) =
(
    local shiftX = (shift.x as integer)
    local shiftY = (shift.y as integer)
    if (shiftX == 0) and (shiftY == 0) do return image

    local bit_w = image.width
    local bit_h = image.height
    local tempImage = bitmap bit_w bit_h color:bgGray

    for yy = 0 to (bit_h - 1) do (
        local srcY = yy - shiftY
        if srcY >= 0 and srcY < bit_h then (
            local row = getPixels image [0, srcY] bit_w
            if shiftX == 0 then (
                setPixels tempImage [0, yy] row
            ) else (
                local newRow = for k in 1 to bit_w collect bgGray
                for k in 1 to bit_w do (
                    local dstX = (k - 1) + shiftX
                    if dstX >= 0 and dstX < bit_w do newRow[dstX + 1] = row[k]
                )
                setPixels tempImage [0, yy] newRow
            )
        )
    )
    copy tempImage image
    return image
)

--------------------------------------------------------------------------------------
-- ARNOLD-CONVERSION RENDERER SWAP HELPERS
--
-- The night-window and night-alpha compositing (getchannel #objectID/#coverage/
-- #shaderColor/#shaderTransparency) relies on the legacy 3ds Max G-Buffer. Arnold
-- does NOT populate the G-Buffer, but the Scanline renderer does. So we render the
-- two G-Buffer-dependent mask passes with Scanline and keep Arnold for everything
-- else (day beauty, preview). These helpers save the current renderer, switch to
-- Scanline, and restore it.
--
-- NOTE: scanline is the renderer the BAT G-Buffer system was originally designed
-- for; mask quality is correct and the compositing code is left untouched.
--------------------------------------------------------------------------------------

-- Save the current (Arnold) renderer and switch to Scanline. Returns the saved
-- renderer so the caller can restore it. Returns undefined on failure.
fn FnSwapToScanlineForGBuffer =
(
	local saved = renderers.current
	try (
		renderers.current = Default_Scanline_Renderer()
	) catch (
		try ( renderers.current = Scanline_Renderer() ) catch ()
	)
	return saved
)

-- Restore a previously-saved renderer (typically Arnold).
fn FnRestoreRenderer savedRenderer =
(
	if savedRenderer != undefined do
	(
		try ( renderers.current = savedRenderer ) catch ()
	)
	return ok
)

--------------------------------------------------------------------------------------
-- autoadjust is an MR-framing workaround. Arnold frames correctly, so make it a
-- no-op when Arnold is current (otherwise it over-crops the top of the image).
--------------------------------------------------------------------------------------
fn FnIsArnoldActive = ((findString ((classOf renderers.current) as string) "Arnold") != undefined)


------------------------------------------------------------------------
-- Function to Insert DayView FSHs
------------------------------------------------------------------------
fn executebatchfsh =
(
	local batchcmd = (getDir #maxroot) + "gamepacks\\bat\\" + (getfilenamefile gSC4ModelName) + ".bat"

	if (FnExistFile batchcmd) then
	(
		local result = doscommand ("\"" +batchcmd + "\"")
	) else
	(
		return true
	)

	return false
)


----------------------------------------------------------------------------------------------------
-- Function:	FnZoomRotInfoString
-- Param:		zom
-- Param:		rot
----------------------------------------------------------------------------------------------------

fn FnZoomRotInfoString zom rot = 
(
	local str = "Zoom: " + (zom as string) + " View: " 
	
	case rot of
	(
		1:	str += "South"
		2:	str += "East"
		3:	str += "North"
		4:	str += "West"
	)
	
	return str
)

----------------------------------------------------------------------------------------------------
-- Function:	FnZoomRotInfoStringCP 
-- Param:		zom
-- Param:		rot
--CP THIS IS NEW VERSION OF THE ABOVE FUNCTION, CHANGED FOR .BMP FILE SAVE
----------------------------------------------------------------------------------------------------

fn FnZoomRotInfoStringCP zom rot = 
(
	local str = "Z" + (zom as string) + "V" 
	
	case rot of
	(
		1:	str += "South"
		2:	str += "East"
		3:	str += "North"
		4:	str += "West"
	)
	
	return str
)

----------------------------------------------------------------------------------------------------
-- Function:	FnGetBoundsNearestCorner 
-- Param:		nodes	- collection of nodes
-- Param:		dir		- vector pointing in far direction (the camera view vector) 
----------------------------------------------------------------------------------------------------
fn FnGetBoundsNearestCorner nodes dir =
(
	local maxPt, minPt, closePt
	
	maxPt = nodes.max
	minPt = nodes.min
	
	closePt = (point3 0 0 0)
	
	if (dir.x > 0) then (
		closePt.x = minPt.x
	)
	else (
		closePt.x = maxPt.x
	)
	
	if (dir.y > 0) then (
		closePt.y = minPt.y
	)
	else (
		closePt.y = maxPt.y
	)
	
	if (dir.z > 0) then (
		closePt.z = minPt.z
	)
	else (
		closePt.z = maxPt.z
	)
	
	return closePt
)

----------------------------------------------------------------------------------------------------
-- Function:	FnRemoveBackFaces 
-- Param:		objMesh - object to be culled
-- Param:		dir     - camera direction
----------------------------------------------------------------------------------------------------
fn FnRemoveBackFaces objMesh dir = 
(
	local numFaces,index,norm,faceList
	
	faceList = #()
	
	numFaces = getNumFaces objMesh
	
	-- get list of back facing faces
	for index in 1 to numFaces do 
	(
		norm = getFaceNormal objMesh index
		if (dot norm dir) > 0 then 
		(
			append faceList index
		)
	)
	
	delete objMesh.Faces[faceList]
)

----------------------------------------------------------------------------------------------------
-- Function:	FnMeshLocalToWorld 
-- Param:		obj
----------------------------------------------------------------------------------------------------
fn FnMeshLocalToWorld obj = 
(
	-- Get the original node transform matrix
	local ntm = obj.transform
	
	-- The new object transform should be identity
	obj.transform= (matrix3 1)
	
	-- Compute the pivot transform matrix
	local piv=obj.objecttransform 
	
	-- Reset the object offsets to 0
	obj.objectoffsetPos  = [0,0,0]
	obj.objectoffsetRot = (quat 0 0 0 1)
	obj.objectoffsetScale = [1,1,1]
	
	-- Apply the pivot transform matrix to the modified original node transform matrix
	-- to get the XForm gizmo transform
	ntm = piv * ntm
	
	-- apply an XForm modifier to the node
	local xformMod=xform()
	addmodifier obj xformMod
	
	-- set the XForm modifier's gizmo tranform
	xformMod.gizmo.transform=ntm
	
	-- finally, collapse everything back to an editable mesh
	collapseStack obj
	
	-- return value of ok
	ok
)

----------------------------------------------------------------------------------------------------
-- Function:	FnApplyScreenRegionUVMapping 
-- Param:		obj 
-- Param:		scrnBox 
-- N.B.			It is assumed that object is an editMesh at this point
----------------------------------------------------------------------------------------------------
fn FnApplyScreenRegionUVMapping obj renderBox = 
(
	local vert, camPt, uvwPt, vrtIndx

	meshop.defaultMapFaces obj.mesh 1

	-- set transform to object local
	gCameraRig.localToWorldXform = obj.objecttransform
	
	for vrtIndx in 1 to obj.mesh.numverts do 
	(
		vert = getVert obj.mesh vrtIndx
		
		-- transform object local coordinates to screen
		camPt = gCameraRig.GetRenderPos vert
		
		-- round to nearest pixel position
		camPt.x = floor (camPt.x + .5)
		camPt.y = floor (camPt.y + .5)
	)
)

----------------------------------------------------------------------------------------------------
-- Function:	FnApplyDicedRegionUVMapping 
-- Param:		obj 
-- Param:		renderBox 
----------------------------------------------------------------------------------------------------
fn FnApplyDicedRegionUVMapping obj renderBox =
(
	local vert, cornerPt, uvwPt, vrtIndx, u, v
	local avgPt = (point3 0 0 0)
	
	meshop.defaultMapFaces obj.mesh 1
	
	-- set transform to object local
	gCameraRig.localToWorldXform = obj.objecttransform
	
	-- guess at corner location from average mesh vert
	for vrtIndx in 1 to obj.mesh.numverts do 
	(
		vert = getVert obj.mesh vrtIndx
		avgPt.x += vert.x
		avgPt.y += vert.y
		avgPt.z += vert.z
	)
	
	avgPt.x = avgPt.x/obj.mesh.numverts
	avgPt.y = avgPt.y/obj.mesh.numverts
	avgPt.z = avgPt.z/obj.mesh.numverts
	
	camPt = gCameraRig.GetRenderPos avgPt
	
	-- round to nearest pixel position
	camPt.x = floor (camPt.x + .5)
	camPt.y = floor (camPt.y + .5)
	
	-- which 256*256 page did that point fall in?
	cornerPt = (point2 0 0)
	cornerPt.x = renderBox.x + ((((camPt.x-renderBox.x) as integer)/256)*256)
	cornerPt.y = renderBox.y + ((((camPt.y-renderBox.y) as integer)/256)*256)
		
	for vrtIndx in 1 to obj.mesh.numverts do 
	(
		vert = getVert obj.mesh vrtIndx
		
		-- transform object local coordinates to screen
		camPt = gCameraRig.GetRenderPos vert
		
		-- round to nearest pixel position
		camPt.x = floor (camPt.x + .5)
		camPt.y = floor (camPt.y + .5)
		u = (camPt.x-cornerPt.x)/256.0
		v = 1-((camPt.y-cornerPt.y)/256.0)
	)
)

----------------------------------------------------------------------------------------------------
-- Function:	FnMakeSlabs 
-- Param:		meshNode	- source mesh to slice, not changed by procedure, must have 1 to 1 mapping verts (results from meshop.defaultMapFaces objmesh 1)
-- Param:		numSlabs	- number of slabs to generate
-- Param:		normal		- normal to slice planes
-- Param:		base		- the origin of the slices (each slice offset = base + index*step )
-- Param:		step		- thickness of slabs relative to normal
-- Param:		parts		- array to accumulate the generated slab
----------------------------------------------------------------------------------------------------
fn FnMakeSlabs meshNode numSlabs normal base step parts =
(
	local aboveMesh, belowMesh
	local slabIndex, vertIndex
	local vert, tVert, mapVal
	local offset
	
	offset = base
	aboveMesh = copy meshNode
	
	for slabIndex in 1 to numSlabs do 
	(
		offset += step
		
		belowMesh = copy aboveMesh
		belowMesh.name = uniqueName "TB2_DiceTemp"
		
		meshop.slice aboveMesh aboveMesh.Faces normal offset delete:true node:meshNode 
		meshop.slice belowMesh belowMesh.Faces (-normal) (-offset) delete:true node:meshNode
		
		meshop.deleteIsoVerts aboveMesh.mesh
		meshop.deleteIsoVerts belowMesh.mesh
		
		meshop.optimize aboveMesh.mesh 40 0 0.1 0 saveSmoothBoundaries:false autoEdge:false
		meshop.optimize belowMesh.mesh 40 0 0.1 0 saveSmoothBoundaries:false autoEdge:false
		
		meshop.deleteIsoVerts aboveMesh.mesh
		meshop.deleteIsoVerts belowMesh.mesh
		
		update aboveMesh 
		update belowMesh
		
		append parts belowMesh
		
		lastOffset = offset
	)
	
	-- at this point aboveMesh is empty
	delete aboveMesh 
	
	return parts
)

----------------------------------------------------------------------------------------------------
-- Function:	SetWindowSet 
-- Param:		setName 
-- Desc:		Sets window set number in file properties.
----------------------------------------------------------------------------------------------------

fn SetWindowSet setName = 
(
	if (setName  !=undefined )then 
	(
		fileProperties.addProperty #custom kWindowSetStr setName
		
		-- apparently Max doesn't notice when you change custom properties
		-- So... I'm messing with the scene a little to force Max to treat the scene as dirty
--RN commented out trying to determine why script is causing the scene to be dirty
--		local dummyNode = (box())
--		delete dummyNode 
	)
)

----------------------------------------------------------------------------------------------------
--CP ADDED THIS FUNCTION TO REPLACE INACCESSIBLE DLL FUNCTION
-- Function:	GetNightWindowSets 
-- Desc:		Gets window sets to fill dropdown box in menu.
----------------------------------------------------------------------------------------------------
fn GetNightWindowSets = 
(
	local PathStrCP = ""
	local OKPathCP = ""
	local foundCP = 1
	local PathArrayCP
	local findtestCP
	local OKPathCP = ""
	local didxCP
	local dCP = (getDirectories (gNightMatPathCP + "*"))
	for didxCP in dCP do     --each didx is a night mat directory name
	(
		faCP = getfiles (didxCP + "*.*")
		if (faCP.count >= 5) then
		(
			local fidxCP = 1
			for fCP in faCP do     --each fcp is a full texture file name
			(
				findTestCP = (findstring (getfilenamefile fCP) "-z5")
				if (findtestCP != undefined) then
				(
					exit
				)
				fidxCP += 1
			)
			for zidxCP = 4 to 1 do
			(
				if ((findTestCP != undefined) and (foundCP != 0)) then
				(
					foundCP = (getfiles (didxCP + (replace (getfilenamefile fCP) findTestCP 3 ("-z" + (zidxCP as string))))).count
				)
				
			)
			if (findTestCP != undefined and foundCP != 0) then
			(
				PathArrayCP = (filterstring didxCP "\\")
				sectionCP = PathArrayCP.count
				OKPathCP = PathArrayCP[sectionCP]
				PathStrCP = (PathStrCP + OKPathCP + ";")
			)
		)	
	)
	return PathStrCP
)
----------------------------------------------------------------------------------------------------
-- Function:	GetWindowSet 
-- Desc:		Gets window set name (or number) from file properties.
----------------------------------------------------------------------------------------------------
fn GetWindowSet = 
(
	local typeIndexW = (fileProperties.findProperty #custom kWindowSetStr)
	local setNameW	 = ""
	
	if (typeIndexW > 0) then 
	(
		setNameW = fileProperties.getPropertyValue #custom typeIndexW
	)
	else
	(
		local localSets = GetNightWindowSets()
		
		if (localSets != undefined and localSets.count > 1) then
		(
			local setArray = filterstring localSets ";"
			
			if (setArray.count > 0) then
			(
				setNameW = setArray[1]
				SetWindowSet setNameW
			)
		)
	)
	setNameW
)

----------------------------------------------------------------------------------------------------
-- CP new function for accessing night window texture files
-- Function:	GetNightWindowFile
-- Parameter:   zoomnum     current zoom level
-- Desc:		Gets window texture filename less zoom number
----------------------------------------------------------------------------------------------------
fn GetNightWindowFile zoomnum = 
(
	--gNightMatPathCP + getwindowset gives the directory
	local NightWinFile
	local winsetCP = ""
	winsetCP = GetWindowSet()
	if (getfiles (gNightMatPathCP + winsetCP + "\\*-z" + (zoomnum as string) + ".*")).count != 0 then
	(
		NightWinFile = (getfiles (gNightMatPathCP + winsetCP + "\\*-z" + (zoomnum as string) + ".*"))
	)
	else
	(
		FnErrorMessage ("Night window texture not Found")
	)
	NightWinFile
)

----------------------------------------------------------------------------------------------------
-- Function:	GetWindowOpacity 
-- Desc:		Gets night windows opacity from file properties.  
----------------------------------------------------------------------------------------------------

fn GetWindowOpacity absolute = 
(
	local idx = (fileProperties.findProperty #custom kWindowOpacityFileProperty)
	
	if (idx > 0) then 
	(
		local opacity = fileProperties.getPropertyValue #custom idx
		if ((opacity != undefined) and (opacity >= gWindowOpacityMin) and (opacity <= gWindowOpacityMax)) then 
		(
			if absolute then
			(
				return opacity
			)
			else
			(
				return gWindowOpacityRelMin + opacity * (gWindowOpacityRelMax - gWindowOpacityRelMin)
			)

		)
		else 
		(
			FnErrorMessage ("Invalid Window Opacity '" + (opacity as string) + "' set in custom file properties. Please set the value using the Building Mill rollout.")
		)
	)
	
	return 1.0
)

----------------------------------------------------------------------------------------------------
-- Function:	SetWindowOpacity 
-- Param:		opacity 
-- Desc:		Sets night windows opacity in file properties.  
----------------------------------------------------------------------------------------------------

fn SetWindowOpacity opacity = 
(
	if ((opacity != undefined) and (opacity >= gWindowOpacityMin) and (opacity <= gWindowOpacityMax)) then 
	(
		fileProperties.addProperty #custom kWindowOpacityFileProperty opacity
		
		-- apparently Max doesn't notice when you change custom properties
		-- So... I'm messing with the scene a little to force Max to treat the scene as dirty
		--local dummyNode = (box())
		--delete dummyNode 
	)
	else 
	(
		FnErrorMessage ("Attempting to set illegal Window Opacity:'" + (opacity as string) +"'\nThis is a script bug.")
	)
)

----------------------------------------------------------------------------------------------------
-- Function:	FnEnableNightLigts 
-- Param:		shine (true - shine; false - not shine) 
----------------------------------------------------------------------------------------------------
fn FnEnableNightLigts shine=
    (
        --check first if our scen has any lights at all
        if ($lights.count >0) do
            (
                --create For loop with lt var
                for lt in $lights do
                    (
                        --filter out possible Targets in $lights
                        if (lt.classID[1] != 4128) do
                            (
                                --following is effectivelly switches between daylights (if at all present in the scene) and nightlights
                                --first chek for the "nightlight" prefix
                                local namePreffix = (substring lt.name 1 8)
                                if (namePreffix == "nightlight") then
                                    (
                                        lt.on = shine
                                    )
                                else
                                    (
                                        lt.on = not shine
                                    )   
                            )
                    )
            )
    )


----------------------------------------------------------------------------------------------------
-- Function:	FnDoRender2 
-- Param:		renderBox 	
-- Param:		renderNight 
----------------------------------------------------------------------------------------------------
fn FnDoRender2 renderBox renderNight display:#all = 
(
	-- render the high res building to a bitmap
----------------------------------------------------------
--CP  THE FOLLOWING FOR FILE NAMING PURPOSES	
	local thisModelTypeCP 	= #building 
	local BmpNameCP = stModelName()
		if (not BmpNameCP.Init maxfilename gDestPath modelType:thisModelTypeCP) do 
		(
			local errorMsg = "Model name structure failed to initialize!"
			messageBox errorMsg
			throw errorMsg
		)
     BmpNameCP.zoom = gcamerarig.curzoom
     BmpNameCP.rot = gcamerarig.currot
	 
----------------------------------------------------------
	-- set the active viewport to our camera so we can do a region render
	viewport.setCamera gCameraRig.curCam -- I believe this is no longer necessary - pit's just what we're used to seeing
     local renderwidCP = gcamerarig.renderwidth
	 local renderhtCP = gcamerarig.renderheight

	local zoomlevel 	= gCameraRig.curZoom
	local rotCam 	= gCameraRig.curRot
	local captionInfo	= FnZoomRotInfoStringCP zoomlevel rotCam
	local displayDay	= (display == #all or display == #day)
	local tempCamera 	= gCameraRig.CreateRenderCam renderBox
	viewport.setCamera tempcamera
	--FnEnableNightLigts false	-- disable local night lights for first render	
	rendHidden 		= false 		-- this stung us once force it off
	renderEffects 	= false		-- disable render effects
-----------------------------------------------
--CP NEW RENDERING CODE HERE

    rendAtmosphere 	= false
	--CP Make directory if it doesn't already exist
	local CurrFshDir = (gDestPath + BmpNameCP.textureoutputGUID())
	local DirectoryCheckCP = #()
	DirectoryCheckCP = getDirectories (CurrFshDir + "*")
	if DirectoryCheckCP.count == 0 then
	(     
		makedir CurrFshDir
	)
	else
	(
		fndeletefiles (CurrFshDir + "\\*.bmp")
		fndeletefiles (CurrFshDir + "\\*.png")
		fndeletefiles (CurrFshDir + "\\*.fsh")
		fndeletefiles (CurrFshDir + "\\*.tga")
	)
	 
	 
    local RenfileNameCP = CurrFshDir + "\\0000"
 	local RenfileAlphaNameCP = CurrFshDir + "\\A_0000"
	local TruOne = CurrFshDir + "\\0001"
	local TruOneAlpha = CurrFshDir + "\\A_0001"
	rendsavefile = true
--CP SET TARGA INTERFACE FOR ALPHA SPLIT TO GENERATE ALPHA IMAGE
    targa.itgaio.setcolordepth 32
    targa.itgaio.setalphasplit true
	-- ARNOLD FIX: Disable premultiplied alpha for Arnold. The alpha mask comes from
	-- a separate Scanline pass whose edges don't perfectly align with Arnold's AA.
	-- Premult over black darkens edge pixels, producing a visible dark outline in-game.
	-- Straight alpha lets the Scanline alpha mask cleanly cut the sprite boundary.
	if (FnIsArnoldActive()) then (
		targa.itgaio.setPreMultAlpha false
	) else (
		targa.itgaio.setPreMultAlpha true
	)

	-- ARNOLD CONVERSION: render the EXPORT against a BLACK background. The
	-- preview uses gray so the window isn't pure black, but premultiplied alpha
	-- (set above) over a gray bg bleeds gray into edge pixels, producing a
	-- bright gray outline in every exported FSH tile. The original Mental-Ray
	-- BAT rendered against black, so premult edges bled to black (invisible
	-- behind the alpha mask). Push black for the render, pop back to gray after.
	local _didPushExportBg = false
	if (FnIsArnoldActive()) do (
		FnPushExportBg()
		_didPushExportBg = true
	)

	-- Fix for Arnold Orthographic RegionCrop bug:
	-- MAXtoA scales the orthographic camera incorrectly when rendertype is #regioncrop.
	-- We render the full frame (#region) and safely extract the exact mathematical
	-- renderbox. This preserves all LOD padding and aligns perfectly with Scanline.
	local tempFullGamma = Render \
	renderer:#production \
	rendertype:#region outputwidth:renderwidCP  outputheight:renderhtCP \
	region:#(renderbox.x,renderbox.y,renderbox.right,renderbox.bottom) \

	if (_didPushExportBg) do FnPopExportBg()

	local cropW = renderbox.w as integer
	local cropH = renderbox.h as integer

	tempGamma = bitmap cropW cropH
	pasteBitmap tempFullGamma tempGamma renderbox [0,0]
	
	sourceCP = bitmap tempGamma.width tempGamma.height fileName:(RenfilenameCP + ".tga")
	copy tempGamma sourceCP

	-- ARNOLD CONVERSION: autoadjust is skipped under Arnold (see autoadjust()) --
	-- Arnold frames the ortho view correctly, unlike the MR region-crop which
	-- left a black band at top. autoadjust's upward shift would crop the top off
	-- the correctly-framed Arnold render.

-- checks for the Max (Mental Ray) version and fixes framing problem produced by MR in Max2009+
	sourceCP = autoadjust sourceCP
	save sourceCP


--CP SET BMP INTERFACE FOR 8 BIT SAVE
    bmp.ibmpio.settype #paletted
    AlphaTempCP = bitmap tempGamma.width tempGamma.height filename:(RenfilenameCP + "-a.Bmp") gamma:(1/displayGamma)
    save alphaTempCP

--CP CONVERT FROM TARGA TO BMP
    alphaSplitCP = openbitmap (RenfileAlphaNameCP + ".tga") gamma:1.0
    AlphaCopyCP = copy alphaSplitCP
    copy alphaCopyCP alphaTempCP

--CP SAVE THE ALPHA MAP IN BMP FORMAT
    save alphaTempCP
    close alphaCopyCP
    close alphaSplitCP
	
--CP RETURN BMP INTERFACE TO 24 BIT TRUE COLOR
    bmp.ibmpio.settype #true24
	
--CP NOW CONVERT THE OTHER TARGA TO BMP
    sourceTgaCP = openbitmap (RenfilenameCP + ".tga") gamma:1.0
	outputBmpCP = bitmap renderbox.w renderbox.h filename:(RenfilenameCP + ".Bmp") gamma:(1/displayGamma)
    idxCP = 0
    for idxCP in 0 to (renderbox.h - 1) do
	(
        local PixelRowCP = getPixels sourceTgaCP (point2 0 idxCP) renderbox.w
        setPixels outputBmpCP (point2 0 idxCP) PixelRowCP
	)
	save outputBmpCP
	close sourceTgaCP
	
--CP DELETE THE TGA FILES AS THEY ARE NO LONGER NEEDED
	deleteFile alphaSplitCP.filename
	deleteFile sourceTgaCP.filename
	if (gRenderTypeCP != 1) do
	(
		close SourceCP
		close outputBmpCP
	)

--CP Make directory if any type of night rendering is to be done
	if (gRenderTypeCP != 0) do
	(     --begin of general night rendering if
	 local CurrNightFshDir = (gDestPath + BmpNameCP.NighttextureGUID())
	 local sourceNCP
	 local sourceACP
	 local sourceNLCP
	 DirectoryCheckCP = #()
	 DirectoryCheckCP = getDirectories (CurrNightFshDir + "*")
	 
	if DirectoryCheckCP.count == 0 then
	(     
		makedir CurrNightFshDir
	)
	else
	(
		fndeletefiles (CurrNightFshDir + "\\*.bmp")
		fndeletefiles (CurrNightFshDir + "\\*.png")
		fndeletefiles (CurrNightFshDir + "\\*.fsh")
		fndeletefiles (CurrNightFshDir + "\\*.tga")
	)
	 
	 
	local AlphaRenfileNameCP = CurrNightFshDir + "\\0000"
	
-- CP the following if only night windows, to generate a night-lit scene to place windows onto
	if (gRenderTypeCP == 1) then
	(
		bmp.ibmpio.settype #paletted
		SourceBmpACP = copy alphaTempCP
		bmp.ibmpio.settype #true24
		SourceBmpNCP = copy outputBmpCP
		SourceNCP = copy SourceCP
		SourceACP = copy SourceNCP
		local pixelsA = getpixels SourceBmpACP (point2 0 0) renderbox.w
		for idxPxRow = 0 to (renderbox.h - 1) do
		(
			local pixels = getpixels SourceBmpNCP (point2 0 idxPxRow) renderbox.w
			for idxPxCol = 0 to (renderbox.w - 1) do
			(
				pixels[idxPxCol+1].r = (pixels[idxPxCol+1].r * 0.5)
				pixels[idxPxCol+1].g = (pixels[idxPxCol+1].g * 0.5)
				pixels[idxPxCol+1].b = (pixels[idxPxCol+1].b * 0.75)
			)
			setpixels SourceBmpNCP (point2 0 idxPxRow) Pixels
			setpixels SourceBmpACP (point2 0 idxPxRow) PixelsA
		)
		SourceBmpNCP.filename = (AlphaRenfilenameCP + ".bmp")
		portable_network_graphics.ipngio.settype #gray8
		portable_network_graphics.ipngio.setalpha false
		portable_network_graphics.ipngio.setinterlaced false
		bmp.ibmpio.settype #paletted
		SourceBmpACP.filename = (AlphaRenfilenameCP + "-a.bmp")
		save SourceBmpACP
		local pngbit = copy SourceBmpACP
		pngbit.filename = (AlphaRenfilenameCP + "temp-a.png")
		save pngbit
		close pngbit
		bmp.ibmpio.settype #true24
		SourceBmpNCP.gamma = displayGamma
		save SourceBmpNCP
		close SourceBmpNCP
		close SourceBmpACP
		close alphaTempCP
		close outputBmpCP
		close SourceCP
	)

--cp  the following for nighttime library or nightlight rendering
	if (gRendertypeCP > 1) do
	(
    	if (gRendertypeCP >= 4) do	  --if nighttime library  replace materials now
		(
		loadmateriallibrary gNightLibTempNameCP
			for obj in geometry do
			(
				if (obj.material != undefined) and (currentmateriallibrary[obj.material.name] != undefined) do
				(
					obj.material = currentmateriallibrary[obj.material.name]
				)
			)	
		)	
        local NightRenfileNameCP = CurrNightFshDir + "\\0000"
--print nightrenfilenamecp to:listener
-- CP the following for night lights only

		if ((gRendertypeCP == 2) or (gRendertypeCP == 3) or (gRendertypeCP >= 6)) do 
		(
			-- enable local night lights for nightlight render	
			FnEnableNightLigts true	
		)  --end nightlight setup
			
		--cp reset lighting levels to match maxis night lighting
		local saveLightTintCP = lightTintColor
		local newLightTintCP = lightTintColor
		newLightTintCP.r = newLightTintCP.r * 0.5
		newLightTintCP.g = newLightTintCP.g * 0.5
		newLightTintCP.b = newLightTintCP.b * 0.75
		lightTintColor = newLightTintCP
		-- turn off ambient too
		local saveColor = ambientColor
		ambientColor = (color 0 0 0)
		bmp.ibmpio.settype #true24
--cp		scanlineRender.antialiasfilter = cook_variable()
--cp		scanlineRender.antialiasfilter = Catmull_Rom()
--cp		scanlineRender.antialiasfiltersize = 1.5

		-- ARNOLD CONVERSION: switch to Scanline for this G-Buffer mask pass.
		-- The compositing reads getchannel #objectID/#coverage/... which only
		-- Scanline populates (Arnold does not write the legacy G-Buffer).
		local savedRendererNCP = FnSwapToScanlineForGBuffer()

		if (getmaxversion()<5000) then
		(
			sourceNCP = Render 	outputfile:(NightRenfilenameCP + ".bmp") \
			renderer:#production \
			rendertype:#regioncrop outputwidth:renderwidCP  outputheight:renderhtCP \
			region:#(renderbox.x,renderbox.y,renderbox.right,renderbox.bottom) \
			channels:#(#ObjectID, #coverage, #shaderColor, #shaderTransparency) antialiasfiltersize:1.1
		) else
		(
			sourceNCP = Render 	outputfile:(NightRenfilenameCP + ".bmp") \
			renderer:#production \
			rendertype:#regioncrop outputwidth:renderwidCP  outputheight:renderhtCP \
			region:#(renderbox.x,renderbox.y,renderbox.right,renderbox.bottom) \
			channels:#(#ObjectID, #coverage, #shaderColor, #shaderTransparency) antialiasing:true
		)

		-- ARNOLD CONVERSION: restore Arnold now that the mask pass is rendered.
		FnRestoreRenderer savedRendererNCP



	if ((maxversion())[1])>=11000 do (
	sourceNCP = autoadjust sourceNCP
	)
save sourceNCP
		
		ambientColor 	= saveColor

		if ((gRendertypeCP == 2) or (gRendertypeCP == 3) or (gRendertypeCP == 4) or (gRendertypeCP >= 6)) do 
		(
			-- restore lighting level
			lightTintColor 		= saveLightTintCP
			
		)
	

-- Following is to produce Night Alpha
		if (gRendertypeCP > 1) do         --   or (gRendertypeCP == 3) or (gRendertypeCP >= 6)) do
		(
			loadmateriallibrary gAlphaLibTempNameCP
			for obj in geometry do
			(
				if (obj.material != undefined) and (currentmateriallibrary[obj.material.name] != undefined) do
				(
					obj.material = currentmateriallibrary[obj.material.name]
				)
			)	
			
			-- now we have to disable the xref in order to turn off the daytime lights (scary)
			local xref1 = xrefs.getXRefFile 1
			xref1.disabled = true
			bmp.ibmpio.settype #paletted
			
			portable_network_graphics.ipngio.settype #gray8
			portable_network_graphics.ipngio.setalpha false
			portable_network_graphics.ipngio.setinterlaced false

			-- ARNOLD CONVERSION: switch to Scanline for this G-Buffer mask pass.
			local savedRendererACP = FnSwapToScanlineForGBuffer()

			if (getmaxversion()<5000) then
			(
				sourceACP = Render 	outputfile:(AlphaRenfilenameCP + "temp-a.png") \
				renderer:#production \
				rendertype:#regioncrop outputwidth:renderwidCP  outputheight:renderhtCP \
				region:#(renderbox.x,renderbox.y,renderbox.right,renderbox.bottom) \
				channels:#(#objectID, #coverage, #shaderColor, #shaderTransparency) antialiasfiltersize:1.15
			) else
			(
				sourceACP = Render 	outputfile:(AlphaRenfilenameCP + "temp-a.png") \
				renderer:#production \
				rendertype:#regioncrop outputwidth:renderwidCP  outputheight:renderhtCP \
				region:#(renderbox.x,renderbox.y,renderbox.right,renderbox.bottom) \
				channels:#(#objectID, #coverage, #shaderColor, #shaderTransparency) antialiasing:true
			)

			-- ARNOLD CONVERSION: restore Arnold now that the mask pass is rendered.
			FnRestoreRenderer savedRendererACP

	if ((maxversion())[1])>=11000 do (
	sourceACP = autoadjust sourceACP
	)
save sourceACP
			
			pngbit = openbitmap (AlphaRenfilenameCP + "temp-a.png") gamma:1.0
			bmpcopy = copy pngbit
			bmpcopy.filename = (AlphaRenfilenameCP + "-a.bmp")
			
--the following pushes the alpha towards white. If adjusting formula, adjust in the alpha compositing sections
--below as well.			
			for ih = 0 to ((renderbox.h as integer) - 1) do
			(
				local newpixels = getpixels pngbit (point2 0 ih) renderbox.w
				for iw = 0 to ((renderbox.w as integer) - 1) do
				(
					local colidx = (newpixels[iw+1].v/256)^0.3 * 256
					if (colidx > 0) then
					(
						if (colidx < 255) then
						(
							newpixels[iw+1] = gLumPixels[colidx+1]
						)
						else
						(
							newpixels[iw+1] = gLumPixels[256]
						)
					)
					else
					(
						newpixels[iw+1] = gLumPixels[1]
					)
				)
				setpixels bmpcopy (point2 0 ih) newpixels
			)
			
			save bmpcopy
			close pngbit
			pngbit = copy bmpcopy
			pngbit.filename = (AlphaRenfilenameCP + "temp-a.png")
			save pngbit
			bmp.ibmpio.settype #true24
			close bmpcopy
			close pngbit

			-- restore xref
			xref1.disabled = false
			
			-- restore the current camera
			gCameraRig.RestoreCam()
			
		
		)  --end of nightlight alpha if
		loadmateriallibrary gDayLibTempNameCP
		for obj in geometry do
		(
			if ((obj.material != undefined) and (currentmateriallibrary[obj.material.name] != undefined)) do
			(
				obj.material = currentmateriallibrary[obj.material.name]
			)
		)	

	)  -- end nighttime library or nightlight rendering if

	-- CP the following for night windows
	if ((mod gRenderTypeCP 2.0) == 1.0) do
	(
		--if larger than 256 get window bitmap and tile it into blank bitmap. Save to temp, otherwise simply save to temp
		local tileit = false
		local numRowsCP
		local numColsCP
		local OrigNightTexture
		local TiledNightTexture
	    local NightRenfileNameCP = CurrNightFshDir + "\\0000"
		local NightWinCP = getwindowset()
		local NightWinFile = (getnightwindowfile zoomlevel)[1]
		if (renderBox.h > 257) then 
		(
			-- tile vertically
			numRowsCP 		= ceil ((renderBox.h-1)/256.0)
			tileit = true
		)
		else 
		(
			-- don't need vertical tiling
			numRowsCP = 1
		)
		if (renderBox.w > 257) then 
		(
			numColsCP 		= ceil ((renderBox.w-1)/256.0)
			tileit = true
		)
		else 
		(
			-- don't need horizontal tiling
			numColsCP = 1
		)
		OrigNightTexture = openbitmap nightwinfile gamma:1.0
		if (tileit == true) then
		(
			TiledNightTexture = (bitmap renderbox.w renderbox.h)
			for idxRow = 0 to (numRowsCP - 1) do
			(
				for idxPRow = 0 to 255 do
				(
                    PixelRowCP = getPixels OrigNightTexture (point2 0 idxPRow) 256
					for idxCol = 0 to (numColsCP - 1) do
					(
						setPixels TiledNightTexture (point2 (idxCol * 256) ((idxRow * 256) + idxPRow)) PixelRowCP
					)
				)	
			)
		)
		else
		(
			TiledNightTexture = copy OrigNightTexture
		)
		local OrigNightRender = openbitmap (NightRenFileNameCP + ".bmp") gamma:1.0
		local NewNightRender = copy OrigNightRender
		close OrigNightRender
--take TiledNightTexture pixels and place onto night rendering		
		for ih = 0 to (renderbox.h - 1) do
		(
			local wtpixels = getpixels TiledNightTexture (point2 0 ih) renderbox.w
			local nrpixels = getpixels NewNightRender (point2 0 ih) renderbox.w
			for iw = 0 to (renderbox.w - 1) do
			(
				local stptC = (point2 iw ih)
				local objIDa = (getchannel SourceNCP stptC #objectID)
				local objID = objIDa[1]
				if ((mod objID 10) == 8.0) then
				(
					local cov = ((getchannel SourceNCP stptC #coverage)[1] / 255.0)
					nrpixels[iw+1] = ((wtpixels[iw+1] * cov * 1.06) + (nrpixels[iw+1] * (1.0 - cov)))
				)
				else
				(
					--if more than one objectID layer check if 2nd layer is nightwindow
					if (objIDa.count > 1) do
					(
						local objIDb = objIDa[2]
						if ((mod objIDb 10) == 8.0) do
						(
							local cova = (getchannel SourceNCP stptC #coverage)
							local cov = cova[1]
							local covb = cova[2]
							local colr = (getchannel SourceNCP stptC #shaderColor)
							local transp = (getchannel SourceNCP stptC #shaderTransparency)
							local colra = colr[1]
							local colrb = colr[2]
							local transpa = transp[1]
							local opaca = (255.0 - transpa.v)
							nrpixels[iw+1] = ((colra * (opaca * cov / 65025.0)) + (((65025.0 - (opaca * cov)) / 65025.0) * wtpixels[iw+1])) --temp  + (((255.0 - covb) * (65025.0 - (opaca * cov)) / 16581375.0) * colrb)
						)
					)
				)
			)  --end for loop iw
			setpixels NewNightRender (point2 0 ih) nrpixels
		)  -- end for loop ih
		close OrigNightTexture	
		NewNightRender.filename = (NightRenFileNameCP + ".bmp")
		save NewNightRender
		close NewNightRender
	
	
	)  -- end of night windows only if
	if (((mod gRenderTypeCP 2.0) == 1.0) or (gRendertypeCP >= 4)) do
	(
		--alpha compositing.
		bmp.ibmpio.settype #paletted
		local OrigAlphaMap = openbitmap (AlphaRenfilenameCP + "temp-a.png") gamma:1.0
		local NewAlphaMap = copy OrigAlphaMap
		NewAlphaMap.filename = (AlphaRenFileNameCP + "-a.bmp")
--cp take Systembmp pixels and place one by one onto night alpha rendering	
		--shadertransparency is color value with white (255) being transparent
		--coverage is single number with 255 being full coverage	
		for ih = 0 to (renderbox.h - 1) do
		(
			local origpixels = getpixels OrigAlphaMap (point2 0 ih) renderbox.w
			local newpixels = getpixels NewAlphaMap (point2 0 ih) renderbox.w
			for iw = 0 to (renderbox.w - 1) do
			(
				--objectID, coverage and shadertransparency are always defined, but node can be undefined so check
				local objIDa = (getchannel SourceACP (point2 iw ih) #objectID)
				local objID = objIDa[1]
				local objIDb = objIDa[2]
				if (objIDb == undefined) do
				(
					objIDb = 0
				)
				local objtsta = (mod objID 10)
				local objtstb = (mod objIDb 10)
				
				if not ((objtsta == 8.0) or (objtstb == 8.0)) then
				(
					if not ((objtsta == 5.0) or (objtstb == 5.0)) then
					(
				
						if not (objtsta == 4.0) do
						(
							if ((objtsta == 9.0) or (objtsta == 1.0) or (objtstb == 9.0) or (objtstb == 1.0)) do
							(
								if (objtsta == 9.0) or (objtsta == 1.0) then
								(
									local stpt = (point2 iw ih)
									local cov = (getchannel SourceACP stpt #coverage)
									local covb = (cov[2] / 255.0)
									local transpa = (getchannel SourceACP stpt #shadertransparency)
									local transp = transpa[1]
									local transpc = transp.v
									local colr = (getchannel SourceACP stpt #shaderColor)
									--local colrac = colr[1]
									local colrbc = colr[2]
									--local colra = (colrac.v / 256)^0.3 * 256
									local colrb = (colrbc.v / 256)^0.3 * 256
--use shader colors a and b in order to antialias correctly
									local colidx = ((colrb * covb * transpc / 255.0) as integer)
									if (colidx > 0) then
									(
										if (colidx < 255) then
										(
											newpixels[iw+1] = gLumPixels[colidx+1]
										)
										else
										(
											newpixels[iw+1] = gLumPixels[256]
										)
									)
									else
									(
										newpixels[iw+1] = gLumPixels[1]
									)	
								)
								else
								(
									if (objtstb == 9.0) or (objtstb == 1.0) do
									(
										local stpt = (point2 iw ih)
										local cov = (getchannel SourceACP stpt #coverage)
										local cova = (cov[1] / 255.0)
										local covb = (cov[2] / 255.0)
										local transpa = (getchannel SourceACP stpt #shadertransparency)
										local colr = (getchannel SourceACP stpt #shaderColor)
										local colrac = colr[1]
										local colrbc = colr[2]
										local colra = (colrac.v / 256)^0.3 * 256
										local colrb = (colrbc.v / 256)^0.3 * 256
										local transp = transpa[1]
										local transpb = transpa[2]
										local opac = (255.0 - transp.v)
										local transpbb = transpb.v
										local colidx = (((colra * cova * opac / 255.0) + (colrb * covb * transpbb / 255.0)) as integer)
										if (colidx > 0) then
										(
											if (colidx < 255) then
											(
												newpixels[iw+1] = gLumPixels[colidx+1]
											)
											else
											(
												newpixels[iw+1] = gLumPixels[256]
											)
										)
										else
										(
											newpixels[iw+1] = gLumPixels[1]
										)
									)
								)  -- end of if 9 or 1 first else 9 or 1 second
							)  --end of   if 9 or 1 first or second
						)  --end of   if not 4
					)  --end if not 5 first or second then
					else
					(
						if (objtsta == 5.0) then
						--multiply coverage by (255-transparency.v) by original .v then divide whole thing by 65025 to get amt of change
						(
							local stpt = (point2 iw ih)
							local cov = (getchannel SourceACP stpt #coverage)
							local covb = (cov[2] / 255.0)
							local transpa = (getchannel SourceACP stpt #shadertransparency)
							local transp = transpa[1]
							local transpc = transp.v
							local colr = (getchannel SourceACP stpt #shaderColor)
							--local colrac = colr[1]
							local colrbc = colr[2]
							--local colra = (colrac.v / 256)^0.3 * 256
							local colrb = (colrbc.v / 256)^0.3 * 256
							local colidx = ((colrb * covb * transpc / 255.0) as integer)
							if (colidx > 0) then
							(
								if (colidx < 255) then
								(
									newpixels[iw+1] = gLumPixels[colidx+1]
								)
								else
								(
									newpixels[iw+1] = gLumPixels[256]
								)
							)
							else
							(
								newpixels[iw+1] = gLumPixels[1]
							)	
						)
						else
						(
							if (objtstb == 5.0) do
							--multiply coverage by (255-transparency.v) by original .v then divide whole thing by 65025 to get amt of change
							--
							(
								local stpt = (point2 iw ih)
								local cov = (getchannel SourceACP stpt #coverage)
								local cova = (cov[1] / 255.0)
								local covb = (cov[2] / 255.0)
								local transpa = (getchannel SourceACP stpt #shadertransparency)
								local colr = (getchannel SourceACP stpt #shaderColor)
								local colrac = colr[1]
								local colrbc = colr[2]
								local colra = (colrac.v / 256)^0.3 * 256
								local colrb = (colrbc.v / 256)^0.3 * 256
								local transp = transpa[1]
								local transpb = transpa[2]
								local opac = (255.0 - transp.v)
								local transpbb = transpb.v
								local colidx = (((colra * cova * opac / 255.0) + (colrb * covb * transpbb / 255.0)) as integer)
								if (colidx > 0) then
								(
									if (colidx < 255) then
									(
										newpixels[iw+1] = gLumPixels[colidx+1]
									)
									else
									(
										newpixels[iw+1] = gLumPixels[256]
									)
								)
								else
								(
									newpixels[iw+1] = gLumPixels[1]
								)
							)
						
						)
					
					)  --end of if not 5 or 2nd 5  else
				)
				else
				(
					if (objtsta == 8.0) then
					(
						stpt = (point2 iw ih)
						local cova = (getchannel SourceACP stpt #coverage)
						local cov = cova[1]
						local covb = cova[2]
						local colidx = ((((floor (objID / 10)) + 1) * cov * 0.1) + (origpixels[iw+1].v * (1.0 - (cov / 255.0)))) as integer
						if (colidx > 0) then
						(
							if (colidx < 255) then
							(
								newpixels[iw+1] = gLumPixels[colidx+1]
							)
							else
							(
								newpixels[iw+1] = gLumPixels[256]
							)
						)
						else
						(
							newpixels[iw+1] = gLumPixels[1]
						)
					)
					else  --check below top object for nightwindow at second level
					(
						if (objtstb == 8.0) do
						(
							stpt = (point2 iw ih)
							local cova = (getchannel SourceACP stpt #coverage)
							local cov = cova[1]
							local covb = cova[2]
							local transpa = (getchannel SourceACP stpt #shaderTransparency)
							local transp = transpa[1]
							local colr = (getchannel SourceACP stpt #shaderColor)
							local colrac = colr[1]
							local colrbc = colr[2]
							local colra = (colrac.v / 256)^0.3 * 256
							local colrb = (colrbc.v / 256)^0.3 * 256
							local opaca = (255.0 - transp.v)
							local colidx = ((((opaca * cov / 65025.0) * colra) + ((65025.0 - (opaca * cov)) * (((floor (objIDb / 10.0)) + 1.0) / 2550.0))) as integer)  --temp  + (((255.0 - covb) * (65025.0 - (opaca * cov)) / 16581375.0) * colrb)
							if (colidx > 0) then
							(
								if (colidx < 255) then
								(
									newpixels[iw+1] = gLumPixels[colidx+1]
								)
								else
								(
									newpixels[iw+1] = gLumPixels[256]
								)
							)
							else
							(
								newpixels[iw+1] = gLumPixels[1]
							)
						
						)  --end of if 2nd 8
						
					)   --end of if 8 else
				)   --end of  if not 8 or 2nd 8  else
			)  --end of width for loop
			setpixels NewAlphaMap (point2 0 ih) newpixels
		)   --end of height for loop
		save NewAlphaMap
		close OrigAlphaMap
		close NewAlphaMap
		close SourceACP
		bmp.ibmpio.settype #true24
	)  -- end of night windows or night library if
	
	
	)  -- end of general night lighting if
	
	if tempCamera != undefined then
	(
		delete tempCamera
	)
)

----------------------------------------------------------------------------------------------------
-- Function:	FnCreateModelMaterial 
-- Param:		meshName 
-- Param:		textureFile 
----------------------------------------------------------------------------------------------------
fn FnCreateModelMaterial meshName textureFile = 
(
	local theMaterial = (StandardMaterial diffuse:[128,128,128] )
	
	theMaterial.name = meshName
	theMaterial.diffusemap = (BitmapTexture filename:textureFile filtering:2)
	theMaterial.opacitymap = (BitmapTexture filename:textureFile monoOutput:1)
	showTextureMap theMaterial theMaterial.diffusemap on
	theMaterial.selfIllumAmount = 100.0
	
	return theMaterial
)

----------------------------------------------------------------------------------------------------
-- Function:	FnRenderAndMapSimpleShell
-- Param:		geomNode 
-- Param:		renderBox 
-- Param:		modelFile 
-- Opt Param:	doNight:false
--	N.B.			This is the new implementation
----------------------------------------------------------------------------------------------------
fn FnRenderAndMapSimpleShell geomNode renderBox modelFile doNight:false =
(
	-- Apply mapping to the shell
	FnApplyScreenRegionUVMapping geomNode renderBox 
	update geomNode.mesh
	-- make sure none of the shell nodes show up in our render
	hide geomNode
	hide $LOD*
	hide $TB2*
	
	FnDoRender2 renderBox doNight
--------------------------------        
--SF creates TGI file for labeling and inserting FSH into SC4Model file
    local CurrFshDir = (gDestPath + modelfile.textureoutputGUID())
	local streamTGI = createfile (CurrFshDir + ".fsh.TGI")
	local tempGUIDCP = (modelfile.textureoutputGUID())
	local streamGUIDCP = tempGUIDCP as stringstream
	format "%\n" (readdelimitedstring streamGUIDCP "_") to: streamTGI
	format "%\n" (readdelimitedstring streamGUIDCP "_") to: streamTGI
	format "%\n" (readdelimitedstring streamGUIDCP "_") to: streamTGI
	flush streamTGI
		
----------------------------
	local dayTexName = modelFile.TextureOutputName 0
	local fshPath = gDestPath as stringstream
	local newPath = readChars fshPath (gDestPath.count-1)
	format "%\n" ("fshwrite /b:\"" + CurrFshDir + "\\0000.bmp\" /a:\"" + CurrFshDir + "\\0000-a.bmp\" /outdir:\"" + newPath + "\" /fshname:" + modelfile.textureoutputGUID() +".fsh <cr.txt" ) to:gStreamBATCP
	-- following for traditional night export to delete?
	if (gRenderTypeCP != 0) then 
	(
	    CurrFshDir = (gDestPath + modelfile.NighttextureGUID())
   		streamfshidxCP = createFile (CurrFshDir + "\\index.fsh")
	   	format "%\n" "FSHTool generated file -- be very careful when editing" to: streamfshidxCP
   		format "%\n" (CurrFshDir + ".fsh") to: streamfshidxCP
   		format "%\n" "FSH" to: streamfshidxCP
    	format "%\n" "SHPI 1 objects, tag G264" to: streamfshidxCP
   		format "%\n" ("BUFSZ " + bufsz) to: streamfshidxCP
   		format "%\n" "NOGLOBPAL" to: streamfshidxCP
    	format "%\n" "FISH 0000.BMP" to: streamfshidxCP
   		format "%\n" ("BMP 61 +0 " + (renderbox.w as string) + " " + (renderbox.h as string) + " {0 0 0 0}") to: streamfshidxCP
   		format "%\n" "alpha 0000-a.BMP" to: streamfshidxCP
    	format "%\n" "#END" to: streamfshidxCP
		flush streamfshidxCP

		streamTGI = createfile (CurrFshDir + ".fsh.TGI")
		tempGUIDCP = (modelfile.NighttextureGUID())
		streamGUIDCP = tempGUIDCP as stringstream
		format "%\n" (readdelimitedstring streamGUIDCP "_") to: streamTGI
		format "%\n" (readdelimitedstring streamGUIDCP "_") to: streamTGI
		format "%\n" (readdelimitedstring streamGUIDCP "_") to: streamTGI
		flush streamTGI
	   	format "%\n" ("fshtool.exe " + CurrFshDir + "\\index.fsh <cr.txt") to: gstreamBATCP
	)
		
	
	ok
)

----------------------------------------------------------------------------------------------------
-- Function:	FnRenderAndMapDicedShell
-- Param:		geomNode 
-- Param:		renderBox 
-- Param:		modelFile 
-- Opt Param:	doNight:false
--	N.B.			This is the new implementation
----------------------------------------------------------------------------------------------------
fn FnRenderAndMapDicedShell geomNode renderBox modelFile doNight:false =
(
	local sliceVector, pixelPt
	local baseOffset, slabStep, numRows, numCols
	local coordSysTM 	= gCameraRig.curCam.transform
	local rowNodes 	= #()
	local resultNodes = #()
	local rowIndex
	local colIndex
	local nodeIndex
	local meshIndex
	local curNode
	
	-- geomNodes' mesh must be in world space for the following to work
	if (renderBox.h > 257) then 
	(
		-- we need to dice vertically
		
		numRows 		= ceil ((renderBox.h-1)/256.0)
		sliceVector = -coordSysTM.row2
		normalize sliceVector 
		
		-- setup parameters for MakeSlabs
		pixelPt 		= gCameraRig.GetPixelWorldPoint (point2 renderBox.x renderBox.y) 
		baseOffset 	= dot sliceVector pixelPt
		
		pixelPt 		= gCameraRig.GetPixelWorldPoint (point2 renderBox.x (renderBox.y+256))
		slabStep		= (dot sliceVector pixelPt) - baseOffset 
		
		FnMakeSlabs geomNode numRows sliceVector baseOffset slabStep rowNodes 
	)
	else 
	(
		-- don't need vertical slice, seed rowNodes with node for column slicing
		append rowNodes (copy geomNode)
		numRows = 1
	)
	
	if (renderBox.w > 257) then 
	(
		
		numCols 		= ceil ((renderBox.w-1)/256.0)
		sliceVector = coordSysTM.row1
		normalize sliceVector 
		
		-- setup parameters for MakeSlabs
		pixelPt 		= gCameraRig.GetPixelWorldPoint (point2 renderBox.x renderBox.y) -- we just need the point part of the ray actually, but this is a handy routine
		baseOffset 	= dot sliceVector pixelPt
		
		pixelPt 		= gCameraRig.GetPixelWorldPoint (point2 (renderBox.x+256) renderBox.y)
		slabStep 	= (dot sliceVector pixelPt) - baseOffset 
		
		--format "baseOffset : % slabStep %\n" baseOffset slabStep to:debugStream
		
		for rowIndex in 1 to rowNodes.count do 
		(
			FnMakeSlabs rowNodes[rowIndex]  numCols sliceVector baseOffset slabStep resultNodes 
		)
		
		delete rowNodes 
	)
	else 
	(
		-- don't need horizontal slice copy result from rows
		resultNodes = rowNodes
		numCols = 1
	)
	
	-- make sure none of the shell nodes show up in our render
	hide resultNodes
	hide geomNode
	hide $LOD*
	hide $TB2*
	
	-- generate source bitmap for dicing
	
	FnDoRender2 renderBox doNight
-------------------------------------	
--CP  COPY RENDERED IMAGES TO NEW TEMPORARY FILES AS THEY WILL BE OVERWRITTEN	
	local CurrNightFshDir = (gDestPath + modelfile.NighttextureGUID())
	local CurrFshDir = (gDestPath + modelfile.textureoutputGUID())
	local SourceBmpNameCP = CurrFshDir + "\\0000.Bmp"
    local SourceAlphaNameCP = CurrFshDir + "\\0000-a.Bmp"
	local TempBmpNameCP = modelfile.rendertempname()
	local TempAlphaNameCP = modelfile.rendertempalphaname()
	local SourceNightBmpNameCP = CurrNightFshDir + "\\0000.Bmp"
    local SourceNightAlphaNameCP = CurrNightFshDir + "\\0000-a.Bmp"
	local TempNightBmpNameCP = modelfile.nightrendertempname()
	local TempNightAlphaNameCP = modelfile.nightalphatempname()
	local TempNightBmpCP
	local TempNightAlphaCP
	if (getfiles SourceBmpNameCP).count != 0 then
	(
	    if (getfiles TempBmpNameCP).count != 0 do
		(
		    deleteFile TempBmpNameCP
		)
		copyFile SourceBmpNameCP TempBmpNameCP
	)
	else
	(
		local errorMsg = ("Couldn't find " + SourceBmpNameCP)
		FnErrorMessage errorMsg
		throw errorMsg	
	)
	if (getfiles SourceAlphaNameCP).count != 0 then
	(
	    if (getfiles TempAlphaNameCP).count != 0 do
		(
		    deleteFile TempAlphaNameCP
		)
		copyFile SourceAlphaNameCP TempAlphaNameCP
	)
	else
	(
		local errorMsg = ("Couldn't find " + SourceAlphaNameCP)
		FnErrorMessage errorMsg
		throw errorMsg	
	)

	local TempBmpCP = openBitmap SourceBmpNameCP gamma:1.0
    bmp.ibmpio.settype #paletted
	local TempAlphaCP = openBitmap SourceAlphaNameCP gamma:1.0
    bmp.ibmpio.settype #true24

	
	
	
	if (gRenderTypeCP != 0) do 
	(
		if (getfiles SourceNightBmpNameCP).count != 0 then
		(
	    	if (getfiles TempNightBmpNameCP).count != 0 do
			(
			    deleteFile TempNightBmpNameCP
			)
			copyFile SourceNightBmpNameCP TempNightBmpNameCP
		)
		else
		(
			local errorMsg = ("Couldn't find " + SourceNightBmpNameCP)
			FnErrorMessage errorMsg
			throw errorMsg	
		)
		if (getfiles SourceNightAlphaNameCP).count != 0 then
		(
		    if (getfiles TempNightAlphaNameCP).count != 0 do
			(
			    deleteFile TempNightAlphaNameCP
			)
			copyFile SourceNightAlphaNameCP TempNightAlphaNameCP
		)
		else
		(
			local errorMsg = ("Couldn't find " + SourceNightAlphaNameCP)
			FnErrorMessage errorMsg
			throw errorMsg	
		)
		
		TempNightBmpCP = openBitmap SourceNightBmpNameCP gamma:1.0
    	bmp.ibmpio.settype #paletted
		TempNightAlphaCP = openBitmap SourceNightAlphaNameCP gamma:1.0
    	bmp.ibmpio.settype #true24
		
	)
--------------------------------------	
	nodeIndex = 1 -- current index in result array
	meshIndex = 0 -- index of valid output mesh (skips empty meshes in resultNodes)
	
	for rowIndex in 1 to numRows do 
	(
		for colIndex in 1 to numCols do 
		(
			curNode = resultNodes[nodeIndex]
			
			if ((curNode.mesh.numVerts > 0) and (curNode.mesh.numFaces > 0)) do 
			(
				FnApplyDicedRegionUVMapping curNode renderBox 
				local texFilename = modelFile.TextureOutputName meshIndex
				print texFilename
				print (modelFile.TextureOutputGUID texIndex:meshIndex as string)
				
				local cropBox = Box2 ((colIndex-1)*256) ((rowIndex-1)*256) 256 256
----------------------------------------------------------------------
--CP  DO DICING OF DAYTIME RENDER HERE
--cp               portable_network_graphics.ipngio.settype #gray8
				 local CurrFshSliceDir = (gDestPath + modelfile.TextureOutputGUID texIndex:meshIndex as string)
			     local DirectorySlCheckCP = #()
				 DirectorySlCheckCP = getDirectories (CurrFshSliceDir + "*")

				if DirectorySlCheckCP.count == 0 then
				(     
					makedir CurrFshSliceDir
				)
				else
				(
					fndeletefiles (CurrFshSliceDir + "\\*.bmp")
					fndeletefiles (CurrFshSliceDir + "\\*.png")
					fndeletefiles (CurrFshSliceDir + "\\*.fsh")
					fndeletefiles (CurrFshSliceDir + "\\*.tga")
				)

		        local NewBmpCP = bitmap 256 256 filename:(CurrFshSliceDir + "\\0000.Bmp") color:black gamma:(1/displayGamma)
--CP set bmp interface for 8-bit			   
				bmp.ibmpio.settype #paletted
				NewAlphaCP = bitmap 256 256 filename:(CurrFshSliceDir + "\\0000-a.Bmp") color:black gamma:(1/displayGamma)
				local idxCP = 0
                bmp.ibmpio.settype #true24
--save 256x256 portion of rendered pic using cropbox.x and cropbox.y as beginning corners
                 for idxCP in 0 to 255 do
				(
                    PixelRowCP = getPixels TempBmpCP (point2 cropbox.x (cropbox.y + idxCP)) 256
                    setPixels NewBmpCP (point2 0 idxCP) PixelRowCP
                    PixelAlphaCP = getPixels TempAlphaCP (point2 cropbox.x (cropbox.y + idxCP)) 256
                    setPixels NewAlphaCP (point2 0 idxCP) PixelAlphaCP
				)
                save NewBmpCP
				close NewBmpCP
                bmp.ibmpio.settype #paletted
				save NewAlphaCP
				close NewAlphaCP
                bmp.ibmpio.settype #true24
       	    	--format "%\n" ("fshtool.exe " + CurrFshSliceDir + "\\index.fsh <cr.txt") to: gstreamBATCP
				local fshPath = gDestPath as stringstream
				local newPath = readChars fshPath (gDestPath.count-1)
				format "%\n" ("fshwrite /b:\"" + CurrFSHSliceDir + "\\0000.bmp\" /a:\"" + CurrFSHSliceDir + "\\0000-a.bmp\" /outdir:\"" + newPath + "\" /fshname:" + (modelfile.textureoutputGUID texIndex:meshIndex as string) +".fsh <cr.txt" ) to:gStreamBATCP
			   	/*local streamfshidxCP = createFile (CurrFshSliceDir + "\\index.fsh")
    			format "%\n" "FSHTool generated file -- be very careful when editing" to: streamfshidxCP
    			format "%\n" (CurrFshSliceDir + ".fsh") to: streamfshidxCP
	    		format "%\n" "FSH" to: streamfshidxCP
	    		format "%\n" "SHPI 1 objects, tag G264" to: streamfshidxCP
    			format "%\n" "BUFSZ 262304" to: streamfshidxCP
	    		format "%\n" "NOGLOBPAL" to: streamfshidxCP
    			format "%\n" "FISH 0000.BMP" to: streamfshidxCP
	    		format "%\n" "BMP 61 +0 256 256 {0 0 0 0}" to: streamfshidxCP
		    	format "%\n" "alpha 0000-a.BMP" to: streamfshidxCP
    			format "%\n" "#END" to: streamfshidxCP
				flush streamfshidxCP*/
				local streamTGI = createfile (CurrFshSliceDir + ".fsh.TGI")
				local tempGUIDCP = (modelfile.TextureOutputGUID texIndex:meshIndex as string)
				local streamGUIDCP = tempGUIDCP as stringstream
				format "%\n" (readdelimitedstring streamGUIDCP "_") to: streamTGI
				format "%\n" (readdelimitedstring streamGUIDCP "_") to: streamTGI
				format "%\n" (readdelimitedstring streamGUIDCP "_") to: streamTGI
				flush streamTGI
-----------------------------------------------------------------------				
				
				if (gRenderTypeCP != 0) do 
				(
					-- do it again for the night mask
					 local CurrNFshSliceDir = (gDestPath + modelfile.NighttextureGUID texIndex:meshIndex as string)
				     local DirectoryNSlCheckCP = #()
					 DirectoryNSlCheckCP = getDirectories (CurrNFshSliceDir + "*")
					 if DirectoryNSlCheckCP.count == 0 do
					if DirectoryNSlCheckCP.count == 0 then
					(     
						makedir CurrNFshSliceDir
					)
					else
					(
						fndeletefiles (CurrNFshSliceDir + "\\*.bmp")
						fndeletefiles (CurrNFshSliceDir + "\\*.png")
						fndeletefiles (CurrNFshSliceDir + "\\*.fsh")
						fndeletefiles (CurrNFshSliceDir + "\\*.tga")
					)
					 
					local NightBmpCP = bitmap 256 256 filename:(CurrNFshSliceDir + "\\0000.Bmp") color:black gamma:(1/displayGamma)
					bmp.ibmpio.settype #paletted
					local NightAlphaCP = getchannelasmask AlphaRenSliceCP #node filename:(CurrNFshSliceDir + "\\0000-a.Bmp")
	   				
					
	                local idxCP = 0
					save NightAlphaCP
					bmp.ibmpio.settype #true24
					for idxCP in 0 to 255 do
					(
	                    PixelRowCP = getPixels TempNightBmpCP (point2 cropbox.x (cropbox.y + idxCP)) 256
    	                setPixels NightBmpCP (point2 0 idxCP) PixelRowCP
        	            PixelAlphaCP = getPixels TempNightAlphaCP (point2 cropbox.x (cropbox.y + idxCP)) 256
            	        setPixels NightAlphaCP (point2 0 idxCP) PixelAlphaCP
					)
					save NightBmpCP
					close NightBmpCP
        	        bmp.ibmpio.settype #paletted
					save NightAlphaCP
					close NightAlphaCP
	                bmp.ibmpio.settype #true24
					format "%\n" ("fshwrite /b:\"" + CurrFSHSliceDir + "\\0000.bmp\" /a:\"" + CurrNFshSliceDir  + "\\0000-a.bmp\" /outdir:\"" + newPath + "\" /fshname:" + (modelfile.textureoutputGUID texIndex:meshIndex as string) +".fsh <cr.txt" ) to:gStreamBATCP
					/*streamfshidxCP = createFile (CurrNFshSliceDir + "\\index.fsh")
			    	format "%\n" "FSHTool generated file -- be very careful when editing" to: streamfshidxCP
    				format "%\n" (CurrNFshSliceDir + ".fsh") to: streamfshidxCP
		    		format "%\n" "FSH" to: streamfshidxCP
	    			format "%\n" "SHPI 1 objects, tag G264" to: streamfshidxCP
		    		format "%\n" "BUFSZ 262304" to: streamfshidxCP
    				format "%\n" "NOGLOBPAL" to: streamfshidxCP
			    	format "%\n" "FISH 0000.BMP" to: streamfshidxCP
    				format "%\n" "BMP 61 +0 256 256 {0 0 0 0}" to: streamfshidxCP
		    		format "%\n" "alpha 0000-a.BMP" to: streamfshidxCP
	    			format "%\n" "#END" to: streamfshidxCP
					flush streamfshidxCP*/
					streamTGI = createfile (CurrNFshSliceDir + ".fsh.TGI")
					tempGUIDCP = (modelfile.NighttextureGUID texIndex:meshIndex as string)
					streamGUIDCPN = tempGUIDCP as stringstream
					format "%\n" (readdelimitedstring streamGUIDCPN "_") to: streamTGI
					format "%\n" (readdelimitedstring streamGUIDCPN "_") to: streamTGI
					format "%\n" (readdelimitedstring streamGUIDCPN "_") to: streamTGI
					flush streamTGI
				   /*	format "%\n" ("fshtool.exe " + CurrNFshSliceDir + "\\index.fsh <cr.txt") to: gstreamBATCP*/

				)
				
				meshIndex += 1
			)
			
			nodeIndex += 1
		)
	)
---------------------------
--CP DELETE THE TEMPORARY UNDICED RENDER FILES
	deleteFile tempBmpNameCP
	deleteFile tempAlphaNameCP
--------------------------- 	
	-- almost there, now go through result nodes and clear out any empty meshes
	for nodeIndex in resultNodes.count to 1 by -1 do 
	(
		curNode = resultNodes[nodeIndex]
		if ((curNode.mesh.numVerts == 0) or (curNode.mesh.numFaces == 0)) do 
		(
			--fnErrorMessage ("Deleting: " + curNode.name)
			deleteItem resultNodes nodeIndex
			
			delete curNode
		)
	)

	return resultNodes 
)

---------------------------------------------------------------------------------------------------
-- Function:	FnCreateLowPolyShell 																					
-- Param:		lodShell 	- Artist created low poly shell														
-- Param:		modelFile 	- stModelName struct to generate filenames										
-- Opt Param:	doNight:false																								
-- Desc:			Creates and returns shell geometry node appropriate for export to S3D format			
---------------------------------------------------------------------------------------------------
fn FnCreateLowPolyShell lodShell modelFile doNight:false =
(
	-- make a copy of the supplied LOD shell because we are going to mangle it
	-- to make a view dependant version of it
	local geomNode = copy lodShell 
	-- make sure building meshes are visible
	-- max unhide all 

	-- give this mesh a unique name so it doesn't get confused with others
	geomNode.name = uniqueName "TB2_ShellTemp"
	-- make sure it's an editmesh so modifications below can work
	convertToMesh geomNode
	-- make sure that the geometry is in world space so mods below can work
	FnMeshLocalToWorld geomNode
	-- remove backfaces 
	FnRemoveBackFaces geomNode (gCameraRig.GetViewDir()) 
	-- get the screen bounds of the shell that is nice texture size
	local renderBox = gCameraRig.GetCamRenderRegion geomNode
	-- is this a simple case, or do we need to dice
	if ((renderBox.h <=256) and (renderBox.w <= 256)) then 
	(
		FnRenderAndMapSimpleShell geomNode renderBox modelFile doNight:doNight
		
		-- unhide geomNode
		
		return geomNode
	)
	-- It's big, dice & return group
	else
	(
		
		local dicedNodes = FnRenderAndMapDicedShell geomNode renderBox modelFile doNight:doNight
		
		if (dicedNodes.count > 1) then 
		(
			local modelGroup
			
			delete geomNode
			-- unhide dicedNodes
			
			modelGroup = group dicedNodes prefix:"TB2_ShellGroup"
			
			return modelGroup
		)
		else 
		(
			if (dicedNodes.count == 1) then 
			(
				return dicedNodes[1]
			)
			else 
			(
				FnErrorMessage "Error: nothing left after Dice and Render. This is a script bug."
				return undefined
			)
		)
	)
)

----------------------------------------------------------------------------------------------------
-- Function:	FnGetFrameFromZoomRot 
-- Param:		zoom
-- Param:		rot
----------------------------------------------------------------------------------------------------
fn FnGetFrameFromZoomRot zoom rot = 
(
	if ((zoom>0) and (zoom <= 5) and (rot > 0) and (rot <= 4)) then
	(
		return (5-zoom)*4 + (rot-1)
	)
	else
	(
		return -1 -- error case
	)
)

----------------------------------------------------------------------------------------------------
-- Function:	FnGetZoomFromFrame 
-- Param:		frame
----------------------------------------------------------------------------------------------------
fn FnGetZoomFromFrame frame = 
(
	if ((frame >= 0) and (frame <= 19)) then
	(
		return 5 - ((frame as integer) / 4)
	)
	else
	(
		return -1
	)
)

----------------------------------------------------------------------------------------------------
-- Function:	FnGetRotFromFrame 
-- Param:		frame
----------------------------------------------------------------------------------------------------
fn FnGetRotFromFrame frame = 
(
	if ((frame >= 0) and (frame <= 19)) then
	(
		return 1 + ((mod frame 4) as integer)
	)
	else
	(
		return -1
	)
)

----------------------------------------------------------------------------------------------------
-- Function:	FnMatHasEffectChan 
-- Param:		mtrl 
-- Param:		matID 
--	gmax:			gmax does not support material effect chanels
----------------------------------------------------------------------------------------------------
fn FnMatHasEffectChan mtrl matID = 
(
--CP /*
	-- multimaterials
	if ((mtrl.classID[1] == kMultiMatClass1) and (mtrl.classID[2] == kMultiMatClass2)) then 
	(
		local submtrl
		
		for submtrl in mtrl.materialList do 
		(
			-- recurse because these could be multimats too
			if (FnMatHasEffectChan submtrl matID) do
			(
				return true
			)
		)
	)
	-- regular material
	else 
	(
		if (mtrl.effectsChannel == matID) do 
		(
			return true
		)
	)
--CP */
--CP	false
)

----------------------------------------------------------------------------------------------------
-- Function:	FnSceneHasNightMats 
--	gmax:			gmax does not support material effect chanels
----------------------------------------------------------------------------------------------------
fn FnSceneHasNightMats = 
(
	return $*night*.count + $*nite*.count > 0
)

----------------------------------------------------------------------------------------------------
-- Function:	FnGetNodesToSave 
----------------------------------------------------------------------------------------------------
fn FnGetNodesToSave = 
(
	local nodesToSave = #()
	
	for node in rootNode.children do 
	(
		local object = node.baseObject
		if (superclassOf object == helper and  classOf object == point) then 
		(
			append nodesToSave node
		) 
	)
	
	return nodesToSave 
)
----------------------------------------------------------------------------------------------------
-- Function:	FnFindLOD 
----------------------------------------------------------------------------------------------------
fn FnFindLOD level = 
(
	local lodFound
	case level of
	(
		1:	lodFound= $LOD1
		2:	lodFound= $LOD2
		3:	lodFound= $LOD3
		4:	lodFound= $LOD4
		5:	lodFound= $LOD5
	)	
	return lodFound
)

----------------------------------------------------------------------------------------------------
-- Function:	FnCreateLOD 
----------------------------------------------------------------------------------------------------
fn FnCreateLOD level ask:true = 
(
	local curLOD
	local lodName = "LOD" + (level as string)
	
	case level of
	(
		3:	curLOD = $LOD3
		4:	curLOD = $LOD4
		5:	curLOD = $LOD5
		default: return undefined
	)
	
	if (curLOD == undefined) then
	(
		curLOD = FnCreateSceneBoundingBox name:lodName
		return curLOD 
	)
	
	local replaceLOD = true
	
	if ask then
	(
		replaceLOD = queryBox  (lodName + " already exists.\nReplace?")
	)
	
	if replaceLOD then
	(
		delete curLOD
		curLOD = FnCreateSceneBoundingBox name:lodName 
	)
	
	return curLOD
)
----------------------------------------------------------------------------------------------------
-- added Functiuon to set LOD layer
----------------------------------------------------------------------------------------------------
fn LODlayerSetter = (
local LODs_Layer = layerManager.getLayerFromName "LODs 3-5"

	if	LODs_Layer != undefined then
		(
			LODs_Layer.current =true
		)
	else 
		(
			LODs_Layer = LayerManager.newLayerFromName "LODs 3-5"
			LODs_Layer.current =true
		)
)



----------------------------------------------------------------------------------------------------
-- Function:	FnCreateLOD_3_4_5 
----------------------------------------------------------------------------------------------------
fn FnCreateLOD_3_4_5 = 
(
	if geometry.count == 0 then
	(
		return false
	)
	
	LODlayerSetter()
	
	if ($LOD3 == undefined) then
	(
		FnCreateSceneBoundingBox name:"LOD3"
		local lod3 = $LOD3
		lod3.isHidden = true
	)
	if ($LOD4 == undefined) then
	(
		local lod4 = copy $LOD3
		lod4.name = "LOD4"
		lod4.isHidden = true
	)
	if ($LOD5 == undefined) then
	(
		local lod5 = copy $LOD3
		lod5.name = "LOD5"
		lod5.isHidden = true
	)
	(LayerManager.getLayer 0).current = true
	return true
)

----------------------------------------------------------------------------------------------------
-- Function:	FnGetLODNodes 
----------------------------------------------------------------------------------------------------
fn FnGetLODNodes &lods = 
(
	FnCreateLOD_3_4_5()
	
	local tempLOD1
	local tempLOD2
	
	-- creat a box that is the bounds of the LOD3 shell to use as the shell for lod 1 & 2
	
	tempLOD1 = box width:($LOD3.max.x - $LOD3.min.x) length:($LOD3.max.y - $LOD3.min.y) height:($LOD3.max.z - $LOD3.min.z) 
	tempLOD1.position.x += $LOD3.min.x - tempLOD1.min.x
	tempLOD1.position.y += $LOD3.min.y - tempLOD1.min.y
	tempLOD1.position.z += $LOD3.min.z - tempLOD1.min.z
	tempLOD1.name = "TB2_TempLOD1_Box"
	
	tempLOD2 = box width:($LOD3.max.x - $LOD3.min.x) length:($LOD3.max.y - $LOD3.min.y) height:($LOD3.max.z - $LOD3.min.z) 
	tempLOD2.position.x += $LOD3.min.x - tempLOD2.min.x
	tempLOD2.position.y += $LOD3.min.y - tempLOD2.min.y
	tempLOD2.position.z += $LOD3.min.z - tempLOD2.min.z
	tempLOD2.name = "TB2_TempLOD2_Box"
	
	lods = #($TB2_TempLOD1_Box, $TB2_TempLOD2_Box, $LOD3, $LOD4, $LOD5)
	
	-- need to make sure that all the shells are there
	
	return true 
)

----------------------------------------------------------------------------------------------------
-- Function:	FnCleanupDestFolder 
-- Param:		destpath	- destination folder
-- Desc:			Deletes all temporary files left from the previous export
----------------------------------------------------------------------------------------------------
fn FnCleanupDestFolder destpath = 
(
	FnDeleteFiles (destpath + "*.fsh")
	FnDeleteFiles (destpath + "*.TGI")
	FnDeleteFiles (destpath + "*.bmp")
)


----------------------------------------------------------------------------------------------------
-- CP added the following function
-- Function:	FnSetRenTypeCP     Sets the render type to control what types of night rendering are performed
-- Param:		 
----------------------------------------------------------------------------------------------------
fn FnSetRenTypeCP =
(
	if ($lights.count > 0) do 	-- scene has local night lights
	(
		local nightcountCP = 0
		for lt in $lights do 
		(
			-- $lights collection includes targets & targets don't have 'enabled' member
			if (lt.classID[1] != 4128) do 
			(
				local namePrefix = (substring lt.name 1 8)
				
				if (namePrefix == "nightlight") then
				(
					nightcountCP +=1
				)
			)
		)
		if nightcountCP != 0 do
		(
			gRendertypeCP += 2
		)

	)
)


----------------------------------------------------------------------------------------------------
-- Function:	FnExportAllZoomsAndRotations
-- Param:		destpath	- destination folder
-- Desc:		Exports all 20 low poly models.
----------------------------------------------------------------------------------------------------
fn FnExportAllZoomsAndRotations destpath = 
(
	if geometry.count == 0 then
	(
		messageBox "Nothing to export. The scene is empty"
		return false
	)

	
	local startTime 		= timeStamp()
	local modelName 	= stModelName()
	local thisModelType = #Building
	local bHasNightMats = FnSceneHasNightMats() or ($nightlight*.count>0) -- don't process the night mask if there isn't one
	local nodesToSave	= FnGetNodesToSave()
	local	success 		= 0					-- used for debugging
	
	local numOfSteps	= 23				--	one for each view + one for thumbnails + one for initialization
	local curStep			= 0
	local datName


	if (gAutoexecute) then 
	(
		--executedeletetree()
		makedir destpath
	)


	FnSetRenTypeCP()


	try
	(
		setWaitCursor()
		progressStart "Exporting..."
		curStep += 1
		progressUpdate (100*curStep/numOfSteps)

		--	Check Camera
		
		if not gCameraRig.CheckCameras() then
		(
			local errorMsg = "Failed to set cameras!"
			messageBox errorMsg
			throw errorMsg
		)
		
		if not gCameraRig.ResetRig() then
		(
			local errorMsg = "Failed to reset cameras!"
			messageBox errorMsg
			throw errorMsg
		)
	
		-- Init a modelname structure
		if (not modelName.Init maxfilename destpath modelType:thisModelType) do 
		(
			local errorMsg = "Model name structure failed to initialize!"
			messageBox errorMsg
			throw errorMsg
		)
		
		success += 1
		-- Delete oldfiles in temp folder
		FnDeleteFiles ((modelName.Destination which:#temp) + "*.*")
		-- Clean up destination folder
		FnCleanupDestFolder destpath
		-- Delete any dangling temp meshes that might have been created before
		delete $TB2_*
		success += 1
--CP Get drive letter  Create and Initialize bat file Then add temporary light
--------------------------------        

		Currdriveletter as string
    	Currdriveletter = (getDir #maxroot) + "gamepacks\\bat"
		if ((getFiles (Currdriveletter + "\\" + (getfilenamefile gSC4ModelName) + ".bat")).count != 0) then
		(
			deleteFile (Currdriveletter + "\\" + (getfilenamefile gSC4ModelName) + ".bat")
		)
   		gstreamBATCP = createFile (Currdriveletter + "\\" + (getfilenamefile gSC4ModelName) + ".bat")
		Currdriveletterd = substring Currdriveletter 1 2
		Currdriveletter = substring Currdriveletter 4 -1

		format "%\n" "cd\\" to: gstreamBATCP
		format "%\n" Currdriveletterd to: gstreamBATCP
		format "%\n" ("cd\\" + Currdriveletter) to: gstreamBATCP
		templightcp = freespot name:"CPdeleteSpot" position:[-100.0,-200.0,300.0] value:1
		in coordsys world rotate templightcp (quat -1.0 0.0 0.0 30.0)
		curStep += 1
		if not (progressUpdate (100*curStep/numOfSteps)) then
		(
			success = -2
			throw "Cancelled by user"
		)
		if  (getfiles ((getDir #maxroot) + "gamepacks\\bat" + "\\System.bmp")).count != 0 then
		(
			systembmp = openbitmap ((getDir #maxroot) + "gamepacks\\bat" + "\\System.bmp") gamma:1.0
			gLumPixels = getpixels systembmp (point2 0 0) 256
			close systembmp
		)
		else
		(
			success = -2
			throw "System.bmp file missing from BAT directory"
		)
		if (gRendertypeCP > 1) do 
		(
			
			local matcnt
			numofsteps += 1
--CP this for Library render and nightlight (night render will use the same library as day)
			if (savemateriallibrary gDayLibTempNameCP) then
			(
				matcnt = scenematerials.count
				loadmateriallibrary gDayLibTempNameCP
				local libcnt = currentmateriallibrary.count
				for lidx = libcnt to 1 by -1 do
				(
					deleteitem currentmateriallibrary lidx
				)
				local idx
				for idx = 1 to matcnt do
				(
					append currentmateriallibrary scenematerials[idx]
				)
				savemateriallibrary gDayLibTempNameCP
			)
			else
			(
				print "Cant save material library. Nightlights and material libraries will not be used." to:listener
				if ((mod gRenderTypeCP 2.0) == 1.0) then
				(
					gRendertypeCP = 1
				)
				else
				(
					gRenderTypeCP = 0
				)
			)
			curStep += 1
			if not (progressUpdate (100*curStep/numOfSteps)) then
			(
				success = -2
				throw "Cancelled by user"
			)
--CP This will only be necessary with library render.  Save temp night library and build the alpha library.
			if (gRendertypeCP >= 4) and (savemateriallibrary gNightLibTempNameCP) and (loadmateriallibrary gNightLibNameCP) then
			(
				savemateriallibrary gNightLibTempNameCP
				loadmateriallibrary gNightLibTempNameCP
				matcnt = scenematerials.count
				local libcnt = currentmateriallibrary.count
				for lidx = libcnt to 1 by -1 do
				(
					if (scenematerials[currentmateriallibrary[lidx].name] == undefined) do
					(
						deleteitem currentmateriallibrary lidx
					)
				)
				for idx = 1 to matcnt do
				(
					if (currentmateriallibrary[scenematerials[idx].name] == undefined) do
					(	
						append currentmateriallibrary scenematerials[idx]
					)
				)
				savemateriallibrary gNightLibTempNameCP
			)
			if (savemateriallibrary gAlphaLibTempNameCP) then
			(
				loadmateriallibrary gAlphaLibTempNameCP
				local idx
				libcnt = currentmateriallibrary.count
				numofsteps += 1
				curStep += 1
				if not (progressUpdate (100*curStep/numOfSteps)) then
				(
					success = -2
					throw "Cancelled by user"
				)
				
				for idx = 1 to libcnt do

				(
					local mattoappend
--CP  multimaterials will crash the render here so avoid
					if ((currentmateriallibrary[idx].classID[1] != 512) and (currentmateriallibrary[idx].classID[1] != 592)) then
					(
						if (currentmateriallibrary[idx].classID[1] == 2) do
						(
							currentmateriallibrary[idx].adlock = false
							currentmateriallibrary[idx].diffuse = (color 255.0 255.0 255.0)
							currentmateriallibrary[idx].specular = (color 255.0 255.0 255.0)
							currentmateriallibrary[idx].ambient = (color 0.0 0.0 0.0)
							currentmateriallibrary[idx].specularlevel = 0.0
							currentmateriallibrary[idx].glossiness = 0.0
							currentmateriallibrary[idx].diffusemapenable = false
							currentmateriallibrary[idx].glossinessmapenable = false
							currentmateriallibrary[idx].displacementmapenable = false
							currentmateriallibrary[idx].reflectionmapenable = false
							currentmateriallibrary[idx].refractionmapenable = false

							if not (currentmateriallibrary[idx].shadertype >= 6) do
							(
								currentmateriallibrary[idx].specularlevelmapenable = false
								currentmateriallibrary[idx].specularmapenable = false
								currentmateriallibrary[idx].ambientmapenable = false
								local siname = (substring currentmateriallibrary[idx].name 1 4)
								if (gRenderTypeCP >= 4) and ((matchpattern siname pattern: "win*") or (matchpattern siname pattern: "doo*") or (matchpattern siname pattern: "gar*") or (matchpattern siname pattern: "neo*")) then 
								(
									currentmateriallibrary[idx].selfillummapenable = true
								)
								else
								(
									currentmateriallibrary[idx].selfillummapenable = false
									currentmateriallibrary[idx].selfillumamount = 0.0
								)
							)
					
						)
					
					)
					else    --multimaterial or blend.  if multimaterial itself contains multimaterial, tough luck
					(
						bogus = 0
					)  -- end of if and else
				)   -- end of for loop
				savemateriallibrary gAlphaLibTempNameCP
				loadmateriallibrary gDayLibTempNameCP
				for obj in geometry do
				(
					if (obj.material != undefined) and (currentmateriallibrary[obj.material.name] != undefined) do
					(
						obj.material = currentmateriallibrary[obj.material.name]
					)
				)	

			)
			else
			(
				print "Cant save material library. Nightlights and material libraries will not be used." to:listener
				if ((mod gRenderTypeCP 2.0) == 1.0) then
				(
					gRendertypeCP = 1
				)
				else
				(
					gRenderTypeCP = 0
				)
			)
		)
		gmatscount = scenematerials.count
----------------------------
		-- Get or create the lod shells
		local lodNodes = #()

		if not FnGetLODNodes &lodNodes then
		(
			local errorMsg = "Failed to find/create lods!"
			messageBox errorMsg
			throw errorMsg
		)
		success += 1
		success += 1
		
		-- Thumbnails
		curStep += 1
		if not (progressUpdate (100*curStep/numOfSteps)) then
		(
			success = -2
			throw "Cancelled by user"
		)
		
		success += 1
	
		success += 1
		-- Create and export all LOD shells
		local zoom
		for zoom = 5 to 1 by -1 do 
		(
			local curShell = lodNodes[zoom] -- get lodNode for current zoom
			local rot
			modelName.zoom = zoom

			for rot = 1 to 4 do 
			(
				curStep += 1
				if not (progressUpdate (100*curStep/numOfSteps)) then
				(
					success = -2
					throw "Cancelled by user"
				)

				modelName.rot = rot
				-- We use a global object to pass view information to subroutines
				gCameraRig.SetCam zoom rot updateViewport:true
				gCameraRig.SetupRenderViewport curShell

				local shellNode = FnCreateLowPolyShell curShell modelName doNight:bHasNightMats
				if (shellNode == undefined) then 		-- Create shell may fail
				(
					local errorMsg = ("Failed to create low poly shell!\n" + (FnZoomRotInfoString zoom rot))
					messageBox errorMsg
					throw errorMsg
				)
				
				success += 1
				
				success += 1
			)
		)
		success = -1
	)
	catch
	(
		-- ARNOLD CONVERSION: the original code swallowed the real exception and
		-- just printed "Error Occurred Somewhere", producing a misleading
		-- "Export failed! Code = N" with no detail. For diagnosis we use a bare
		-- 'throw' (the only form permitted in a catch block) to re-raise, so
		-- MAXScript prints its full native error report -- with file/position/line
		-- and the complete call stack -- to the Listener. That is the only way to
		-- see WHICH line actually failed.
		format "Export threw at success=% -- re-raising for full trace\n" success to:listener
		throw
	)
	--prograssUpdate 100

--CP close bat file and empty out temporary libraries
	-- ARNOLD CONVERSION: guard the stream cleanup -- if the export threw before
	-- the .bat stream was created (or createFile failed), gstreamBATCP is
	-- undefined and flush/close would throw a misleading secondary error.
	if gstreamBATCP != undefined do
	(
		try ( flush gstreamBATCP ) catch ()
		try ( close gstreamBATCP ) catch ()
	)

	gc() 									-- do a garbage collect
	try ( delete $TB2_* ) catch ()			-- delete any dangling temp meshes that might have been created before
--CP TEMP	FnDeleteFiles ((modelName.Destination which:#temp) + "*.*")
	try ( delete templightcp ) catch ()
	gCameraRig.ResetRig()



	if (gAutoexecute) then 
	(
		if not (executebatchfsh()) then	
		(
			--executeDATCmd()
		)
	)

	--	Report elapsed time
	local timeStr = ("Processing time was : " + (((timeStamp()-startTime)/60000.0) as string) + " minutes\n")
	fnLogMessage timeStr
	format timeStr to:listener

	progressEnd()
	setArrowCursor()
	
	if success == -1 then
	(
		messageBox ("Render is complete.\n" + timeStr)
	)
	else if success == -2 then	--	Progress cancelled by user
	(
		if datName != undefined then
		(
			FnDeleteFiles datName
		)
		
		messagebox "Export aborted by user."
	)
	else
	(
		messageBox ("Export failed!\nCode = " + (success as string))
	)

	return success
)