--------------------------------------------------------------------------------
--	Script file guard
--	Examine its value to see how many times the script was run.
--------------------------------------------------------------------------------
if (guardLtbL_functions == undefined) then
(
	global guardLtbL_functions = 0
)

guardLtbL_functions += 1

--------------------------------------------------------------------------------------
--	Arnold "Let There Be Light" functions for BAT (Max).
--
--	NOTE: These use the real MAXtoA (Arnold for 3ds Max) MAXScript classes, which
--	differ from the Mental Ray / mental-ray-style names that were here originally:
--		- lights       : Arnold_Light shapeType:<int>  (6=Skydome, 1=Distant, ...)
--		                 shapeType is a plain integer paramblock param in this
--		                 MAXtoA build, not an enum-by-name.
--		- physical sky : ai_physical_sky  (a Texmap, assigned to a skydome light's
--		                 color map)
--		- tone mapping : Arnold uses render-view "imagers" (exposure / color_manager),
--		                 NOT a SceneExposureControl plugin class. There is no
--		                 "ArnoldExposureControl" class in MAXtoA, and calling one was
--		                 the source of the original
--		                 "type error: call needs function or class, got: undefined".
--		- AOVs / glare : driven via the renderer's imager_* properties, not a
--		                 standalone ArnoldAOV() constructor on the renderer.
--------------------------------------------------------------------------------------

global sky
global sun
global sky_map

--------------------------------------------------------------------------------------
--	Verify that MAXtoA (Arnold) is actually loaded before we try to use its classes.
--	Every constructor below (Arnold_Light, ai_physical_sky, ...) is undefined if the
--	Arnold plugin is not installed / not the current renderer, which produces the
--	exact "call needs function or class, got: undefined" error otherwise.
--------------------------------------------------------------------------------------
fn FnArnoldAvailable =
(
	-- Referencing an undefined MAXScript class throws rather than returning
	-- undefined, so wrap the probe in try/catch.
	local arnoldLoaded = false
	try (
		arnoldLoaded = (Arnold_Light != undefined) and (ai_physical_sky != undefined)
	) catch (
		arnoldLoaded = false
	)

	if (not arnoldLoaded) then
	(
		messageBox "MAXtoA (Arnold) does not appear to be installed.\n\nInstall the Arnold plugin for 3ds Max before using the BAT rig functions."
		return false
	)

	-- Confirm the current renderer is Arnold. We deliberately do NOT reassign
	-- renderers.current here -- doing so would replace the user's configured
	-- Arnold renderer with a fresh default. Just check and warn.
	local arnoldActive = false
	try (
		local curRendererName = ((classOf renderers.current) as string)
		arnoldActive = (findString curRendererName "Arnold") != undefined
	) catch (
		arnoldActive = false
	)

	if (not arnoldActive) then
	(
		messageBox "Arnold is not the current renderer.\n\nOpen Render Setup (F10) and assign the Arnold renderer, then press Setup again."
		return false
	)

	return true
)

--------------------------------------------------------------------------------------
--	Create the physical-sky Texmap used by the day / night rigs.
--	'physical sky' is the Arnold physical_sky shader (Texmap), not a light node.
--------------------------------------------------------------------------------------
fn SetupSky =
(
	sky_map = ai_physical_sky()
	sky_map.name = "physical sky"
	-- ai_physical_sky is a texture; visibility is controlled by the skydome light
	-- that samples it, so there is no sky_map.visibility flag here.

	-- Pin the physical sky's embedded sun to match the MR reference, whose sun
	-- is at [-474,-352,575] (light travels [474,352,-575]). Converting that to
	-- elevation/azimuth: elevation ~= 44.2 deg above horizon, azimuth ~= 216.6 deg
	-- (computed below). We set BOTH use_degrees=true + azimuth/elevation AND the
	-- raw sun_direction vector, so whichever mode the skydome reads from is
	-- consistent.
	--
	-- NOTE: the Arnold default azimuth is 90, which is ~127 deg off from MR's
	-- 216.6 -- that is why the original exports shaded faces on the wrong side
	-- compared to real Maxis buildings.
	if (hasProperty sky_map "use_degrees") do sky_map.use_degrees = true
	if (hasProperty sky_map "elevation") do sky_map.elevation = 44.2
	if (hasProperty sky_map "azimuth")   do sky_map.azimuth   = 216.6
	-- sun_direction points TOWARD the sun (the sun's position direction), which
	-- is the opposite sign from the light-travel ray direction [474,352,-575].
	local sd = [-474.0, -352.0, 575.0]
	local sdLen = length sd
	if sdLen > 0.0 do sd = sd / sdLen
	if (hasProperty sky_map "sun_direction") do sky_map.sun_direction = sd
)

--------------------------------------------------------------------------------------
--	Set the render background.
--
--	The original BAT4Max (gmax/MR) rendered the building against a flat gray
--	environment -- the gmax default background, which read as a mid-gray ground.
--	A skydome light only illuminates; it does not show up behind geometry, so we
--	must set the Arnold environment background explicitly. We use a flat gray
--	background COLOR (matching the original look), not the physical-sky image:
--	the skydome still lights the scene with the physical sky.
--
--	'env_phys_bgnd_mode': 0 = Use Background Color, 1 = Use Map.
--------------------------------------------------------------------------------------
fn FnSetSkyBackground =
(
	local ren = renderers.current
	local didSet = false

	-- Use black background for both preview and export to avoid lighting discrepancies
	-- and prevent gray outline bleeding in premultiplied alpha exports.
	local bgGray = (color 0 0 0)

	-- Path A: MAXtoA's own environment background color slot.
	try (
		if (hasProperty ren "env_phys_bgnd_mode") and (hasProperty ren "env_phys_bgnd_color") then
		(
			ren.env_phys_bgnd_mode = 0   -- 0 = Use Background Color
			ren.env_phys_bgnd_color = bgGray
			didSet = true
		)
	) catch ()

	-- Path B: 3ds Max background color (core global, honored by every renderer).
	try (
		backgroundColor = bgGray
		didSet = true
	) catch ()

	return didSet
)

--------------------------------------------------------------------------------------
-- ARNOLD CONVERSION: export background swap.
--
-- The export pipeline (FnDoRender2) renders with premultiplied alpha
-- (targa.itgaio.setPreMultAlpha true) -- this matches the original Mental-Ray
-- BAT, where it worked because MR rendered against a BLACK background. With a
-- black bg, premultiplied edge pixels bleed toward black, which is invisible
-- behind the alpha mask in the SC4 FSH sprite.
--
-- For the PREVIEW we set a gray background so the preview window isn't pure
-- black. But that same gray background is fatal for export: premultiplied edges
-- bleed toward gray (128), producing a bright gray outline/halo around the
-- building in every exported FSH tile.
--
-- Fix: render export against BLACK (restoring the MR condition), keep gray for
-- the interactive preview. These helpers save the current bg, force black for
-- the export render, then restore gray afterward.
--------------------------------------------------------------------------------------
global FnPushExportBg
global FnPopExportBg

-- Store saved values in a small global stack so Push/Pop nest correctly.
global g_ArnoldExportBgStack = #()

fn FnPushExportBg =
(
	local ren = renderers.current
	local savedEnvMode = undefined
	local savedEnvColor = undefined
	local savedCoreBg = backgroundColor
	try (
		if (hasProperty ren "env_phys_bgnd_mode") do savedEnvMode = ren.env_phys_bgnd_mode
		if (hasProperty ren "env_phys_bgnd_color") do savedEnvColor = ren.env_phys_bgnd_color
	) catch ()
	-- force BLACK on both slots
	try (
		if (hasProperty ren "env_phys_bgnd_mode") and (hasProperty ren "env_phys_bgnd_color") then
		(
			ren.env_phys_bgnd_mode = 0
			ren.env_phys_bgnd_color = (color 0 0 0)
		)
	) catch ()
	backgroundColor = (color 0 0 0)
	append g_ArnoldExportBgStack #(savedEnvMode, savedEnvColor, savedCoreBg)
	return true
)

fn FnPopExportBg =
(
	if g_ArnoldExportBgStack.count == 0 do return false
	local top = g_ArnoldExportBgStack[g_ArnoldExportBgStack.count]
	deleteItem g_ArnoldExportBgStack g_ArnoldExportBgStack.count
	local savedEnvMode = top[1]
	local savedEnvColor = top[2]
	local savedCoreBg = top[3]
	local ren = renderers.current
	try (
		if (savedEnvMode != undefined) and (hasProperty ren "env_phys_bgnd_mode") do ren.env_phys_bgnd_mode = savedEnvMode
		if (savedEnvColor != undefined) and (hasProperty ren "env_phys_bgnd_color") do ren.env_phys_bgnd_color = savedEnvColor
	) catch ()
	if savedCoreBg != undefined do backgroundColor = savedCoreBg
	return true
)

fn SetupGround =
(
	local ground_layer = layerManager.getLayerFromName "ground plane"

	if ground_layer != undefined then (
		ground_layer.current = true
		ground_layer.isHidden = false
	) else (
		ground_layer = LayerManager.newLayerFromName "ground plane"
		ground_layer.current = true
		ground_layer.isHidden = false
	)

	-- Re-use a fresh ground plane each time.
	if (getNodeByName "earth") != undefined then (
		delete $earth
	)

	local ground = plane length:1000 width:1000 name:"earth"
	ground.primaryVisibility = off
	ground.material = standardmaterial diffuseColor:(color 100 100 100)

	(LayerManager.getLayer 0).current = true
	MessageBox "Ground has been created!"
)

--------------------------------------------------------------------------------------
--	Tone mapping in MAXtoA.
--
--	Arnold does NOT use 3ds Max's SceneExposureControl; tone mapping is done by
--	"imager" shaders attached to the render view. In this MAXtoA build (confirmed
--	by probing the live scene):
--	  - the exposure imager class is  ai_imager_exposure   (with the ai_ prefix)
--	  - it is assigned to the renderer via  renderer.imager_0
--	  - it has properties  #Enable  (capital E) and  #exposure
--	Note: imager_0 is only populated AFTER an imager is created; we construct one
--	directly so the user never has to touch Render Setup.
--	Note: colorManagement is undefined in this Max config, so display gamma is not
--	a usable fallback -- the imager is the only path.
--------------------------------------------------------------------------------------

-- Create/replace the exposure imager at the given exposure value. Returns true
-- on success, false if this MAXtoA build does not expose the imager as expected.
fn FnEnableExposureImager exposureValue =
(
	local result = false
	local myRen = renderers.current

	try (
		-- ai_imager_exposure is the real class (imager_exposure without the
		-- ai_ prefix is undefined and was the source of the earlier failure).
		local im = ai_imager_exposure()
		if (hasProperty im "Enable") do im.Enable = true
		if (hasProperty im "exposure") do im.exposure = exposureValue
		if (hasProperty myRen "imager_0") do myRen.imager_0 = im
		result = true
	) catch ()

	return result
)

fn FnSetExposureImager exposureValue gammaValue =
(
	local ok = FnEnableExposureImager exposureValue
	if (not ok) do
	(
		local msg = "Automatic Arnold exposure imager could not be set on this MAXtoA build.\n\nOpen Render Setup > Arnold > Imagers and add an Exposure imager (exposure ~" + (exposureValue as string) + ") manually for correct brightness."
		messageBox msg
	)
)

--------------------------------------------------------------------------------------
--	Glare is a night effect. There is no standalone 'glare' imager; bloom/glow is
--	the lens_effects imager. We just instruct the user, since the imager list is
--	managed through the Render Setup UI in this build.
--------------------------------------------------------------------------------------
fn Glare =
(
	local MaxisNiteSky = getNodeByName "Arnold Sky | Maxis nite"
	local DarkNiteSky  = getNodeByName "Arnold Sky | Dark nite"

	if (MaxisNiteSky != undefined) or (DarkNiteSky != undefined) then
	(
		messageBox "For night glare, open Render Setup > Arnold > Imagers and add a Lens Effects imager, then adjust bloom/glow to taste."
	)
	else
	(
		messageBox "Glare is a night effect. Set the night rig by pressing\n\n-Maxis Nite- or -Dark Nite-\n\nbutton first."
	)
)

fn SetRigLayerVisibility =
(
	local Bat_Rig_Layer = layerManager.getLayerFromName "Rig"

	if Bat_Rig_Layer != undefined then (
		Bat_Rig_Layer.current = true
		Bat_Rig_Layer.isHidden = true
		Bat_Rig_Layer.isFrozen = true
	) else (
		Bat_Rig_Layer = LayerManager.newLayerFromName "Rig"
		Bat_Rig_Layer.current = true
		Bat_Rig_Layer.isHidden = true
		Bat_Rig_Layer.isFrozen = true
	)
)

fn ClearRig =
(
	-- Delete the Arnold rig lights we create (by name), regardless of parent.
	-- Previously this only deleted lights parented to TB2CameraHandle, but the
	-- lights now stay fixed in world space (not parented), so clean up by name.
	local rigLightNames = #("Arnold Sky", "Arnold Sun", "Arnold Sun.Target", "Arnold Sky | Maxis nite", "Arnold Sky | Dark nite")
	for nm in rigLightNames do
	(
		local n = getNodeByName nm
		if n != undefined and not isDeleted n do delete n
	)
	-- Also catch any stragglers previously parented to the camera handle.
	local lt = ($Lights) as array
	for n = 1 to lt.count do
	(
		if lt[n] != undefined and not isDeleted lt[n] do
		(
			if lt[n].parent != undefined and (lt[n].parent.name == "TB2CameraHandle") do delete lt[n]
		)
	)
)

fn SetUnits =
(
	units.SystemType = #meters
	units.SystemScale = 1.0
	units.DisplayType = #metric
)

-----------------------------------------------------------------------------
--	Rigs
-----------------------------------------------------------------------------

/* Day rig: a single skydome light driven by ai_physical_sky.
   shapeType is a plain integer paramblock param in this MAXtoA build, NOT an
   enum-by-name. Mapping (0=Point,1=Distant,2=Spot,3=Quad,4=Disc,5=Cylinder,
   6=Skydome,7=Photometric,...) confirmed from ArnoldLight.dlo. NOTE: the
   distant type (1) does not illuminate in this scene -- see Rig1 body. */
-- Define recursive search for the original sun in XRefs
fn FindOrigSun rootNode requireNameMatch = (
	if classOf rootNode == TargetDirectionalLight do (
		if requireNameMatch then (
			local lname = toLower rootNode.name
			if (matchPattern lname pattern:"*sun*") or (matchPattern lname pattern:"*key*") do return rootNode
		) else (
			return rootNode
		)
	)
	for c in rootNode.children do (
		local res = FindOrigSun c requireNameMatch
		if res != undefined do return res
	)
	return undefined
)

fn Rig1 =
(
	/* Day rig: a single skydome light driven by ai_physical_sky + a dedicated distant sun. */
	sky = Arnold_Light shapeType:6 pos:[0,0,575] name:"Arnold Sky"
	if (hasProperty sky "texmap") do sky.texmap = sky_map
	if (hasProperty sky "useTexmap") do sky.useTexmap = true
	-- Increased sky intensity to 0.5 to brighten the scene overall
	sky.intensity = 0.5
	sky.exposure = 0.0
	-- Disable skydome shadows so we only get clean hard shadows from the distant light
	if (hasProperty sky "cast_shadows") do sky.cast_shadows = false
	if (hasProperty sky "castShadows") do sky.castShadows = false

	-- Re-investigate the dead distant light with a targeted light variant
	local sunTarg = TargetObject pos:[0,0,0] name:"Arnold Sun.Target"
	sun = Arnold_Light shapeType:1 pos:[-474, -352, 575] name:"Arnold Sun"
	sun.intensity = 1.0
	sun.exposure = 0.0
	if (hasProperty sun "cast_shadows") do sun.cast_shadows = true
	if (hasProperty sun "castShadows") do sun.castShadows = true
	
	-- Assign LookAt constraint to make it a targeted light variant
	sun.rotation.controller = LookAt_Constraint()
	sun.rotation.controller.appendTarget sunTarg 100
	sun.rotation.controller.target_axis = 2 -- Z axis
	sun.rotation.controller.target_axisFlip = true -- point -Z at target (Max default for lights)
	sun.rotation.controller.viewline_length_abs = false

	-- Find the original MR sun to copy its EXACT position, target, and hierarchy (so it rotates with the camera)
	local origSun = undefined
	for x = 1 to xrefs.getXRefFileCount() do (
		origSun = FindOrigSun (xrefs.getXRefFile x).tree true
		if origSun != undefined do exit
	)
	if origSun == undefined do (
		for x = 1 to xrefs.getXRefFileCount() do (
			origSun = FindOrigSun (xrefs.getXRefFile x).tree false
			if origSun != undefined do exit
		)
	)

	if origSun != undefined then (
		-- Disable the original so it doesn't double-light Arnold
		origSun.on = false
		
		sun.pos = origSun.pos
		if origSun.target != undefined do (
			sunTarg.pos = origSun.target.pos
		)
		sun.parent = origSun.parent
		sunTarg.parent = origSun.parent
		sky.parent = origSun.parent
	) else (
		-- Fallback if no XRef sun exists: parent to TB2CameraHandle directly to ensure rotation works
		local rigRoot = getNodeByName "TB2CameraHandle"
		if rigRoot != undefined do (
			sun.parent = rigRoot
			sunTarg.parent = rigRoot
			sky.parent = rigRoot
		)
	)

	-- Make the physical sky visible behind the geometry
	FnSetSkyBackground()
)

/* Maxis night rig. */
fn Rig3 =
(
	sky = Arnold_Light shapeType:6 pos:[0,0,575] name:"Arnold Sky | Maxis nite"
	if (hasProperty sky "texmap") do sky.texmap = sky_map
	if (hasProperty sky "useTexmap") do sky.useTexmap = true
	sky.intensity = 0.025
	sky.exposure = 0.0
	sky.color = (color 105 101 255)
	FnSetSkyBackground()
)

/* Dark night rig. */
fn Rig4 =
(
	sky = Arnold_Light shapeType:6 pos:[0,0,575] name:"Arnold Sky | Dark nite"
	if (hasProperty sky "texmap") do sky.texmap = sky_map
	if (hasProperty sky "useTexmap") do sky.useTexmap = true
	sky.intensity = 0.015
	sky.exposure = 0.0
	sky.color = (color 41 41 85)
	FnSetSkyBackground()
)

-----------------------------------------------------------------------------
--	Tone mapping (replaces the old GC1/GC2 ExposureControl calls)
-----------------------------------------------------------------------------
--
--	NOTE on values: Arnold's imager_exposure.exposure is in EV/stops (0 = neutral,
--	+1 doubles brightness). The old Mental-Ray constants (10.0 day / 5.0 night)
--	were on a totally different scale and would clip everything to white in Arnold
--	(2^10 ~ 1000x over-exposed). Use Arnold-appropriate values instead.

/* Day exposure settings: sun + sky provide plenty of light, keep near neutral. */
fn GC1 = FnSetExposureImager 0.0 2.2

/* Night exposure settings: scene is dim, lift exposure a few stops. */
fn GC2 = FnSetExposureImager 3.0 2.2

-----------------------------------------------------------------------------
--	Global illumination / sampling (replaces the old FG1 final-gather call)
-----------------------------------------------------------------------------

/* Arnold GI / sampling settings */
fn FG1 =
(
	local myRen = renderers.current
	-- These property names exist on the MAXtoA renderer in this build (confirmed
	-- via diagnostic). Guard each one so we degrade gracefully if a future build
	-- renames it.

	-- Anti-aliasing: AA_samples is the primary edge-quality control. Default is 3,
	-- which can look pixelated on the small BAT renders. Bump to 6 for clean edges.
	if (hasProperty myRen "AA_samples") do myRen.AA_samples = 6

	-- GI / indirect sampling.
	if (hasProperty myRen "GI_diffuse_samples") do myRen.GI_diffuse_samples = 3
	if (hasProperty myRen "GI_specular_samples") do myRen.GI_specular_samples = 2
	if (hasProperty myRen "GI_sss_samples") do myRen.GI_sss_samples = 2
	if (hasProperty myRen "GI_volume_samples") do myRen.GI_volume_samples = 2
)

--------------------------------------------------------------------------------------
--	Apply physical-sky parameters using the REAL ai_physical_sky property names
--	(confirmed from the scene dump): intensity, sky_tint, sun_tint, sun_size,
--	enable_sun, turbidity, ground_albedo.
--
--	We keep the old Mental-Ray-style call signature (so SetDay/SetMaxisNite/
--	SetDarkNite don't change) but map each argument onto the real property.
--	  multiplier   -> intensity
--	  haze         -> turbidity
--	  saturation   -> (no direct equivalent; folded into sky_tint, left as-is)
--	  groundColor  -> ground_albedo (a Point3/color in ai_physical_sky)
--	  sunIntensity -> (no per-sun intensity; enable_sun toggles the sun disc)
--	  sunGlow      -> (no equivalent)
--	  sunScale     -> sun_size
--------------------------------------------------------------------------------------
fn FnApplySkyMapParams multiplier haze horizonHeight saturation groundColor sunIntensity sunGlow sunScale =
(
	if sky_map == undefined do return ok

	if (hasProperty sky_map "intensity") do sky_map.intensity = multiplier
	if (hasProperty sky_map "turbidity") do sky_map.turbidity = haze
	if (hasProperty sky_map "sun_size") do sky_map.sun_size = sunScale
	if (hasProperty sky_map "enable_sun") do sky_map.enable_sun = (sunIntensity > 0.0)

	-- ground_albedo is a Point3/color (not a scalar) in ai_physical_sky.
	if (hasProperty sky_map "ground_albedo") do
		sky_map.ground_albedo = groundColor

	ok
)

--------------------------------------------------------------------------------------
--	Creates the Day Rig and sets everything for a day render scene.
--------------------------------------------------------------------------------------
fn SetDay =
(
	SetRigLayerVisibility()
	ClearRig()
	gCameraRig.SetCam 5 1 updateViewport:false
	local RigXref = xrefs.getXrefFile 1
	if RigXref != undefined do RigXref.hidden = true

	Rig1()
	GC1()
	FG1()
	SetUnits()

	-- Disable the skydome's internal physical-sky sun (sunIntensity = 0.0).
	-- We now rely on the dedicated 'Arnold Sun' (targeted distant light) created in Rig1
	-- to provide the hard directional light and shadows, which is fixed in world space.
	FnApplySkyMapParams 2.0 3.0 0.0 1.0 (color 20 19 18) 0.0 1.0 4.0

	-- IMPORTANT: do NOT parent the sun/sky to $TB2CameraHandle. The camera rig
	-- rotates TB2CameraHandle by 90 deg per export view to orbit the cameras; if
	-- the sun were its child, the sun would orbit too, making the shadow fall the
	-- same way in every view. For SimCity 4 the sun is at a fixed compass heading
	-- in the game world, so the lights MUST stay fixed in world space.
	-- freeze $TB2CameraHandle
	-- hide $TB2CameraHandle
	(LayerManager.getLayer 0).current = true
)

fn SetMaxisNite =
(
	SetRigLayerVisibility()
	ClearRig()
	gCameraRig.SetCam 5 1 updateViewport:false
	local RigXref = xrefs.getXrefFile 1
	if RigXref != undefined do RigXref.hidden = true

	Rig3()
	GC2()
	FG1()
	SetUnits()

	-- Note: the old Mental-Ray sky multipliers (0.002 etc.) would crush Arnold's
	-- physical_sky texture to near-black. The night darkness here comes from the
	-- skydome LIGHT's low intensity (0.025 in Rig3); the texture intensity stays
	-- at 1.0 so the night-sky tint still shows.
	FnApplySkyMapParams 1.0 0.0 -7.0 0.75 (color 38 33 45) 0.0 0.0 0.0

	-- Lights stay fixed in world space (see SetDay comment).
	-- freeze $TB2CameraHandle
	-- hide $TB2CameraHandle
	(LayerManager.getLayer 0).current = true
)

fn SetDarkNite =
(
	SetRigLayerVisibility()
	ClearRig()
	gCameraRig.SetCam 5 1 updateViewport:false
	local RigXref = xrefs.getXrefFile 1
	if RigXref != undefined do RigXref.hidden = true

	Rig4()
	GC2()
	FG1()
	SetUnits()

	FnApplySkyMapParams 1.0 0.0 -7.0 1.0 (color 15 13 18) 0.0 0.0 0.0

	-- Lights stay fixed in world space (see SetDay comment).
	-- freeze $TB2CameraHandle
	-- hide $TB2CameraHandle
	(LayerManager.getLayer 0).current = true
)

--------------------------------------------------------------------------------------
--	Setup is the entry point wired to the "Setup" button. It must confirm that
--	Arnold is available before constructing any Arnold objects -- this is what
--	stops the "call needs function or class, got: undefined" error at its source.
--------------------------------------------------------------------------------------
fn Setup =
(
	if (not FnArnoldAvailable()) do return false

	ClearRig()
	SetupSky()
	SetDay()
	-- SetupGround()
	return true
)
