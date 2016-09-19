--[[Extended functionality for OpenComputes robot,
	for easy movement, navigation and manipulation with inventory.

	Author: Multirez ]]--

local sides = require("sides")
local component = require("component")

local robotExt = { }
local help = { } -- help texts for robotExt will be wrapped at the end

-- region Movement
local pos = { ["x"] = 0, ["y"] = 0, ["z"] = 0 }
setmetatable(pos, {
	__add = function (pos, add) -- the addition of two vectors
		pos.x = pos.x + add.x
		pos.y = pos.y + add.y
		pos.z = pos.z + add.z
		return pos
	end,
	__sub = function (pos, sub) -- the subtraction of two vectors
		pos.x = pos.x - sub.x
		pos.y = pos.y - sub.y
		pos.z = pos.z - sub.z
		return pos
	end,
	__mul = function (pos, m) -- multiplication of vector by a number
		pos.x = pos.x * m
		pos.y = pos.y * m
		pos.z = pos.z * m
		return pos
	end
})
local direction = sides.forward

help.setOrigin = "function() - robot resets its navigation state to (0,0,0), so that the current position as the origin."
function robotExt.setOrigin()
	pos.x, pos.y, pos.z = 0, 0, 0
	direction = sides.forward
end

help.getDir = "function():number - returns value from sides as direction relative the start."
function robotExt.getDir()
	return direction
end

local rotateMap = {
	sides.forward, sides.right, sides.back, sides.left,
	front = 0, right = 1, back = 2, left = -1
} -- the help table for the sides conversion

help.transformDirection = "function(localDirection:number):number - transforms direction from local space to start space."
function robotExt.transformDirection(localDirection)
	if ((direction == sides.forward) or(localDirection < 2)) then
		return localDirection
	end
	local mapIndex = rotateMap[sides[direction]]
	-- self index in rotateMap
	local localMapIndex = rotateMap[sides[localDirection]]
	return rotateMap[(mapIndex + localMapIndex + 8) % 4 + 1]
end

help.inverseTransformDirection = "function(startDirection:number):number - transforms direction from start space to local space."
function robotExt.inverseTransformDirection(startDirection)
	if (startDirection < 2) then
		return startDirection
	end
	local deltaMapIndex = rotateMap[sides[startDirection]] - rotateMap[sides[direction]]
	return rotateMap[(deltaMapIndex + 8) % 4 + 1]
end

help.rotate = "function(side: number[, isStartSpace:bool]):number - rotate robot to the [side] " ..
	"relative the current rotation by default or (if [isStartSpace]=true) relative start rotation. " ..
	"The robot can not rotate to [up] or [down] sides, so function returns the result side for interaction, " ..
	"it's one of {sides.front, sides.up, sides.down}."
function robotExt.rotate(side, isStartSpace)
	if (side < 2) then
		-- error("Wrong [side] for rotation. The robot can not rotate to [up] or [down] sides.")		
		return side
	end
	if (isStartSpace) then
		-- convert to local space
		side = robotExt.inverseTransformDirection(side)
	end
	-- rotate robot
	local i = rotateMap[sides[side]]
	local di = i < 0 and 1 or -1
	while(i ~= 0)do
		component.robot.turn(i > 0)
		i = i + di
	end
	direction = robotExt.transformDirection(side) -- update direction

	return sides.front
end

help.getPos = "function():table{x, y, z} - returns table contains current robot coordinates relative the start position, " ..
	"where x - right, y - up, z - forward directional axes."
-- x = "number - value of X axis of current robot position."}
function robotExt.getPos()
	return { x = pos.x, y = pos.y, z = pos.z }
end

local side2vector = {
	[sides.right] = { x = 1, y = 0, z = 0 },
	[sides.left] = { x = -1, y = 0, z = 0 },
	[sides.up] = { x = 0, y = 1, z = 0 },
	[sides.down] = { x = 0, y = -1, z = 0 },	
	[sides.front] = { x = 0, y = 0, z = 1 },
	[sides.back] = { x = 0, y = 0, z = -1 }
}

help.move = "function(direction:number, distance:number[, isStartSpace:bool]):bool[, number, string] " ..
	"- robot try to move at [distance] of blocks to the [direction] as sides value. " ..
	"If [isStartSpace]=true robot will move relative its rotation at the start, otherwise relative the current rotation. " ..
	"Returns [true] if final movement point has been reached, otherwise [false] and how many blocks has passed and "..
	"describing why moving failed, which will either be 'impossible move', 'not enough energy' or "..
	"the description of the obstacle as robot.detect would return."
function robotExt.move(direction, distance, isStartSpace)
	local moveSide = robotExt.rotate(direction, isStartSpace)
	local moveVector = moveSide < 2 and side2vector[moveSide] or side2vector[robotExt.getDir()]
	local i, isMoved, reason = 0, true, nil
	while(i<distance and isMoved)do
		isMoved, reason = component.robot.move(moveSide)
		i = i + 1
		pos = pos + moveVector
	end	
	if(not isMoved)then
		i = i - 1
		pos = pos - moveVector
		return false, i, reason
	end
	return true
end

-- endregion

--region World interaction

help.swingAt = "function(side:number[, targetSide:number [, sneaky:bool]]):bool[, string] - Makes the robot use the item "..
	"currently in the tool slot against the block or space immediately in [side] of the robot "..
	"in the same way as if a player would make a left-click. [targetSide] - if given the robot will try to 'left-click' "..
	"only on the surface as specified by side, otherwise the robot will try all possible sides. "..
	"Returns [true] if the robot could interact with the block or entity, [false] otherwise. "..
	"If successful the secondary parameter describes what the robot interacted with "..
	"and will be one of 'entity', 'block' or 'fire'."
function robotExt.swingAt(side, targetSide, sneaky)
	local backDir = direction
	side = robotExt.rotate(side)
   isSwing, desrciption = component.robot.swing(side, targetSide, sneaky ~= nil and sneaky ~= false)
	robotExt.rotate(backDir, true)

	return isSwing, desrciption
end

help.detectAt = "function(side:number): bool, string - detects what is directly in [side] of the robot. "..
	"Returns: [true] if the robot if whatever is in [side] of the robot would prevent him from moving "..
	"(a block or an entity), [false] otherwise. The second parameter describes what is in [side] in general "..
	"and is one of either 'entity', 'solid', 'replaceable', 'liquid', 'passable' or 'air'."
function robotExt.detectAt(side)
	local backDir = direction
	side = robotExt.rotate(side)
   local isObstacle, desrciption = component.robot.detect(side)
	robotExt.rotate(backDir, true)

	return isObstacle, desrciption
end

help.mine = "function(direction:number, distance:number[, isStartSpace:bool]):bool[, number, string] " ..
	"- robot try to mine at [distance] of blocks to the [direction] as sides value. " ..
	"If [isStartSpace]=true robot will mine relative its rotation at the start, otherwise relative the current rotation. " ..
	"Returns [true] if final point has been reached, otherwise [false] and how many blocks has passed and "..
	"describing why moving failed, which will either be 'impossible move', 'not enough energy' or "..
	"the description of the obstacle as robot.detect would return."
function robotExt.mine(direction, distance, isStartSpace)
	local moveSide = robotExt.rotate(direction, isStartSpace)
	local moveVector = moveSide < 2 and side2vector[moveSide] or side2vector[robotExt.getDir()]
	local i, isMoved, reason, isDetect = 0,  true, nil, false
	while(i<distance and isMoved)do
		isMoved, reason = component.robot.move(moveSide)
		if(not isMoved)then
			if(robotExt.swingAt(moveSide))then
				isDetect, reason = component.robot.detectAt(moveSide)
				isMoved = not isDetect
			end
		else
			i = i + 1
			pos = pos + moveVector
		end
	end	
	if(i<distance)then
		return false, i, reason
	end
	return true
end

help.find = "function(filter:string[, warn:bool]):bool, number - scans the blocks around until finds one by filter. "..
	"Returns [true] if found, and side for interaction. Require geolayzer for working. "..
	"If warn is [true] - throws error if geolyzer not available."
function robotExt.find(filter, warn)
	if(not component.isAvailable("geolyzer")) then
		if(warn)then
			error("Error! robotExt.find(filter) require geolyzer for working.")
		end
		return false
	end
	local geo = component.geolyzer
	local function check(side)
		local blockData = geo.analyze(side)
		return blockData ~= nill and string.find(blockData.name, filter) ~= nil
	end

	local checkList = {sides.front, sides.down, sides.up}
	for _, v in pairs(checkList) do
		if(check(v))then 
			return true, v
		end
	end
	for i=1, 3 do
		robotExt.rotate(sides.right)
		if(check(sides.front))then 
			return true, sides.front
		end
	end

	robotExt.rotate(sides.right)
	return false
end

help.findChest = "function([minSize:number[, onlyEmptyCells:bool]]):bool, number - checks blocks around "..
	"until finds one with inventory size more or equal [minSize], 5 by default. Returns [true] if found one "..
	"and side for interaction with inventory. Requires inventory_controller for working. "..
	"If [onlyEmptyCells] is specified - will found block with empty slots quantity more or equal [minSize]."
function robotExt.findChest(minSize, onlyEmptyCells)
	if(not component.isAvailable("inventory_controller")) then
		print("Error! robotExt.findChest() require inventory_controller for working.")
		return false
	end
	minSize = minSize or 5 -- minimum size for chest by default
	local ic = component.inventory_controller
	local size = 0
	local function check(side)
		size = ic.getInventorySize(side)
		if(not onlyEmptyCells)then
			return size ~= nill and size >= minSize
		end
		--count empty slots
		size = size or 0
		local empty = 0
		for i=1, size do
			empty = ic.getSlotStackSize(side, i) == 0 and (empty + 1) or empty
		end
		return empty >= minSize
	end

	local checkList = {sides.front, sides.down, sides.up}
	for _, v in pairs(checkList) do
		if(check(v))then 
			return true, v
		end
	end
	for i=1, 3 do
		robotExt.rotate(sides.right)
		if(check(sides.front))then 
			return true, sides.front
		end
	end

	robotExt.rotate(sides.right)
	return false
end
--endregion

-- region Debug
help.reload = "function():robotExt - reload module 'robotExt' from lib folder. Uses only for debug purposes, example: myRobotExt = myRobotExt.reload()."
function robotExt.reload()
	package.loaded["robotExt"] = nil
	_G["robotExt"] = nil
	return require("robotExt")
end

help.getInfo = "function(self):string - returns help information for functions of this library."
function robotExt.getInfo(self, ident)
	ident = ident or ""
	result = "{"
	ident = ident .. " "
	newLine = ""
	for n, v in pairs(self) do
		if (type(v) == "table" and(not getmetatable(v) or not getmetatable(v).__tostring)) then
			result = result .. newLine .. n .. "=" .. robotExt.getInfo(v, ident)
		else
			result = result .. newLine .. n .. "=" .. tostring(v)
		end
		newLine = ",\n" .. ident
	end
	result = result .. "}"
	return result
end
-- endregion

-- region Help wrapper
local function wrapFn(fn, desc)
	return setmetatable( { }, {
		__call = function(_, ...) return fn(...) end,
		__tostring = function() return desc end
	} )
end
 
local function wrapTable(table, helpTable)
	if (type(helpTable) ~= "table") then
		print("Error! HelpTable must have same structure like the wrap table")
		return
	end

	for n, v in pairs(table) do
		if (type(v) == "table") then
			if (type(helpTable[n]) == "table") then
				wrapTable(v, helpTable[n])
			end
			if (type(helpTable[n]) == "string") then
				mt = getmetatable(v)
				if (not mt) then
					mt = { }
					setmetatable(v, mt)
				end
				mt.__tostring = function() return helpTable[n] end
			end
		elseif (type(v) == "function") then
			if (type(helpTable[n]) == "string") then
				table[n] = wrapFn(v, helpTable[n])
			end
		end
	end
end

wrapTable(robotExt, help)

-- endregion

return robotExt

--[[
function math.sign(x)
	return x<0 and -1 or 1
end
]]--