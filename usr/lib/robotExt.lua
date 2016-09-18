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
	front = 0, right = 1, back = 2, left = 3
} -- the help table for the sides conversion

help.transformDirection = "function(localDirection:number):number - transforms direction from local space to start space."
function robotExt.transformDirection(localDirection)
	if ((direction == sides.forward) or(localDirection < 2)) then
		return localDirection
	end
	local mapIndex = rotateMap[sides[direction]]
	-- self index in rotateMap
	local localMapIndex = rotateMap[sides[localDirection]]
	return rotateMap[(mapIndex + localMapIndex) % 4 + 1]
end

help.inverseTransformDirection = "function(startDirection:number):number - transforms direction from start space to local space."
function robotExt.inverseTransformDirection(startDirection)
	if (startDirection < 2) then
		return startDirection
	end
	local deltaMapIndex = rotateMap[sides[startDirection]] - rotateMap[sides[direction]]
	return rotateMap[(deltaMapIndex + 4) % 4 + 1]
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
	for i = 1, rotateMap[sides[side]] do
		component.robot.turn(true)
	end
	direction = robotExt.transformDirection(side)
	-- update direction

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
"Returns true if final movement point has been reached, otherwise nil and how many blocks has passed and "..
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
		return isMoved, i, reason
	end
	return true
end

-- endregion

--region World interaction

help.swing = "function(side:number[, targetSide:number [, sneaky:bool]]):bool[, string] - Makes the robot use the item "..
"currently in the tool slot against the block or space immediately in [side] of the robot "..
"in the same way as if a player would make a left-click. [targetSide] - if given the robot will try to 'left-click' "..
"only on the surface as specified by side, otherwise the robot will try all possible sides. "..
"Returns [true] if the robot could interact with the block or entity in front of it, false otherwise. "..
"If successful the secondary parameter describes what the robot interacted with "..
"and will be one of 'entity', 'block' or 'fire'."
function robotExt.swing(side, targetSide, sneaky)
   return component.robot.swing(side, targetSide, sneaky ~= nil and sneaky ~= false)
end

--[[
function robotExt.detect(side)
   return component.robot.detect(side)
end
]]--

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

function robot.findChest() -- true если нашел и сторона куда повернут, и сторона с которой взаимодействовать
    if(component.isAvailable("inventory_controller") ~= true) then
        print("Нет контроллера инвентаря чтобы проверять сундуки.")
        return false
    end

    local minSize = 5
    local ic = component.inventory_controller

    local size = ic.getInventorySize(sides.forward)
    if(size ~= nill and size > minSize)then
        return true, sides.forward, sides.forward
    end
    size = ic.getInventorySize(sides.up)
    if(size ~= nill and size > minSize)then
        return true, sides.up, sides.up
    end
    robot.turnRight()
    size = ic.getInventorySize(sides.forward)
    if(size ~= nill and size > minSize)then
        return true, sides.right, sides.forward
    end
    robot.turnRight()
    size = ic.getInventorySize(sides.forward)
    if(size ~= nill and size > minSize)then
        return true, sides.back, sides.forward
    end
    robot.turnRight()
    size = ic.getInventorySize(sides.forward)
    if(size ~= nill and size > minSize)then
        return true, sides.left, sides.forward
    end

    robot.turnRight()
    return false
end

function robot.find(filter, warn) -- true если нашел и сторона куда повернут, и сторона с которой взаимодействовать
    if(component.isAvailable("geolyzer") ~= true) then
        if(warn == nil or warn) then print("Нет геолайзера чтобы осмотреться вокруг") end
        return false
    end
    local geo = component.geolyzer
    local function Check(block)
        return block ~= nill and string.find(block.name, filter) ~= nil
    end

    local block = geo.analyze(sides.forward)
    if(Check(block))then
        return true, sides.forward, sides.forward
    end
    block = geo.analyze(sides.up)
    if(Check(block))then
        return true, sides.up, sides.up
    end
    robot.turnRight()
    block = geo.analyze(sides.forward)
    if(Check(block))then
        return true, sides.right, sides.forward
    end
    robot.turnRight()
    block = geo.analyze(sides.forward)
    if(Check(block))then
        return true, sides.back, sides.forward
    end
    robot.turnRight()
    block = geo.analyze(sides.forward)
    if(Check(block))then
        return true, sides.left, sides.forward
    end

    robot.turnRight()
    return false
end

--endregion
]]--