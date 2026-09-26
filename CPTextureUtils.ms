--------------------------------------------------------------------------------
--	Script file guard
--	Examine its value to see how many times the script was run.
--------------------------------------------------------------------------------
if (guardTextureUtils == undefined) then
(
	global guardTextureUtils = 0
)	

guardTextureUtils += 1

--------------------------------------------------------------------------------
--	Make sure TB2 starup was executed first.
--------------------------------------------------------------------------------
if (guardTB2Startup == undefined) then
(
	global guardTB2Startup = 0
	FileIn ((getDir #startupScripts) + "\\CPTB2Startup.ms")
)

--------------------------------------------------------------
-- struct SceneTextures
--------------------------------------------------------------
struct SceneTextures
(
	mapfiles = #(),
	
	---------------------------------------------------------
	--	Function:	AddMap
	---------------------------------------------------------
	fn AddMap mapFile = 
	( 
		local mapfileN 	= mapfile as string 
		local index		= finditem mapfiles mapfileN 
		
		if index == 0 do 	-- add only unique 
		(
			append mapfiles mapfileN 
		)
	),

	fn Clear =
	(
		mapfiles=#()
		ok
	),
	
	fn Init which:  =
	(
		Clear()

		if (which == unsupplied) then
		(
			enumeratefiles addmap 
		)
		else if (which == #usedOnly) then
		(
			for curNode in $geometry do 
			(
				enumeratefiles curNode AddMap -- #localOnly 
			)
		)		
		else
		(
			enumeratefiles addmap which 
		)

		sort mapfiles 
		ok
	),

	fn PrintMaps =
	(
		print ("Count = " + (mapfiles.count as string))
		cnt = 1
		for mapfile in mapfiles do 
		(
			print ((cnt as string) + ":\t" + (mapfile as string))
			cnt += 1
		)
	)
)

