--------------------------------------------------------------------------------
--	Script file guard
--	Examine its value to see how many times the script was run.
--------------------------------------------------------------------------------
if ( guardCameraRig == undefined ) then
(
    global guardCameraRig = 0
)
guardCameraRig += 1

--------------------------------------------------------------------------------------
--	HD variant of the BAT camera rig.
--
--	The Preview roll-out's SD/HD radio button fileIn's this file to switch the zoom-5
--	(thumbnail) render size. The base rig lives in CPCameraRig.ms; this file simply
--	sets the HD thumbnail size and re-instantiates the global rig so its zoomSizes
--	array picks up the new value.
--
--	The previous version of this file was a corrupted partial copy of the struct
--	(it closed after GetRigXRef and left RenderView / GetRigCamera / GetOutputFileName
--	dangling outside the struct, referencing undefined SetArnoldRendererSettings /
--	SetupArnoldCamera / SetupArnoldLights helpers, and using the wrong ArnoldLight
--	constructor). That made fileIn of this file throw at parse/eval time.
--------------------------------------------------------------------------------------

-- HD thumbnail (zoom 5) renders at 292 px instead of the SD 146 px.
global sfhd = 292

-- Make sure the base rig script (which defines stViewportCameraRig) has been loaded.
if ( stViewportCameraRig == undefined ) then
(
    FnTB2FileInOnce "CPCameraRig.ms" undefined
)

-- Re-instantiate the global rig and override the zoom-5 size on the instance.
-- (The struct's zoomSizes default is baked in at definition time from the old
-- sfhd value, so we override the member directly rather than relying on
-- re-instantiation alone.)
global gCameraRig = stViewportCameraRig()
gCameraRig.zoomSizes = #( 8, 16, 32, 73, sfhd )
