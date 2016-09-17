--[[Extended functionality for OpenComputes robot, 
	for easy movement, navigation and manipulation with inventory.

	Author: Multirez ]]--

local sides = require("sides")
local component = require("component")

local robotExt = {}
local help = {} -- help texts for robotExt will be wrapped at the end

--region Movement
help.pos = "table{x, y, z} - contains current robot coordinates relative the start position, "..
    "where x - right, y - up, z - forward directional axes."
	--x = "number - value of X axis of current robot position."}
robotExt.pos = {["x"] = 0, ["y"] = 0, ["z"] = 0}

--[[
function robot.move(side)
    return component.robot.move(side)
end

function robot.rotate(side, invert)
    local count = 0
    local newSide = side
    if(side == sides.left) then
        if invert then count = 1 else count = 3 end
        newSide = sides.forward
    elseif (side == sides.right) then
        if invert then count = 3 else count = 1 end
        newSide = sides.forward
    elseif (side == sides.back) then
        count = 2
        newSide = sides.forward
    end
    --print("Повернуться раз: " .. tostring(count))
    for i=1, count do
        robot.turnRight()
    end

    return newSide
end

--endregion

--region World interaction

function robot.swing(side, sneaky)
    return component.robot.swing(side, side, sneaky ~= nil and sneaky ~= false)
end

function robot.detect(side)
    return component.robot.detect(side)
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

--region Debug
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
	for n,v in pairs(self) do
		if(type(v)=="table" and (not getmetatable(v) or not getmetatable(v).__tostring))then			
			result = result .. newLine .. n .. "=" .. robotExt.getInfo(v, ident)
		else
			result = result .. newLine .. n .. "=" .. tostring(v)
		end
		newLine = ",\n" .. ident
	end
	result = result .. "}"
	return result
end
--endregion

--region Help wrapper
local function wrapFn(fn, desc)
  return setmetatable({}, {
    __call = function (_, ...) return fn(...) end,
    __tostring = function () return desc end
  })
end
 
local function wrapTable(table, helpTable)
	if(type(helpTable) ~= "table")then
		print("Error! HelpTable must have same structure like the wrap table")
		return
	end

	for n,v in pairs(table) do
		if(type(v)=="table")then
			if(type(helpTable[n])=="table")then
				wrapTable(v, helpTable[n])
			end
			if(type(helpTable[n])=="string") then
				mt = getmetatable(v)
				if(not mt)then
					mt = {}
					setmetatable(v, mt)
				end
				mt.__tostring = function() return helpTable[n] end
			end
		elseif(type(v)=="function")then
			if(type(helpTable[n])=="string")then
				table[n] = wrapFn(v, helpTable[n])
			end
		end
	end
end

--robotExt["reload"] = wrapFn(robotExt["reload"], help["reload"])
wrapTable(robotExt, help)

--endregion


print(robotExt:getInfo())
io.read()

return robotExt