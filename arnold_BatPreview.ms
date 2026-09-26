--------------------------------------------------------------------------------
--	Script file guard
--	Examine its value to see how many times the script was run.
--------------------------------------------------------------------------------
if ( guardPreview == undefined ) then
(
	global guardPreview = 0
)

guardPreview += 1

global B4M_Preview

--------------------------------------------------------------------------------------
--	Preview a single zoom/rotation using the Arnold renderer.
--	Bat_Preview() is wired to the Preview button in the Preview roll-out.
--------------------------------------------------------------------------------------
fn Bat_Preview = (
	-- '$LOD*' may be empty; guard against an undefined wildcard match.
	local lodCount = 0
	try ( lodCount = $LOD*.count ) catch ( lodCount = 0 )

	if lodCount == 0 then (
		messageBox "No LODs were found in the scene. \nPress Re-fit LOD's button in Parameters Roll-out and, if needed, edit them"
	) else if gCameraRig.curCam == undefined then (
		messageBox "No view current camera is set, please select a rotation or zoom from the Preview rollout"
	) else (
		local meshMaxX = 0
		local meshMaxY = 0
		local boxRadius = 8
		local PPT = 8
		-- 'sfhd' is declared in CPCameraRig.ms / arnold_CameraRig_HD.ms; default to
		-- the SD thumbnail size if the HD rig has not been loaded.
		local zoomSizes = #( 8, 16, 32, 73, sfhd )
		local curRot = #( "South", "East", "North", "West" )
		local testPt = ( point3 0 0 0 )
		local BBdim = $LOD3.max - $LOD3.min
		local myBB = box width:bbDim.x length:bbDim.y height:bbDim.z
		myBB.center = $LOD3.center
		hide $LOD*
		hide myBB

		local RenderCam = FreeCamera()
		renderCam.transform = gCameraRig.curCam.transform

		local z = -23.898 + myBB.center.z
		move RenderCam [myBB.Center.x, myBB.center.y, z]

		RenderCam.Target_Distance = gCameraRig.curCam.Target_Distance
		RenderCam.OrthoProjection = true
		RenderCam.name = "Preview: " + ( curRot[gCameraRig.curRot] ) as string + " Zoom" + gCameraRig.curZoom as string

		local maxPt = myBB.max
		local minPt = myBB.min

		for vrtIndex in 0 to 7 do (
			if ( ( bit.and vrtIndex 1 ) > 0 ) then
				testPt.x = maxPt.x
			else
				testPt.x = minPt.x

			if ( ( bit.and vrtIndex 2 ) > 0 ) then
				testPt.y = maxPt.y
			else
				testPt.y = minPt.y

			if ( ( bit.and vrtIndex 4 ) > 0 ) then
				testPt.z = maxPt.z
			else
				testPt.z = minPt.z

			local CamPt = fnTransformPt testPt ( inverse RenderCam.transform )

			local camX = abs camPt.x
			if ( camX > meshMaxX ) do meshMaxX = camX

			local camY = abs camPt.y
			if ( camY > meshMaxY ) do meshMaxY = camY
		)

		testPt.z = 0
		local scrSZ = meshMaxX + PPT

		local cellMinX = meshMaxX
		local cellMaxX = - meshMaxX

		for vrtIndex in 0 to 3 do (
			if ( ( bit.and vrtIndex 1 ) > 0 ) then
				testPt.x = boxRadius
			else
				testPt.x = - boxRadius

			if ( ( bit.and vrtIndex 2 ) > 0 ) then
				testPt.y = boxRadius
			else
				testPt.y = - boxRadius

			local camPt = FnTransformPt testPt ( inverse gCameraRig.CurCam.transform )

			if ( camPt.x > cellMaxX ) do cellMaxX = camPt.x
			if ( camPt.x < cellMinX ) do cellMinX = camPt.x
		)

		local renderFov = 2 * ( atan ( scrSZ / gCameraRig.curCam.Target_Distance ) )
		renderwidth  = ceil ( ( zoomSizes[gCameraRig.curZoom] * 2 * scrSZ ) / ( cellMaxX - cellMinX ) + .5 )
		renderheight = ceil ( ( ( ( meshMaxY + PPT ) / scrSZ ) * renderWidth ) + .5 )

		renderCam.FOV = renderFov

		-- Render with whatever renderer is currently assigned (Arnold, per the
		-- Setup flow). Do NOT force renderers.current here -- that would replace
		-- the user's configured Arnold renderer with a fresh default each preview.
		local arnoldActive = false
		try (
			arnoldActive = (findString ((classOf renderers.current) as string) "Arnold") != undefined
		) catch ( arnoldActive = false )
		if (not arnoldActive) do
			messageBox "Arnold is not the current renderer. Set it in Render Setup (F10) before previewing."

		-- Render the preview into the global B4M_Preview bitmap.
		B4M_Preview = render camera:RenderCam

		delete RenderCam
		delete myBB
	)
)
