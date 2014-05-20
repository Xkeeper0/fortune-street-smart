
	-- 0x88: Word for suggested target value
	-- 0x7C: Starting cash values


	function toBinary(n, l)

		out		= ""
		while n >= 1 do
			out	= math.floor(math.fmod(n, 2)) .. out
			n	= math.floor(n / 2)
		end

		local p	= math.ceil(out:len() / 8) * 8

		return string.format("%0".. (l and l or p) .."s", out)

	end




	function hexdump(str, showDec)

		local len	= str:len()
		local out	= ""
		local out2	= ""
		for i = 1, len do
			out		= out .. string.format("%02x ", str:byte(i))
			if (i % 4 == 1) then
				out2	= out2 .. string.format("%11d  ", str:getWord(i - 1))
			end
			if (i % 4 == 0) then
				out	= out .. " "
			end

		end

		return out .. (showDec and ("\n".. out2) or "")
	end



	function string:getWord(ofs, l, signed)

		return bytesToNumber(self:sub0(ofs, l and l or 4), signed and true or false)

	end



	-- s = start (0-ind), l = length
	function string:sub0(s, l)

		return self:sub(s + 1, l and (s + l) or nil)

	end



	function bytesToNumber(word, signed)

		local n, i	= 0
		local l	= word:len()
		for i = 1, l do
			n	= n + word:byte(i) * 256 ^ (i - 1)
		end

		if signed then
			if n >= (2 ^ (l * 8 - 1)) then
				n	= n - (2 ^ (l * 8))
			end
		end

		return n

	end


	function getDistrictData(data)
		-- District start pointer is at 0x90-0x93
		-- Square start pointer is at 0x94-0x97

		-- Get data from <district start pointer> to <square start pointer - 1>
		local districtPointer	= data:getWord(0x90)
		local squarePointer		= data:getWord(0x94)

		print(string.format("DP: %04X - SP: %04X", districtPointer, squarePointer))

		return data:sub0(districtPointer, squarePointer - districtPointer)



	end

	function getSquareData(data)
		local squarePointer		= data:getWord(0x94)

		return data:sub0(squarePointer)


	end


	function parseDistricts(data)

		-- 30 bytes:	District name
		-- 1 byte: District ID
		-- 1 byte: District color
		-- 8 bytes: District squares (FF: not used)

		local len		= data:len()
		local districts	= len / 40
		print("Len: ".. len)
		assert(math.fmod(len, 40) == 0)

		local districtArray	= {}

		for i = 1, districts do

			local dData		= data:sub0(40 * (i - 1), 40)

			-- Grab the name and cut off the nulls
			local dName		= dData:sub0(0, 30):gsub("%z+$", "")
			local dId		= dData:byte(31)
			local dColor	= dData:byte(32)
			districtArray[dId]	= {
				name		= dName,
				color		= dColor,
				}

			print(string.format("%d: %-30s (id %d, col %d)", i, dName, dId, dColor))
		end

		return districtArray

	end



	function parseSquares(data)

		local len		= data:len()
		local squares	= len / 76
		print(squares)

		local squareA	= {}

		for i = 1, squares do
			local sData		= data:sub0(76 * (i - 1), 76)
			local sName		= sData:sub0(0, 27):gsub("%z+$", "")
			local sExtra	= sData:sub0(28, 4)
			local sType		= sData:getWord(32, 1)
			local sDistrict	= sData:getWord(33, 1)
			local sPrice	= sData:getWord(34, 2)
			local sValue	= sData:getWord(36, 4)
			local sXPos		= sData:getWord(40, 1, true)
			local sYPos		= sData:getWord(41, 1, true)


			local sUnk		= sData:sub0(32)
			if sName == "" then
				sName		= "<null>"
			end
			print(string.format("%2x: %-28s (Vl: %4d; Pc: %4d; Type: %2x; D: %2x; X: %3d; Y: %3d)",
				i - 1,
				sName,
				sValue,
				sPrice,
				sType,
				sDistrict,
				sXPos,
				sYPos
				))
			-- print(hexdump(sUnk, true))

			-- Sorry if you figured this out already, but I thought this over while laying in bed
			--   sleepless.  I don't feel like touching your code so I'll just leave this long
			--   comment explaining things.
			-- <3 ~Inu
			--
			-- So this bitfield we were puzzling over before? There's 17 16-bit integers, yes?
			-- I think I worked out what they're all used for, and why there's a lot of null
			--   bytes in that mess...
			--
			-- So... each of the first 16 integers?  I'm pretty sure they correspond to
			--   what directions you're allowed to move when you move onto the square coming
			--   from that direction.
			-- I'm guessing most of them are just blank because you can't move onto the square
			--   from that direction in the first place, so there's no point filling it in?
			-- And about the seventeenth? I think that's for when you can move in any direction,
			--   via the venture card or warping on the square, or whatever.

			local sFullMoveMask	= ""
			for uDump = 0, 16 do
				for uDumpB = 0, 1 do
					sFullMoveMask	= sFullMoveMask .. toBinary(sData:getWord(42 + 2 * uDump + uDumpB, 1), 8) .. " "
				end
				-- print(hexdump(sData:sub0(42 + 2 * uDump, 2)), sFullMoveMask:gsub("0", "."))
			end

			local uDump	= 16
			local binOut	= ""
			for uDumpB = 0, 1 do
				binOut	= binOut .. toBinary(sData:getWord(42 + 2 * uDump + uDumpB, 1), 8)
			end

			squareA[i - 1]	= {
				id			= i - 1,
				name		= sName,
				value		= sValue,
				price		= sPrice,
				type		= sType,
				district	= sDistrict,
				xPos		= sXPos,
				yPos		= sYPos,
				moveMask	= binOut,
				moveMaskAll	= sFullMoveMask,
				extra		= sExtra
				}


		end

		return squareA
	end



--	local mfile	= io.open("m01-bin_en", "rb");
--	local fdata	= mfile:read("*all");


--	local mword	= fdata:getWord(0x94)


--	local test	= string.char(4, 1, 0, 0)

--	test	= test:getWord(0)

--	parseDistricts(getDistrictData(fdata))

--	squares	= parseSquares(getSquareData(fdata))

