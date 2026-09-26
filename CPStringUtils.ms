--------------------------------------------------------------------------------
--	Script file guard
--	Examine its value to see how many times the script was run.
--------------------------------------------------------------------------------
 if (guardStringUtils == undefined) then
 (
	global guardStringUtils = 0
 )	

 guardStringUtils += 1

--------------------------------------------------------------------------------
--	Make sure TB2 starup was executed first.
--------------------------------------------------------------------------------
 if (guardTB2Startup == undefined) then
 (
	global guardTB2Startup = 0
	FileIn ((getDir #startupScripts) + "\\CPTB2Startup.ms")
 )

kNamePartDelim	=	"_"

----------------------------------------------------------------------------------------------------
--	Function: 	FnStrCompare 
--	Param:		s1 
--	Param:		s2 
----------------------------------------------------------------------------------------------------

fn FnStrCompare s1 s2 caseSensitive:false = 
(
	if (s1 == undefined or s2 == undefined) then
	(
		return false
	)
	
	if caseSensitive then
	(
		return s1 == s2
	)
	else
	(
	return matchPattern s1 pattern:s2
	)
)

----------------------------------------------------------------------------------------------------
--	Function: 	verifyHex
--	Param:		hexStr 
----------------------------------------------------------------------------------------------------

fn VerifyHex hexStr = 
(
	if ((substring hexStr 1 2) == "0x") then
	(
		hexStr = (substring hexStr 3 (hexStr.count - 2))
	)

	local hexDigits = "0123456789abcdefABCDEF"
		
	for index = 1 to hexStr.count do 
	(
		if ((findstring hexDigits hexStr[index])==undefined) then return false
	)
		
	true	-- implicit return value
)

----------------------------------------------------------------------------------------------------
--	Function: 	hexStrToInt 
--	Param:		hexStr 
----------------------------------------------------------------------------------------------------
fn HexStrToInt hexStr = 
(
	
	if ((substring hexStr 1 2) == "0x") then
	(
		hexStr = (substring hexStr 3 (hexStr.count - 2))
	)
	
	if ((hexStr.count <=8) and (VerifyHex hexStr)) then 
	(
		local hexDigits = "0123456789abcdefABCDEF"
		local index
		local digit
		local result = (findstring hexDigits hexStr[1])-1
		
		--if ((hexStr.count==8) and (result > 7)) then 
		--	return undefined -- MaxScript unsigned stupidity
		
		for index = 2 to hexStr.count do 
		(
			digit = (findstring hexDigits hexStr[index])
			if (digit > 16) do 
				digit -= 6 -- handle caps
			
			result = result*16 + (digit-1)
		)
	
		return result
	)
	else
	(
		return undefined
	)
)

----------------------------------------------------------------------------------------------------
--	Function: 	FnRightWidthSubString 
--	Param:		longString 
--	Param:		pixelWidth 
-- 	Desc:		Takes the rightmost part of a long string that will fit in a given pixel width.
-- 				This is useful for displaying the relevant part of a long pathname in a UI control.
----------------------------------------------------------------------------------------------------

fn FnRightWidthSubString longString pixelWidth = 
(
	local stringExtents = GetTextExtent longString
	
	if (stringExtents.x <= pixelWidth) then 
	(
		-- the easy case
		return longString
	)
	else 
	(
		local stepSize = longString.count
		local leftIndex = 1
		local resultString
		
		while (stepSize > 1) do 
		(
			stepSize = stepSize/2
			if (stringExtents.x > pixelWidth) then
				leftIndex += stepSize
			else
				leftIndex -= stepSize
			
			resultString = substring longString leftIndex longString.count
			
			stringExtents = GetTextExtent resultString
		)
		
		-- one more
		if (stringExtents.x > pixelWidth) do 
		(
			resultString = substring longString (leftIndex+1) longString.count
		)
		
		return resultString
	)
)

----------------------------------------------------------------------------------------------------
--	Function: 	FnCountRight 
--	Param:		str
--	Param:		charToCount 
----------------------------------------------------------------------------------------------------
fn FnCountRight str charToCount =
(
	cnt = 0
	
	for i = str.count to 0 by -1 do
	(
		if (str[i] == charToCount) then
		(
			cnt += 1
		)
		else
		(
			exit
		)
	)
	
	return cnt
)

----------------------------------------------------------------------------------------------------
--	Function: 	FnTrimRight 
--	Ref Param:	&str
--	Param:		charToTrim 
----------------------------------------------------------------------------------------------------
fn FnTrimRight &str charToTrim =
(
	cnt = FnCountRight str charToTrim 
	
	if (cnt > 0) then
	(
		str = substring str 1 (str.count - cnt)
		return true
	)

	return false
)

----------------------------------------------------------------------------------------------------
--	Function: 	FnAppendToStr 
--	Ref Param:	&str
--	Param:		charToAppend 
--	Opt Param:	cnt:1
----------------------------------------------------------------------------------------------------
fn FnAppendToStr &str charToAppend cnt:1 =
(
	toAppend = cnt - FnCountRight str charToAppend
	
	if (toAppend > 0) then 
	(
		for i = 1 to toAppend do
		(
			str += charToAppend
		)
	)
	else if (toAppend < 0) then
	(
		str = substring str 1 (str.count + toAppend)
	)
	
	return toAppend 
)

----------------------------------------------------------------------------------------------------
--	Function: 	FnMakeResKey 
--	Ref Param:	&str
--	Param:		charToAppend 
--	Opt Param:	cnt:1
----------------------------------------------------------------------------------------------------
fn FnMakeResKey typeGUID groupGUID instanceGUID =
(
	--return MakeDATKey typeGUID groupGUID instanceGUID
	return 	"0x" + (bit.intAsHex typeGUID)  + kNamePartDelim +
				"0x" + (bit.intAsHex groupGUID) + kNamePartDelim +
				"0x" + (bit.intAsHex instanceGUID)
)


----------------------------------------------------------------------------------------------------
-----CP THIS IS AN ALTERNATIVE IMPLEMENTATION, TO GENERATE TEXTURENAMES
--	Function: 	FnMakeResKeyCP
--	Ref Param:	&str
--	Param:		charToAppend 
--	Opt Param:	cnt:1
----------------------------------------------------------------------------------------------------
fn FnMakeResKeyCP typeGUID groupGUID instanceGUID =
(
	
	return 	(bit.intAsHex typeGUID)  + kNamePartDelim +
				(bit.intAsHex groupGUID) + kNamePartDelim +
				(bit.intAsHex instanceGUID)
	
)

