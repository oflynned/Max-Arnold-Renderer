--------------------------------------------------------------------------------
--	Script file guard
--	Examine its value to see how many times the script was run.
--------------------------------------------------------------------------------
if (guardModelNames == undefined) then
(
global guardModelNames = 0
)	

 guardModelNames += 1

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
FnTB2FileInOnce "CPStringUtils.ms"		guardStringUtils

--------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--	struct stModelName 
-- a little class to handle the building file naming conventions
--------------------------------------------------------------------------------

struct stModelName 
(
	--	Class constants and variables
	compassNames 			= #("S","W","N","E","NS","EW","X"),	-- lookup table for naming the rotations
	nameParts 				= #(),										-- Human readable sections of the Max filename
	destPath 				= "",
	tempSubDir 				= ((getDir #export) + "\\Temp\\"),
	zoom 						= 1,											-- current zoom
	rot 						= 1,											-- current rotation
	mUseNamingConvention = false,
	
	kPropertyFileName 	= "File Name",
	kPropertyModelID 		= "Model ID",
	--	S3D type IDs
	kIntS3DTypeID			= (HexStrToInt "0x5ad0e817"),
	kIntBuildingGroupID	= (HexStrToInt "0xbadb57f1"),

	--	FSH type ID
	kIntFSHTypeID			= (HexStrToInt "0x7ab50e44"),
	kIntFSHGroupID			= (HexStrToInt "0x1abe787d"),
	
	---------------------------------------------------------------------------------------------------
	-- Function:	Destination 																								
	-- Param:		which:#final																								
	-- Desc:			Returns the folder to put things in this class tracks two possible paths 				
	-- 				for the filenames it generates one is a temp folder under the destination				
	-- 				the which parameter chooses where the filename ends up										
	---------------------------------------------------------------------------------------------------
	fn Destination which:#final = 
	(
			return destPath
	),

	----------------------------------------------------------------------------------------------------
	-- Function:	InitUsingNamingConvention							
	-- Param:		maxName 					- name of the Max file	
	-- Param:		dest						- destination folder		
	-- Param:		modelType				- model type				
	----------------------------------------------------------------------------------------------------
--CP NOT SURE IF THIS FUNCTION EVER GETS CALLED
	fn InitUsingNamingConvention maxName dest modelType = 
	(	
		-- parse out portions of the filename														
		nameParts 	= filterstring (getfilenamefile maxName) kNamePartDelim
		destPath 	= dest
		
		-- Verify format of the file name															
		if (nameParts.count != 3) do 
		(
			FnErrorMessage ("The MAX file name: \"" + maxName +"\" does not follow the naming convention.")
			return false
		)
		if ((nameParts[3].count != 4) or (not (verifyHex nameParts[3]))) do 
		(
			FnErrorMessage ("\"" + maxName + "\"\n" + nameParts[3] + " is not a proper GUID id.")
			return false
		)
		
		-- Have to init tempDir after destPath since Destination() refers to destPath	
		local tempDir = (Destination which:#temp)
		local tempDir = gTempPathCP
		
		
		-- Make sure it exists for later																
		if (not doesFileExist tempDir) do 
		(
			--NOT AVAILABLE IN GMAX: makeDir tempDir
--CP   ITS AVAILABLE IN 3DSMAX
			makeDir tempDir
			return false
		)
		
		-- Hack the new naming convention in : swap nameParts 1 & 3
		local tmpStr = nameParts[3]
		nameParts[3] = nameParts[1]
		nameParts[1] = tmpStr
		
		if (modelType==#building) then
			nameParts[1] += "0"
		else
			nameParts[1] += "1"
		
		return true
	),

	----------------------------------------------------------------------------------------------------
	-- Function:	InitUsingFileProperties										
	-- Param:		maxName 					- name of the Max file	
	-- Param:		dest						- destination folder		
	-- Param:		modelType				- model type				
	----------------------------------------------------------------------------------------------------
	fn InitUsingFileProperties maxName dest modelType = 
	(
		local updateID 	= false
		local modelID

		destPath 	= dest
		nameParts 	= #()

		--	Look for Model ID in file properties						
		
		local typeIndex = (fileProperties.findProperty #custom kPropertyModelID)
		
		if (typeIndex > 0) then 
		(
			modelID = fileProperties.getPropertyValue #custom typeIndex
		)
		
		if (modelID == undefined) then
		(
			updateID		= true
		)

		
		--	Check if the file name changed								
		--	If so, changed the ID											
				
		if (not updateID) then
		(
			typeIndex = (fileProperties.findProperty #custom kPropertyFileName)
			if (typeIndex > 0) then 
			(
				local fileName = fileProperties.getPropertyValue #custom typeIndex

				if (fileName == undefined or fileName != maxName) then 
				(
					updateID = true
				)
			)
			else
			(
				updateID = true
			)
		)
				
		if updateID then
		(
             modelID = "0x5ad0e817-0x" + gGroupIDCP + "-0x" + gInstanceIDCP
		)
			
		if (modelID == undefined) then
		(
			return false
		)

		local guids 	= filterstring modelID kNamePartDelim

		if (guids.count != 3) then
		(
			guids 	= filterstring modelID "-"
		)
		if (guids.count != 3) then
		(
			guids 	= filterstring modelID "_"
		)
		
		if (guids.count != 3) then
		(
			return false
		)

		local idx 

		for idx in 1 to 3 do
		(
			if (not (VerifyHex guids[idx])) then
			(
				return false
			)
		)	
		
		if updateID then
		(
			fileProperties.addProperty #custom kPropertyFileName 	maxName
			fileProperties.addProperty #custom kPropertyModelID 	modelID
		)
		

		kIntS3DTypeID			= HexStrToInt guids[1]
		kIntBuildingGroupID	= HexStrToInt guids[2]
		kIntFSHGroupID			= kIntBuildingGroupID
		
		append nameParts (substring guids[3] 3 4)
		append nameParts (getFileNameFile maxName)
		append nameParts "UserModel"
		
		if (modelType==#building) then
			nameParts[1] += "0"
		else
			nameParts[1] += "1"
		
		return true
	),
	
	----------------------------------------------------------------------------------------------------
	-- Function:	Init 														
	-- Param:		maxName 					- name of the Max file	
	-- Param:		dest						- destination folder		
	-- Param:		modelType:#building	- model type				
	----------------------------------------------------------------------------------------------------
	fn Init maxName dest modelType:#building useNamingConvention:false = 
	(
		mUseNamingConvention = useNamingConvention
		
		if useNamingConvention then
		(
			return InitUsingNamingConvention maxName dest modelType
		)
		else
		(
			return InitUsingFileProperties maxName dest modelType
		)
	),

	----------------------------------------------------------------------------------------------------
	-- Function:	Category
	--	Desc:			Valid only after initialization!
	----------------------------------------------------------------------------------------------------
	fn Category =
	(
		return nameParts[3]
	),
	
	----------------------------------------------------------------------------------------------------
	-- Function:	ModelName
	--	Desc:			Valid only after initialization!
	----------------------------------------------------------------------------------------------------
	fn ModelName =
	(
		return nameParts[2]
	),
	
	----------------------------------------------------------------------------------------------------
	-- Function:	ModelID
	--	Desc:			Valid only after initialization!
	----------------------------------------------------------------------------------------------------
	fn ModelID =
	(
		return nameParts[1]
	),
	
	----------------------------------------------------------------------------------------------------
	-- Function:	ModelIDAsInt
	--	Desc:			Valid only after initialization!
	----------------------------------------------------------------------------------------------------
	fn ModelIDAsInt =
	(
		return (HexStrToInt (ModelID() + "000"))
	),
	
	----------------------------------------------------------------------------------------------------
	-- Function:	ModelGroupIDAsInt
	--	Desc:			Valid only after initialization!
	----------------------------------------------------------------------------------------------------
	fn ModelGroupIDAsInt =
	(
		return kIntBuildingGroupID
	),

	----------------------------------------------------------------------------------------------------
	-- Function:	InstanceID	
	--	Desc:							
	----------------------------------------------------------------------------------------------------
	fn InstanceID = 
	(
		return 		(ModelID())						+
						((zoom-1) as string) 		+
						((rot-1) as string) 			+
						"0"	
	),

	----------------------------------------------------------------------------------------------------
	-- Function:	InstanceID	
	--	Desc:							
	----------------------------------------------------------------------------------------------------
	fn InstanceIDAsInt = 
	(
		return (HexStrToInt (InstanceID()))
	),
	
	----------------------------------------------------------------------------------------------------
	-- Function:	ModelGUID
	--	Desc:			Valid only after initialization!
	----------------------------------------------------------------------------------------------------
	fn ModelGUID =
	(
--cp		return FnMakeResKey kIntS3DTypeID kIntBuildingGroupID (InstanceIDAsInt())
	),	
	
	----------------------------------------------------------------------------------------------------
	-- Function:	ModelOutputName	
	--	Param:		which:#final		
	--	Desc:			the full pathname of the S3D file
	----------------------------------------------------------------------------------------------------

	fn ModelOutputName which:#final = 
	(
		return 		(Destination which:which)	+
						(InstanceID())					+
						"_" 								+
						(ModelName())					+
						"_" 								+
						(Category()) 					+
						"_Z" 								+
						(zoom as string) 				+
						compassNames[rot] 			+
						".S3D" 							
	),

	----------------------------------------------------------------------------------------------------
	-- Function:	TextureOutputIDStr	
	--	Param:		texIndex							
	--	Desc:			
	----------------------------------------------------------------------------------------------------
	fn TextureOutputIDStr texIndex:0 = 
	(
		local highSwizzle = 0
		-- awful kludge to be able to handle more than 16 textures per view
		-- sharing the second digit between rot & the high bit of the texture index
		local digit2 = (texIndex as integer)/16
		texIndex = (mod texIndex 16) as integer
		if (digit2 > 3) then 
		(
			DoMessage ("This building is huge! It's just not going to work!")
		)
		else 
		(
			highSwizzle = digit2 * 4
		)
		
		return guidStr =  (ModelID())											+
								((zoom-1) as string) 							+
								(bit.intAsHex (highSwizzle + (rot-1))) 	+
								(bit.intAsHex texIndex)
	),
	
	----------------------------------------------------------------------------------------------------
	-- Function:	TextureOutputGUID
	--	Param:		texIndex							
	--	Desc:			
	----------------------------------------------------------------------------------------------------
	fn TextureOutputGUID texIndex:0 = 
	(
		local instID = (HexStrToInt (TextureOutputIDStr texIndex:texIndex))
--CP THIS HAS BEEN CHANGED TO USE THE NEW FUNCTION SO THE 0x DOESNT SHOW UP IN THE FILENAME		
		
		return FnMakeResKeyCP kIntFSHTypeID kIntFSHGroupID instID
	),
	
	----------------------------------------------------------------------------------------------------
	-- Function:	NightTextureIDStr	
	--	Param:		texIndex							
	--	Desc:			
	----------------------------------------------------------------------------------------------------
	fn NightTextureIDStr texIndex:0 = 
	(
		local guid4 		= (substring (ModelID()) 1 4)
		local typeDigit 	= ((ModelID())[5] as integer) + 8
		local highSwizzle = 0
		-- awful kludge to be able to handle more than 16 textures per view
		-- sharing the second digit between rot & the high bit of the texture index
		local digit2 = (texIndex as integer)/16
		texIndex = (mod texIndex 16) as integer
		if (digit2 > 3) then 
		(
			DoMessage ("This building is huge! It's just not going to work!")
		)
		else 
		(
			highSwizzle = digit2 * 4
		)
		
		return guidStr =  guid4 												+
								(bit.intAsHex typeDigit) 						+
								((zoom-1) as string) 							+
								(bit.intAsHex (highSwizzle + (rot-1))) 	+
								(bit.intAsHex texIndex)

	),
	
	----------------------------------------------------------------------------------------------------
	-- Function:	NightTextureGUID
	--	Param:		texIndex							
	--	Desc:			
	----------------------------------------------------------------------------------------------------
	fn NightTextureGUID texIndex:0 = 
	(
		local instID = (HexStrToInt (NightTextureIDStr texIndex:texIndex))
--CP THIS HAS BEEN CHANGED TO USE THE NEW FUNCTION SO THE 0x DOESNT SHOW UP IN THE FILENAME		
		return FnMakeResKeyCP kIntFSHTypeID kIntFSHGroupID instID
	),
	
	----------------------------------------------------------------------------------------------------
	-- Function:	TextureOutputName	
	--	Param:		texIndex				
	--	Param:		which:#final		
	--	Param:		wext:".BMP"			
	--	Desc:			the full pathname of the n-th texture file
	----------------------------------------------------------------------------------------------------
--CP  .BMP HAS BEEN CHANGED FROM .TGA
	fn TextureOutputName texIndex which:#temp ext:".BMP" = 
	(
		local highSwizzle = 0
		-- awful kludge to be able to handle more than 16 textures per view
		-- sharing the second digit between rot & the high bit of the texture index
		local digit2 = (texIndex as integer)/16
		texIndex = (mod texIndex 16) as integer
		if (digit2 > 3) then 
		(
			DoMessage ("This building is huge! It's just not going to work!")
		)
		else 
		(
			highSwizzle = digit2 * 4
		)
		
		return 	(Destination which:which) 						+
--CP					(ModelID())											+
--CP					((zoom-1) as string) 							+
--CP					(bit.intAsHex (highSwizzle + (rot-1))) 	+
					(bit.intAsHex texIndex) 						+
--CP					"_" 													+
--CP					(ModelName())										+
--CP					"_" 													+
--CP					(Category())										+
--CP					"_Z" 													+
--CP					(zoom as string) 									+
--CP					compassNames[rot] 								+
					ext 
	),
	
	----------------------------------------------------------------------------------------------------
	-- Function:	NightTextureName	
	--	Param:		texIndex				
	--	Param:		which:#final		
	--	Param:		wext:".BMP"			
	--	Desc:			the full pathname of the n-th texture file
	----------------------------------------------------------------------------------------------------
--CP  .BMP HAS BEEN CHANGED FROM .TGA
	
	fn NightTextureName texIndex which:#temp ext:".BMP" = 
	(
		local guid4 		= (substring (ModelID()) 1 4)
		local typeDigit 	= ((ModelID())[5] as integer) + 8
		local highSwizzle = 0
		-- awful kludge to be able to handle more than 16 textures per view
		-- sharing the second digit between rot & the high bit of the texture index
		local digit2 = (texIndex as integer)/16
		texIndex = (mod texIndex 16) as integer
		if (digit2 > 3) then 
		(
			DoMessage ("This building is huge! It's just not going to work!")
		)
		else 
		(
			highSwizzle = digit2 * 4
		)
		
		return 	(Destination which:which) 						+
					guid4 												+
					(bit.intAsHex typeDigit) 						+
					((zoom-1) as string) 							+
					(bit.intAsHex (highSwizzle + (rot-1))) 	+
					(bit.intAsHex texIndex) 						+
					"_" 													+
					(ModelName())										+
					"_Night_Z" 											+
					(zoom as string) 									+
					compassNames[rot] 								+
					ext 
	),

	---------------------------------------------------------------------------------------------------
	-- Function:	TextureSourceName	
	--	Param:		texIndex				
	--	Param:		oldName				
	--	Desc:			for the model mill, generate a conforming texture name for a given texture name		
	---------------------------------------------------------------------------------------------------
	fn TextureSourceName texIndex oldName = 
	(
		local texFile = (getFilenameFile oldName)
		local texType = (getFilenameType oldName)
		
		return 	(ModelID())						+
					((zoom-1) as string) 		+
					((rot-1) as string) 			+
					(bit.intAsHex texIndex) 	+
					"_" 								+
					(ModelName())					+
					"_" 								+
					texFile 							+
					"_" 								+
					(Category())					+
					"_Z" 								+
					(zoom as string) 				+	
					compassNames[rot] 			+
					texType 
	),
		
	---------------------------------------------------------------------------------------------------
	-- Function:	TempMaxName		
	--	Param:		frameIndex		
	--	Param:		which:#temp		
	--	Desc:								
	---------------------------------------------------------------------------------------------------
	fn TempMaxName frameIndex which:#temp = 
	(
		return (Destination which:which) + "temp" + (frameIndex as string) + ".MAX"
	),
	
	---------------------------------------------------------------------------------------------------
	-- Function:	MeshName			
	--	Param:		texIndex			
	--	Desc:			Name to give to generated materials that will come through as mesh names 
	--					in S3D format (should be useful for debuging)
	---------------------------------------------------------------------------------------------------
	fn MeshName texIndex = 
	(
		return 	(ModelName())			+
					"_" 						+
					(Category())			+
					"_Z" 						+
					(zoom as string) 		+
					compassNames[rot]		+ 
					"_" 						+
					(texIndex as string)
	),
		
	---------------------------------------------------------------------------------------------------
	-- Function:	RenderTempName			
	--	Param:		which:#temp			
	--	Desc:			Name for temporary renderfile (for diced renders)
	---------------------------------------------------------------------------------------------------
	fn RenderTempName which:#temp = 
	(
		return 	(Destination which:which) 	+
					(InstanceID())					+
					"_" 								+
					(ModelName())					+
					"_RenderTemp_Z" 				+
					(zoom as string) 				+
					compassNames[rot] 			+
					".BMP" 
	),
	---------------------------------------------------------------------------------------------------
	--CP  ADDED THE FOLLOWING TO HANDLE THE LIBRARY ALPHA RENDER FILE NAME
	-- Function:	RenderTempAlphaName			
	--	Param:		which:#temp			
	--	Desc:			Name for temporary library alpha renderfile (for diced renders)
	---------------------------------------------------------------------------------------------------
	fn RenderTempAlphaName which:#temp = 
	(
		return 	(Destination which:which) 	+
					(InstanceID())					+
					"_" 								+
					(ModelName())					+
					"_RenderAlphaTemp_Z" 				+
					(zoom as string) 				+
					compassNames[rot] 			+
					"-a.BMP" 
	),
	---------------------------------------------------------------------------------------------------
	--CP  ADDED THE FOLLOWING TO HANDLE THE SECOND NITELIGHT ALPHA RENDER FILE NAME
	-- Function:	NightAlphaTempName			
	--	Param:		which:#temp			
	--	Desc:			Name for temporary nite alpha renderfile (for diced renders)
	---------------------------------------------------------------------------------------------------
	fn NightAlphaTempName which:#temp = 
	(
		return 	(Destination which:which) 	+
					(InstanceID())					+
					"_" 								+
					(ModelName())					+
					"_NightAlphaTemp_Z" 				+
					(zoom as string) 				+
					compassNames[rot] 			+
					"-a.BMP" 
	),


	---------------------------------------------------------------------------------------------------
	-- Function:	NightRenderTempName			
	--	Param:		which:#temp			
	--	Desc:			Name for temporary night mask (diffuse) (for diced renders) nightlight and library render
	---------------------------------------------------------------------------------------------------
	fn NightRenderTempName which:#temp = 
	(
		return 	(Destination which:which) 	+
					(InstanceID()) 				+
					"_" 								+
					(ModelName()) 					+
					"_NightMaskTemp_Z" 			+
					(zoom as string) 				+
					compassNames[rot] 			+
					".BMP"
	)
)
