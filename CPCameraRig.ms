--------------------------------------------------------------------------------
--	Script file guard
--	Examine its value to see how many times the script was run.
--------------------------------------------------------------------------------
if (guardCameraRig == undefined) then
(
	global guardCameraRig = 0
)	
guardCameraRig += 1

--------------------------------------------------------------------------------
--	Make sure TB2 starup was executed first.
--------------------------------------------------------------------------------
if (guardTB2Startup == undefined) then
(
	global guardTB2Startup = 0
FileIn ((getDir #startupScripts) + "\\CPTB2Startup.ms")
)

-----------------------------------------------------------------------------------------
-- Script library includes
-----------------------------------------------------------------------------------------
FnTB2FileInOnce "CPScriptUtils.ms"	guardScriptUtils
FnTB2FileInOnce "CPBuildingMill.ms"	guardBuildingMill

-----------------------------------------------------------------------------------------
-- Auxiliary functions
-----------------------------------------------------------------------------------------

fn UsingInternalRenderer = 
(
    return false
)

-----------------------------------------------------
--CP ADDED GLOBAL VARIABLES
------------------------------------------------------
global sfhd = 146
gcurCamCP
gcheckCP
gWTCX
gtestcp1
grenwidCP = 0.123		
grenwidCP = 0.123		
grenhtcp = 0.123
GrenBoxCP
--------------------------------------------------------------------------------
--	struct stViewportCameraRig 
--										
-- class to manage the camera, lighting rig, & view transform setup for 
--	the building mill also handles calculating the pixel location of world pixels
--	in rendered images
--------------------------------------------------------------------------------
struct stViewportCameraRig
(
	-- Declare data members and give them default values so we don't have to initialize them on construction
	
	-- These are treated as constants
	rigNamePattern			= "*TB2_CameraLightRig*",
	rigRootName 			= "TB2CameraHandle",
	thumbnailCamName 		= "Thumbnail Camera",
	cameraNames 			= #("Camera Z1", "Camera Z2", "Camera Z3", "Camera Z4", "Camera Z5"),
	boxRadius 				= 8, -- half the reference cell width for the projected zoom sizes
	zoomSizes				= #( 8, 16, 32, 73, sfhd ), 	
	rotStep					= 90.0,  -- how many angle views to a circle, buildings use 4, sprites 8 (16?)
	viewportSlop 			= 8.0,   -- in world units, how much to extend edge of viewport beyond max object dimension
	-- Variable data
	fileName					= undefined,
	curZoom 					= -1,
	curRot 					= -1,
	usingThumbnailCam		= false,
	curCam 					= undefined,
	worldToCamXform 		= (matrix3 1),
	
	localToWorldXform 	= (matrix3 1),
	
	renderWidth 			= -1,
	renderHeight 			= -1,
	renderFov 				= 0.0,
	renderScaleX 			= 0.0,
	renderScaleY 			= 0.0,
	
	
	---------------------------------------------------------------------------------------------------
	-- Function:	InvalidateRenderParams	 																								
	---------------------------------------------------------------------------------------------------
	fn InvalidateRenderParams = 
	(
		renderWidth 		= -1
		renderHeight 		= -1
		renderFov 			= 0.0
		renderScaleX 		= 0.0
		renderScaleY 		= 0.0
	),
	
	---------------------------------------------------------------------------------------------------
	--	Function: 	DeleteMultipleXRefRigs																				
	---------------------------------------------------------------------------------------------------
	
	fn DeleteMultipleXRefRigs = 
	(
		--	Find all XRef'ed rigs and delete all but one
		
		local xrefCount 	= xrefs.getXRefFileCount()
		local rigsFound 	= 0
		
		if (xrefCount > 0) then
		(
			for idx = xrefCount to 1 by -1 do
			(
				local xrefFile = xrefs.getXRefFile idx
				
				if (matchPattern xrefFile.filename pattern:rigNamePattern) then
				(
					rigsFound += 1
					
					if (rigsFound > 1) then
					(
						if (xrefFile.filename == fileName) then
						(
							fileName = undefined
						)
						
						delete xrefFile
						rigsFound -= 1
					)
				)
			)
		)
		
		return rigsFound
	),
	
	---------------------------------------------------------------------------------------------------
	--	Function: 	DeleteAllXRefRigs																				
	---------------------------------------------------------------------------------------------------
	
	fn DeleteAllXRefRigs = 
	(
		fileName = undefined
		
		local xrefCount 	= xrefs.getXRefFileCount()
		
		if (xrefCount == 0) then
		(
			return ok
		)


		for idx = xrefCount to 1 by -1 do
		(
			local xrefFile = xrefs.getXRefFile idx

			if (matchPattern xrefFile.filename pattern:rigNamePattern) then
			(
				delete xrefFile
			)
		)
		
		return ok
	),

	---------------------------------------------------------------------------------------------------
	--	Function: 	GetRigXRef																				
	---------------------------------------------------------------------------------------------------
	
	fn GetRigXRef = 
	(
		--	Find all XRef'ed rigs and delete all but one
		
		local xrefCount 	= xrefs.getXRefFileCount()
		
		for xrefIdx = 1 to xrefCount do 
		(
			local xrefFile = xrefs.getXRefFile xrefIdx

			if (matchPattern xrefFile.filename pattern:rigNamePattern) then
			(
				fileName = xrefFile.fileName
				return xrefFile
			)
		)
		
		--	No XRef'ed rig found
		
		local rigs = getFiles (gCamLightsFolder + rigNamePattern)
		
		if rigs.count > 0 then
		(
			fileName = rigs[1]
			local xrefFile = xrefs.addNewXRefFile fileName
			return xrefFile
		)
		else
		(
			fileName = undefined
			return undefined
		)
	),
	
	---------------------------------------------------------------------------------------------------
	--	Function: 	IsPointLit																						
	---------------------------------------------------------------------------------------------------
	
	fn IsPointLit lightNode pt =
	(
		if ((classOf lightNode) != TargetDirectionalLight) then
		(
			return true
		)
		
		local lightDir = -lightNode.dir
		
		local auxDot = dot (pt - lightNode.pos) lightDir
		
		if auxDot < 0  then
		(
			return false
		)
		
		return (length (pt - lightNode.pos - auxDot * lightDir) <= lightNode.falloff)
	),
	
	---------------------------------------------------------------------------------------------------
	--	Function: 	CheckCurLights																						
	---------------------------------------------------------------------------------------------------
	
	fn CheckCurLights = 
	(
		if geometry.count == 0 then
		(
			return true
		)
		
		local curXrefRig = GetRigXRef()
		
		if (curXrefRig == undefined) then
		(
			return true
		)
		
		local sceneMin = geometry.min
		local sceneMax = geometry.max
		
		local rigNodes = FnCollectTree curXrefRig.tree
		
		for idx = 1 to rigNodes.count do
		(
			if ((classOf rigNodes[idx]) == TargetDirectionalLight) then
			(
				local thisLight = rigNodes[idx]
				
				for vertIdx = 1 to 8 do
				(
					if not (IsPointLit thisLight (GetBoxVert sceneMin sceneMax vertIdx)) then
					(
						return false
					)
				)
			)
		)
		
		return true
	),
	
	---------------------------------------------------------------------------------------------------
	--	Function: 	AutoCheckAndFixXRef1																						
	---------------------------------------------------------------------------------------------------
	
	fn AutoCheckAndFixXRef1 = 
	(
		local bChangedFile = false
		local bChangedBind = false
		-- XRef Check and fix
		local xrefCount 	= xrefs.getXRefFileCount()
		local xref1
		local bindNode		= rigRootName
		
		if (xrefCount==1) then 
		(
			xref1 = xrefs.getXRefFile 1
			
			-- If the file has correct cameras and lights
			
			if (xref1.filename == gCamLightsPath) then 
			(			
				-- ... but invalid binding
				if ((xref1.parent == undefined) or (xref1.parent.name != bindNode)) do 
				(
					local rigRoot = (FnFindChildNode bindNode rootNode)
					
					if (rigRoot != undefined) then 
					(
						delete rigRoot
					)
					
					rigRoot = dummy boxsize:(point3 16 16 16) name:(bindNode)
					
					xref1.parent = rigRoot
					--hide rigRoot
				)
			)
			-- If the file has incorrect cameras and lights
			else 
			(									
				xrefs.deleteAllXRefs()
				
				local rigRoot = (FnFindChildNode bindNode rootNode)
				
				if (rigRoot != undefined) then 
				(
					delete rigRoot
				)
				
				rigRoot = dummy boxsize:(point3 16 16 16) name:(bindNode)
				local camXref = xrefs.addNewXRefFile gCamLightsPath
				
				camXref.parent = rigRoot
				--hide rigRoot
				
				bChangedFile = true
			)
		)
		else 
		(
			if (xrefCount>1) then 
			(
				xrefs.deleteAllXRefs()		
			)
			
			local rigRoot = (FnFindChildNode bindNode rootNode)
			
			if (rigRoot != undefined) then 
			(
				delete rigRoot
			)
			
			local dummyRoot = dummy boxsize:(point3 16 16 16) name:(bindNode)
			local camXref 	= xrefs.addNewXRefFile gCamLightsPath
			camXref.parent 	= dummyRoot
			--hide rigRoot
			
			bChangedFile = true
		)
		
		hide $helpers
		
		return bChangedFile 
	),
	
	---------------------------------------------------------------------------------------------------
	--	Function: 	AutoCheckAndFixXRef2																						
	-- Return error codes:																										
	--			0	-	No error																										
	--		  -1	-	Unknown error																								
	--		  -2	-	No camera and lights rig found																		
	--			1	-	Insufficent lighting, default or current lights used											
	---------------------------------------------------------------------------------------------------
	
	fn AutoCheckAndFixXRef2 = 
	(
		try
		(
			local rigRootNode = (FnFindChildNode rigRootName rootNode)

			if (rigRootNode == undefined) then
			(
				rigRootNode = dummy boxsize:(point3 16 16 16) name:(rigRootName)
			)

			--	Delete all but one xref'ed rigs

			DeleteMultipleXRefRigs()

			--	Find current rig

			local rigXRef = GetRigXRef()

			if rigXRef == undefined then
			(
				--messagBox "No camera and lights rig found!"
				return -2
			)

			--	Fix binding if necessary

			if (rigXRef.parent != rigRootNode) then
			(
				if (rigXRef.parent != undefined) then
				(
					rigXRef.parent.transform = (rotateZMatrix (0))
				)
				rigXRef.parent = rigRootNode
			)


			if CheckCurLights() then
			(
				return 0
			)
			
			local rigs = getFiles (gCamLightsFolder + rigNamePattern)

			if rigs.count == 0 then
			(
				return -2		--	At this point this should not happen, but lwt's check just in case...
			)

			local origRigName = fileName

			DeleteAllXRefRigs()

			for rigIdx = 1 to rigs.count do
			(
				fileName = rigs[rigIdx]

				if fileName != origRigName then
				(
					rigXRef = xrefs.addNewXRefFile fileName
					rigXRef.parent = rigRootNode

					if CheckCurLights() then
					(
						return 0
					)
					else
					(
						fileName = undefined
						delete rigXRef
					)
				)
			)


			--	If we got here, none of the rigs lit the whole scene
			--	Let the user know about thta and set original rig

			--messageBox "Available rigs do not privde sufficient lights for your building.\nDefault lights will be used."
			
			print "0"
			fileName = origRigName
			
			if fileName == undefined then
			(
				fileName = rigs[1]
			)
			
			print "1"
			rigXRef = xrefs.addNewXRefFile fileName
			print "2"
			rigXRef.parent = rigRootNode
			print "3"
		)
		catch 
		(
			return -1
		)
		
		return 1	--	Insufficent lighting
	),
	
	---------------------------------------------------------------------------------------------------
	--	Function: 	AutoCheckAndFixXRef																						
	---------------------------------------------------------------------------------------------------
	fn AutoCheckAndFixXRef = 
	(
		return AutoCheckAndFixXRef2()
	),
	
	---------------------------------------------------------------------------------------------------
	--	Function: 	ErrorMessage																						
	---------------------------------------------------------------------------------------------------
	fn ErrorMessage errorCode = 
	(
		local errorMsg
		
		case errorCode of
		(
			(-1): errorMsg = "Unknown Camera and Lights Rig error!"
			(-2): errorMsg = "Camera and Lights Rig file not found!"
		)
		
		if errorMsg != undefined then
		(
			FnErrorMessage errorMsg
		)
		
		ok
	),
	
	
	---------------------------------------------------------------------------------------------------
	-- Function:	CheckRig		 																																								
	---------------------------------------------------------------------------------------------------
	fn CheckCameras = 
	(
		local rigOK 	= ((FnGlobalFindNode rigRootName) != undefined)
		local zoomVal	= 1
		
		while (rigOK and zoomVal <= 5) do
		(
			rigOK = ((FnGlobalFindNode cameraNames[zoomVal]) != undefined)
			zoomVal += 1
		)
		
		if not rigOK then
		(
			rigOK = (AutoCheckAndFixXRef() >= 0)

			zoomVal	= 1

			while (rigOK and zoomVal <= 5) do
			(
				rigOK = ((FnGlobalFindNode cameraNames[zoomVal]) != undefined)
				zoomVal += 1
			)
		)

		return rigOK
	),
	
	---------------------------------------------------------------------------------------------------
	-- Function:	SetCam		 																								
	-- Param:		zoomVal																										
	-- Param:		rotVal																										
	-- Desc:			This function sets the following data memebrs:													
	--						curZoom																									
	--						curRot																									
	--						curCam																									
	--						worldToCamXform																						
	--					and invalidates rendering parameters.																
	---------------------------------------------------------------------------------------------------
	fn SetCam zoomVal rotVal updateViewport:false = 
	(
		usingThumbnailCam = false
		
		local bViewChanged 	= false
		local zoomCam 			= (FnGlobalFindNode cameraNames[zoomVal])
		local rigRoot 			= (FnGlobalFindNode rigRootName)
		
		if (zoomCam == undefined or rigRoot == undefined) then
		(
			local fixResult = AutoCheckAndFixXRef()
			
			if fixResult >= 0 then
			(
				zoomCam  = (FnGlobalFindNode cameraNames[zoomVal])
				rigRoot 	= (FnGlobalFindNode rigRootName)
			)
			else
			(			
				ErrorMessage fixResult
				return false
			)
			
			if zoomCam == undefined then
			(
				FnErrorMessage ("Couldn't find camera \"" + cameraNames[zoomVal] + "\".")
				return false
			)

			if (rigRoot == undefined) then 
			(
				FnErrorMessage ("Couldn't find \"" + rigRootName + "\"")
				return false
			)
		)
		
		curCam 			= zoomCam
		curZoom 			= zoomVal		
		curRot 			= rotVal 
		
		animate off
		
		rigRoot.transform = (rotateZMatrix (rotStep * (curRot-1) ))
		
		worldToCamXform 	= inverse curCam.transform
--CP gWTCX = worldtocamxform
		InvalidateRenderParams()
		
		if updateViewport then
		(
			viewport.setCamera curCam
		)
		
		-- DIAGNOSTIC: Verify if the physical sky sun direction is changing per rotation
		if sky_map != undefined then (
			local az = "undefined"
			local sd = "undefined"
			if (hasProperty sky_map "azimuth") do az = sky_map.azimuth as string
			if (hasProperty sky_map "sun_direction") do sd = sky_map.sun_direction as string
			format "DIAGNOSTIC SetCam (zoom:% rot:%): sky_map.azimuth = %, sun_direction = %\n" curZoom curRot az sd
		)
		
		return true
	),
	
	---------------------------------------------------------------------------------------------------
	-- Function:	RestoreCam	 																								
	---------------------------------------------------------------------------------------------------
	fn RestoreCam = 
	(
		local zoomCam = (FnGlobalFindNode cameraNames[curZoom])
		
		if (zoomCam != undefined) then 
		(
			curCam = zoomCam
		)
		
		ok
	),
	
	---------------------------------------------------------------------------------------------------
	-- Function:	ResetRig 																								
	---------------------------------------------------------------------------------------------------
	fn ResetRig = 
	(
		local rigRoot = (FnGlobalFindNode rigRootName)
		
		if (rigRoot == undefined) then 
		(
			return false
		)

		rigRoot.transform = (rotateZMatrix (0))
		
		return true
	),
	
	---------------------------------------------------------------------------------------------------
	-- Function:	GetViewDir																									
	---------------------------------------------------------------------------------------------------
	fn GetViewDir = 
	(
		if UsingInternalRenderer() then
		(
			return GetRenderViewDir()
		)		
		else if (curCam != undefined) then 
		(
			local camTM = curCam.transform
			return -camTM.row3
		)
		else 
		(
			FnErrorMessage ("GetViewDir : Camera rig un-initialized!")
			return (point3 0 0 -1) -- top view
		)
	),
	
	---------------------------------------------------------------------------------------------------
	-- Function:	GetRenderPos																								
	-- Param:		objPt																											
	---------------------------------------------------------------------------------------------------
	fn GetRenderPos objPt = 
	(
		if UsingInternalRenderer() then
		(
			return GetRenderPosition objPt localToWorldXform
		)
		else if (curCam != undefined) then
		(
			local worldPt 	= FnTransformPt objPt localToWorldXform
			local camPt 	= FnTransformPt worldPt worldToCamXform
			local renderPt = (point3 0 0 0)

			renderPt.x = (0.5 + camPt.x * renderScaleX/curCam.Target_Distance) * renderWidth
			renderPt.y = (0.5 - camPt.y * renderScaleY/curCam.Target_Distance) * renderHeight
			renderPt.z = camPt.z

			return renderPt
		)
		else 
		(
			FnErrorMessage ("GetRenderPos : Camera rig un-initialized!")
			return (point3 0 0 0) -- punt
		)
	),
	
	---------------------------------------------------------------------------------------------------
	-- Function:	SetupRenderViewport																						
	-- Param:		nodes																											
--CP curCam must be initialized
	-- Desc:			This function sets the rendering parameters.														
	---------------------------------------------------------------------------------------------------
	fn SetupRenderViewport nodes = 
	(
		if (curCam == undefined) do 
		(
			FnErrorMessage ("SetupRenderViewport : Camera rig un-initialized! Render will fail.")
			InvalidateRenderParams()
			return false
		)
		
		-- first get x,y dimensions of nodes to render in camera/world space
		local meshMaxY = 0.
		local meshMaxX = 0.
		local testPt 	= (point3 0 0 0)
		local vrtIndex 
		local camPt
		local obj
		for obj in nodes do 
		(
			local maxPt = obj.max
			local minPt = obj.min
			for vrtIndex in 0 to 7 do -- iterate all corners of the box
			(
				if ((bit.and vrtIndex 1)>0) then
					testPt.x = maxPt.x
				else
					testPt.x = minPt.x
				
				if ((bit.and vrtIndex 2)>0) then
					testPt.y = maxPt.y
				else
					testPt.y = minPt.y
				
				if ((bit.and vrtIndex 4)>0) then
					testPt.z = maxPt.z
				else
					testPt.z = minPt.z
				
				camPt = FnTransformPt testPt worldToCamXform
				
				local camX = abs camPt.x
				if (camX > meshMaxX) do meshMaxX = camX
			
				local camY = abs camPt.y
				if (camY > meshMaxY) do meshMaxY = camY
			)	
		)
		local targetWidth2 = meshMaxX + viewportSlop -- add some slop on each edge
		
		-- now figure out how many pixels this should be
		testPt.z 		= 0
		
		local cellMinX = targetWidth2  	-- forces reset later
		local cellMaxX = -targetWidth2
		for vrtIndex in 0 to 3 do 			-- iterate all corners of a square cell centered on the origin
		(
			if ((bit.and vrtIndex 1)>0) then
				testPt.x = boxRadius
			else
				testPt.x = -boxRadius
			
			if ((bit.and vrtIndex 2)>0) then
				testPt.y = boxRadius
			else
				testPt.y = -boxRadius
			
			camPt = FnTransformPt testPt worldToCamXform
			
			if (camPt.x > cellMaxX) do cellMaxX = camPt.x
			if (camPt.x < cellMinX) do cellMinX = camPt.x
		)
		-- set camera fov large enough so width of building appears in view
		renderFov 		= 2 * (atan (targetWidth2/curCam.Target_Distance))
		if usingThumbnailCam then
		(
			renderWidth 	= (146 * 2.0 * targetWidth2)/(cellMaxX - cellMinX)
		)
		else
		(
			renderWidth 	= (zoomSizes[curZoom] * 2.0 * targetWidth2)/(cellMaxX - cellMinX)
		)
		renderWidth 	= ((renderWidth  + 0.5) as integer)		-- round off
		renderHeight 	= (((meshMaxY + viewportSlop)/targetWidth2) * renderWidth)
		renderHeight 	= ((renderHeight + 0.5) as integer)		-- round off
		renderScaleX 	= (0.5*curCam.Target_Distance) / targetWidth2
		renderScaleY 	= (renderWidth * renderScaleX) / renderHeight
grenwidCP = renderWidth		
grenhtCP = renderHeight		
		true
--CP gcheckCP = 9		
	),
	
	---------------------------------------------------------------------------------------------------
	-- Function:	GetCamRenderRegion																						
	-- Param:		nodes
    -- RETURNS 2 DIMESIONAL BOX OF RENDERING REGION IN PIXELS																											
	---------------------------------------------------------------------------------------------------
	fn GetCamRenderRegion nodes adjust: true =
	(
		local scrnBox
		
		--	gmax camera used
		if UsingInternalRenderer() then
		(
			--SetRenderCamera (curZoom - 1) (curRot - 1)
		)
		-- max camera used
		else
		(
			local obj

			for obj in nodes do 
			(
				localToWorldXform = obj.objecttransform		-- set transform to object local

				local objMesh 		= obj.mesh
				local vrtIndx

				for vrtIndx in 1 to objMesh.numverts do 
				(				
					local vert 		= getVert objMesh vrtIndx
					local camPt		= GetRenderPos vert			-- transform object local coordinates to screen
					local scrnPt 	= point2 (floor camPt.x) (floor camPt.y)
					if (scrnBox == undefined) then 
					(
						scrnBox = Box2 scrnPt scrnPt
					)
					else 
					(
						if scrnBox.left > scrnPt.x do
							scrnBox.left = scrnPt.x
						if scrnBox.right <= scrnPt.x do
							scrnBox.right = (scrnPt.x)
						if scrnBox.top > scrnPt.y do
							scrnBox.top = scrnPt.y
						if scrnBox.bottom <= scrnPt.y do
							scrnBox.bottom = (scrnPt.y)
					)
				)
			)

			if /*((maxversion())[1])<11000*/ adjust then
			(
				FnEnlargeBox2 &scrnBox
			)
		)
--CP SCRNBOX IS THE FINAL RENDERING REGION IN PIXELS	
		return scrnBox
	),
	
	---------------------------------------------------------------------------------------------------
	-- Function:	GetPreviewRegion																						
	-- Param:		nodes																											
	---------------------------------------------------------------------------------------------------
	fn GetPreviewRegion nodes =
	(
		local previewBox
		
		if UsingInternalRenderer() then
		(
			previewBox = GetCamRenderRegion nodes
		)
		else
		(
			previewBox = box2 0 0 renderWidth renderHeight
		)

		return previewBox
	),
	
	---------------------------------------------------------------------------------------------------
	-- Function:	CreateTempRenderCam																						
	---------------------------------------------------------------------------------------------------
	fn CreateTempRenderCam = 
	(
		if (curCam == undefined) do 
		(
			FnErrorMessage ("CreateTempRenderCam : Camera rig un-initialized! This is a bug.")
			InvalidateRenderParams()
			return undefined
		)
		
		if ((renderWidth < 0) or (renderHeight < 0) or (renderFov < 0)) do 
		(
			FnErrorMessage ("CreateTempRenderCam : Render viewport not set! This is a bug.")
			InvalidateRenderParams()
			return undefined
		)
		
		renderCam = FreeCamera()
		
		renderCam.Target_Distance 	= curCam.Target_Distance
		renderCam.orthoProjection 	= true
		renderCam.nearrange       	= curCam.nearrange
		renderCam.farrange        	= curCam.farrange
		renderCam.transform       	= curCam.transform
		renderCam.fov    				= renderFov
		renderCam.name   				= uniqueName "TB2_TempRenderCam" 
		
		
		return renderCam
	),
	---------------------------------------------------------------------------------------------------
	-- Function:	CreateRenderCam																							
	--	Param:		renderBox																									
	---------------------------------------------------------------------------------------------------
	fn CreateRenderCam renderBox = 
	(
		local tempCam
		
		if UsingInternalRenderer() then
		(
			-- Do nothing
		)
		else
		(
			tempCam = CreateTempRenderCam()
		)
		
		return tempCam
	),
	
	---------------------------------------------------------------------------------------------------
	-- Function:	SetThumbnailCam																							
	---------------------------------------------------------------------------------------------------
	fn SetThumbnailCam nodes:unsupplied = 
	(
		if (nodes == unsupplied) then
		(
			nodes = FnGlobalFindNode "LOD3"
		)
		
		if (nodes == undefined) then
		(
			return false
		)
		
		usingThumbnailCam = true
		curCam				= (FnGlobalFindNode thumbnailCamName)
		
		if (curCam == undefined) then 
		(
			local zoomCam	= (FnGlobalFindNode cameraNames[5])
			
			if zoomCam == undefined then
			(
				if AutoCheckAndFixXRef() >= 0 then
				(
					zoomCam	= (FnGlobalFindNode cameraNames[5])
				)
				else
				(
					return false
				)
				
				if zoomCam == undefined then
				(
					return false
				)
			)
						
			curCam 	= FreeCamera()

			curCam.Target_Distance 	= zoomCam.Target_Distance
			--curCam.orthoProjection 	= true
			curCam.nearrange       	= zoomCam.nearrange
			curCam.farrange        	= zoomCam.farrange
			curCam.transform       	= zoomCam.transform
			curCam.name 				= thumbnailCamName		
		)
		
		if (curCam == undefined) then
		(
			usingThumbnailCam = false
			return false
		)

		curCam.orthoProjection 	= true	--	At this moment gmax renderer only supports ortho projections
		
		SetRenderCamera 		curCam
		
		local wt = 256
		local ht = 256
		
		local renderBox = Box2 0 0 wt ht
		
		SetRenderRegion 		renderBox 
		SetRenderDimensions 	wt ht 
		
		return true
	),
		
	---------------------------------------------------------------------------------------------------
	-- Function:	GetBBoxRenderRegion																						
	-- Param:		minPt																											
	-- Param:		maxPt																											
	---------------------------------------------------------------------------------------------------
	fn GetBBoxRenderRegion minPt maxPt = 
	(
		local vrtIndex
		local testPt = (point3 0 0 0)
		local camPt
		local scrnPt 
		local scrnBox
		
		localToWorldXform = (matrix3 1)

		for vrtIndex in 0 to 7 do 
		(
			-- iterate all corners of the box
			
			if ((bit.and vrtIndex 1)>0) then
				testPt.x = maxPt.x
			else
				testPt.x = minPt.x
			
			if ((bit.and vrtIndex 2)>0) then
				testPt.y = maxPt.y
			else
				testPt.y = minPt.y
			
			if ((bit.and vrtIndex 4)>0) then
				testPt.z = maxPt.z
			else
				testPt.z = minPt.z
	
			-- now transform it to the screen
			camPt = GetRenderPos testPt

			scrnPt = point2 (floor camPt.x) (floor camPt.y)
			
			-- make sure the screen box is big enough
			if (scrnBox == undefined) then 
			(
				scrnBox = Box2 scrnPt scrnPt
			)
			else 
			(
				if scrnBox.left > scrnPt.x do
					scrnBox.left = scrnPt.x
				if scrnBox.right <= scrnPt.x do
					scrnBox.right = (scrnPt.x)
				if scrnBox.top > scrnPt.y do
					scrnBox.top = scrnPt.y
				if scrnBox.bottom <= scrnPt.y do
					scrnBox.bottom = (scrnPt.y)
			)
		)
		
		return scrnBox
	),
	
	------------------------------------------------------------------------------------------------
	-- Function:	GetPixelWorldPoint																					
	-- Param:		pixelPt 																									
	------------------------------------------------------------------------------------------------
	fn GetPixelWorldPoint pixelPt =
	(
		local p0 = point3 0 0 0

	-- undo projection in cameraRig::GetRenderPos
	p0.x =  (pixelPt.x/renderWidth  - 0.5)*curCam.Target_Distance/renderScaleX
	p0.y = -(pixelPt.y/renderHeight - 0.5)*curCam.Target_Distance/renderScaleY
		p0.z = 4000.0

		-- transform point into world
		return (FnTransformPt p0 curCam.transform)
	)
)

--*************************************************************************************************
-- finally, define a rig in the global scope for everyone to use												
--*************************************************************************************************

global gCameraRig = stViewportCameraRig()
