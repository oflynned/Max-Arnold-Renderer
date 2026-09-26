--------------------------------------------------------------------------------
--	Script file guard
--	Examine its value to see how many times the script was run.
--------------------------------------------------------------------------------
if (guardFileUtils == undefined) then
(
	global guardFileUtils = 0
)	

guardFileUtils += 1

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
FnTB2FileInOnce "CPStringUtils.ms"	guardStringUtils
FnTB2FileInOnce "CPTextureUtils.ms"	guardTextureUtils

--------------------------------------------------------------
-- struct FileArray
--------------------------------------------------------------

struct FileArray
(
	m_files = #(),
	
	---------------------------------------------------------
	--	Function:	FindFile 
	---------------------------------------------------------
	fn FindFile fileToFind how:#uniquePath = 
	(
		if (m_files.count == 0) then
		(
			return 0
		)
		
		case how of
		(
			#uniquePath:
			(
				for idx = 1 to m_files.count do 
				(
					if (FnStrCompare m_files[idx] fileToFind) then
					(
						return idx
					)
				)
			)
			
			#uniqueFileName:		
			(
				fileNameToFind = getFileNameFile fileToFind 
				
				for idx = 1 to m_files.count do 
				(
					if (FnStrCompare (getFileNameFile m_files[idx]) fileNameToFind) then
					(
						return idx
					)
				)
			)
			
			#uniqueFileNameWithExt:		
			(
				fileNameToFind = filenameFromPath fileToFind 
				
				for idx = 1 to m_files.count do 
				(
					if (FnStrCompare (filenameFromPath m_files[idx]) fileNameToFind) then
					(
						return idx
					)
				)
			)			
		)
		
		return 0
	),
	
	---------------------------------------------------------
	--	Function:	Clear 
	---------------------------------------------------------
	fn Clear =
	(
		m_files = #()
		ok
	),
	
	---------------------------------------------------------
	--	Function:	AddFile 
	---------------------------------------------------------
	fn AddFile fileToAdd how:#uniquePath = 
	( 	
		index = FindFile fileToAdd how:how
		if (index == 0) then 	-- add only unique 
		(
			append m_files fileToAdd 
			return true
		)
		
		return false
	),
	
	---------------------------------------------------------
	--	Function:	AddFiles 
	---------------------------------------------------------
	fn AddFiles files how:#uniquePath = 
	( 	
		initCount = m_files.count
		
		for file in files do
		(
			AddFile file how:how
		)
		
		return m_files.count - initCount 
	),	

	---------------------------------------------------------
	--	Function:	FillFromDir 
	---------------------------------------------------------
	
	fn FillFromDir root patern:"*" how:#uniquePath recursive:false = 
	(
		AddFiles (getFiles (root + patern)) how:how
		
		if recursive then -- recursion
		(
			dirArray = getDirectories (root + "*")
			
			for dir in dirArray do
			(
				FillFromDir dir patern:patern how:how recursive:recursive
			)
		)
		
		ok
	),
	
	---------------------------------------------------------
	--	Function:	FillFromMax
	---------------------------------------------------------
	
	fn FillFromMax patern:"*" how:#uniquePath which: = 
	(
		textures = SceneTextures()
		textures.Init which:which
		AddFiles textures.mapfiles how:how
		
		ok
	),
	
	---------------------------------------------------------
	--	Function:	PrintFiles 
	---------------------------------------------------------
	fn PrintFiles =
	(
		print ("Count = " + (m_files.count as string))
		cnt = 1
		for file in m_files do 
		(
			print ((cnt as string) + ":\t" + file)
			cnt += 1
		)
	)
)

----------------------------------------------------------------------------------------------------
--	Function: 	FnExistFile 
--	Param:		fname  
----------------------------------------------------------------------------------------------------
fn FnCom fname = 
(
	if (fname == undefined) then 
	(
		return undefined;
	)
	
	return ((getfiles fname).count != 0)
)

----------------------------------------------------------------------------------------------------
--	Function: 	FnExistFile 
--	Param:		fname  
----------------------------------------------------------------------------------------------------
fn FnExistFile fname = 
(
	if (fname == undefined) then 
	(
		return undefined;
	)
	
	return ((getfiles fname).count != 0)
)

----------------------------------------------------------------------------------------------------
--	Function: 	FnDeleteFile 
--	Param:		fname  
-- 	Desc:		WildCard delete.
----------------------------------------------------------------------------------------------------
fn FnDeleteFiles pattern = 
(
	local toDelete = getFiles pattern 
	
	for file in toDelete do
	(
		deleteFile file
	)
	
	ok
)

----------------------------------------------------------------------------------------------------
--	Function: 	FnGetFiles  
--	Ref Param:	&fileArray
--	Param:		root	- root folder
--	Opt Param:	patern:"*"
--	Opt Param:	recursiv:false
----------------------------------------------------------------------------------------------------

fn FnGetFiles &fileArray root patern:"*" recursive:false = 
(
	join fileArray (getFiles (root + patern))
	
	if recursive then -- recursion
	(
		dirArray = getDirectories (root + "*")
		
		for dir in dirArray do
		(
			FnGetFiles &fileArray dir patern:patern recursive:recursive
		)
	)
	
	ok
)

