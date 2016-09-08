local robot = require("robot")
local sides = require("sides")
local component = require("component")

function robot.detect(side)
    return component.robot.detect(side)
end

function robot.swing(side, sneaky)
    return component.robot.swing(side, side, sneaky ~= nil and sneaky ~= false)
end

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

return robot