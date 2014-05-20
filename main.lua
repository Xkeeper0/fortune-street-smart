

	require "map"
	require "squaretypes"
	require "districtcolors"

	function pointInBox(x, y, bX, bY, bW, bH)

		if (x >= bX) and (x < (bX + bW)) and (y >= bY) and (y < (bY + bH)) then
			return true
		else
			return false
		end
	end


	function angleMove(x, y, a, r)

		local xM	= x + math.sin(math.rad(a)) * r
		local yM	= y + math.cos(math.rad(a)) * r

		return xM, yM

	end



	function love.load()
		gridSize		= 50
		gridScale		= gridSize / 64
		mapBaseX		= 700 - gridSize * .5
		mapBaseY		= 400 - gridSize * .5


		local mapBaseDirectory	= "mapdata/"
		mapDirectory	= love.filesystem.getDirectoryItems(mapBaseDirectory)
		maps			= {}
		for k, v in pairs(mapDirectory) do
			local mapNum	= tonumber(v:sub(2, 3))
			maps[mapNum]	= {
				name	= love.filesystem.read(mapBaseDirectory .. v .. "/quest_en.txt"):gsub("[^\r\n]+\r\n[^\r\n]+\r\n([^\r\n]+)\r\n.+", "%1"),
				easy	= mapBaseDirectory .. v .. "/ein_en",
				normal	= mapBaseDirectory .. v .. "/bin_en"
				}
			print("Found map ".. mapNum ..", ".. maps[mapNum]['name'] ..": easy: ".. maps[mapNum]['easy'] .." - normal: ".. maps[mapNum]['normal'])
		end


		currentState	= "maplist"

		mouseX, mouseY	= love.mouse.getPosition()

		drawQueue		= {}

		fData			= ""
		squares			= {}

	end


	function loadMap(map)
		fData			= love.filesystem.read(map)
		squares			= parseSquares(getSquareData(fData))
		districts		= parseDistricts(getDistrictData(fData))

		local maxX, maxY	= 0, 0

		for k, v in pairs(squares) do
			maxX	= math.max(maxX, math.abs(v['xPos']))
			maxY	= math.max(maxY, math.abs(v['yPos']))
		end

		local gridSizePotX	= 500 / (maxX / 4 + 1)
		local gridSizePotY	= 400 / (maxY / 4 + 1)

		print(string.format("Grid vars: maxX %d, maxY %d, gSPX %.2f, gSPY %.2f", maxX, maxY, gridSizePotX, gridSizePotY))

		gridSize		= math.min(gridSizePotX, gridSizePotY)
		gridScale		= gridSize / 64
	end


	function displayMaps()

		love.graphics.print("Pick a map, yo.", 80, 50)

		for i, v in ipairs(maps) do

			local yPos	= 50 + i * 30

			love.graphics.print(string.format("#%d: %s", i, v.name), 100, yPos + 2)
			if crappyButton("Easy", 220, yPos, 100, 20) then
				currentState	= "mapdisplay"
				loadMap(v.easy)
			end

			if crappyButton("Normal", 340, yPos, 100, 20) then
				currentState	= "mapdisplay"
				loadMap(v.normal)

			end

		end

	end


	function crappyButton(label, x, y, w, h)

		local inBox	= pointInBox(mouseX, mouseY, x, y, w, h)

		if inBox then
			love.graphics.setColor(120, 120, 180)
			love.graphics.rectangle("fill", x, y, w, h)
			love.graphics.setColor(255, 255, 255)
			love.graphics.rectangle("line", x, y, w, h)

		else
			love.graphics.setColor( 60,  60, 100)
			love.graphics.rectangle("fill", x, y, w, h)
			love.graphics.setColor(170, 170, 170)
			love.graphics.rectangle("line", x, y, w, h)

		end

		love.graphics.setColor(255, 255, 255)
		love.graphics.printf(label, x, y + (h - 15) / 2, w, "center")

		return inBox and love.mouse.isDown('l')

	end


	function drawSquareMovements(square)

		local baseX	= square['xPos'] / 4 * gridSize + mapBaseX
		local baseY	= square['yPos'] / 4 * gridSize + mapBaseY

		for m = 0, 15 do
			local a			= 360 / 16 * m
			local oX, oY	= baseX + gridSize * .5, baseY + gridSize * .5
			local pX, pY	= angleMove(oX, oY, a, gridSize * .33)
			local pXA, pYA	= angleMove(oX, oY, a, gridSize * 1)

			local mTest		= math.fmod(m + 15, 16) + 1

			if (square['moveMask']:sub(mTest, mTest) == "1") then
				love.graphics.setColor(255, 255, 255)
			else
				love.graphics.setColor(80, 80, 80, 100)
			end

			love.graphics.line(pX, pY, pXA, pYA)
			--love.graphics.print(a .. square['moveMask']:sub(m + 1, m + 1), pXA, pYA, math.rad(-a))
		end

		love.graphics.setColor(255, 255, 255)


	end



	function drawSquareDetails(square)

		love.graphics.rectangle("line", 10, 10, 190, 490)

		if square['type'] == 18 then
			destSquare	= square['extra']:byte(1)
			local dBaseX, dBaseY	= getSquarePosition(squares[destSquare])

			love.graphics.rectangle("line", dBaseX - gridSize * .1, dBaseY - gridSize * .1, gridSize * 1.2, gridSize * 1.2)

		end

		love.graphics.print(string.format("%s\n%s", square['name'], SquareTypes[square['type']] and SquareTypes[square['type']]['name'] or "UNKNOWN"), 15, 15)


		if square['type'] == 1 or (square['value'] ~= 0 or square['price'] ~= 0) then
			love.graphics.print(string.format("Value: %d\nPrices: %d", square['value'], square['price']), 15, 55)
		end

		if square['type'] == 1 or square['type'] == 2 then
			love.graphics.print(string.format("District %d (%s)", square['district'], districts[square['district']]['name']), 15, 95)
		end

		love.graphics.print(square['moveMaskAll']:gsub("(%d+ %d+) ", "%1\n"):gsub("0", "- "), 15, 125)

		love.graphics.print(hexdump(square['extra']), 15, 400)

	end



	function getSquarePosition(square)

		local baseX	= square['xPos'] / 4 * gridSize + mapBaseX
		local baseY	= square['yPos'] / 4 * gridSize + mapBaseY

		return baseX, baseY

	end



	function drawSquare(square)

		local baseX, baseY = getSquarePosition(square)

		love.graphics.setColor(180, 180, 180)

		if SquareTypes[square['type']] and SquareTypes[square['type']]['image'] then
			love.graphics.draw(SquareTypes[square['type']]['image'], baseX, baseY, 0, gridScale, gridScale)
		end

		if (square['type'] == 1 or square['type'] == 2) and DistrictColors[square['district']] then
			love.graphics.setColor(DistrictColors[square['district']])
		else
			love.graphics.setColor(255, 255, 255)
		end

		love.graphics.rectangle("line", baseX, baseY, gridSize - 1, gridSize - 1)

		love.graphics.setColor(255, 255, 255)

		if square['type'] == 1 then
			love.graphics.printf(square['value'] .."\n".. square['price'], baseX, baseY + gridSize - 28, gridSize, "center")
		end

		if pointInBox(mouseX, mouseY, baseX, baseY, gridSize, gridSize) then
			love.graphics.print(string.format("%02x", square['id']), baseX + 3, baseY + 3)
			table.insert(drawQueue, { func = drawSquareMovements, args = square})
			table.insert(drawQueue, { func = drawSquareDetails, args = square})
		end

	end




	function love.update(dt)

		mouseX, mouseY	= love.mouse.getPosition()


	end



	function love.draw()

		if currentState == "maplist" then
			displayMaps()

		else

			for k, v in pairs(squares) do

				drawSquare(v)

			end

			if crappyButton("Back", 1100, 10, 90, 20) then
				currentState	= "maplist"
			end
		end


		for k, v in ipairs(drawQueue) do
			v.func(v.args)
		end

		drawQueue	= {}

	end