--[[ Шахтер для OpenComputers
    для копки нужен сундук, внизу ложим кирки, рядом робот, можно еще зарядку рядом с роботом,
    нужно улучшение работы с инвентарем, можно генератор для подзарядки углем.
    
    Author: Multirezonator
    ]]

local component = require("component")
local computer = require("computer")
local robot = require("robot")
local sides = require("sides")
local ic = component.inventory_controller

local mineSize = 15
local downSize = 15
local shaftLength = 0

function Initialize()
    print("Введите размер выработки:")
    local input = tonumber(io.read())
    if (input ~= nil and input > 1) then
        mineSize = input
    end

    print("Введите высоту выработки:")
    local input = tonumber(io.read())
    if (input ~= nil and input > 1) then
        downSize = input
    end

    print("Опуститься вниз без копки на (блоков):")
    local input = tonumber(io.read())
    if input ~= nill then
        shaftLength = input
    end
end

--region Robot
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

function UpdatePos(pos, side)
    if (side == sides.up) then 
        pos[2] = pos[2] + 1
    elseif (side == sides.down) then
        pos[2] = pos[2] - 1
    elseif (side == sides.forward) then 
        pos[3] = pos[3] + 1
    elseif (side == sides.back) then
        pos[3] = pos[3] - 1
    elseif (side == sides.right) then 
        pos[1] = pos[1] + 1
    elseif (side == sides.left) then
        pos[1] = pos[1] - 1
    end
end

--endregion

--region Movement

local pos = {0, 0, 0} -- x, y, z
function pos:toString()
    return "dX=" .. self[1] .. ", dY=" .. self[2] .. ", dZ=" .. self[3]
end

function Move(side, count) -- возвращает false если не может дойти до цели и сколько прошел блоков
    local backSide = side
    side = robot.rotate(side, false)
    local isBlock, detect
    local moved = 0
    for i = 0, (count-1) do
        isBlock, detect  = robot.detect(side)
        if(isBlock and detect ~= "air" and detect ~= "liquid") then
            if(robot.swing(side) ~= true) then
                print("Нельзя двигаться, не могу разбить блок!")
                robot.rotate(backSide, true)
                return false, moved
            end
        end

        local isMoved, issue = robot.move(side)
        if(isMoved ~= true) then
            print("Не получается двигаться, ", issue)
            robot.rotate(backSide, true)
            return false, moved
        end

        UpdatePos(pos, backSide)
        moved = moved + 1
    end

    --print("Move " .. sides[backSide] .. ". pos: " .. pos:toString())
    robot.rotate(backSide, true)
    return true, moved
end

function GotoBase() -- возвратит true если дойдет до базы
    print("Возвращаемся на базу!")
    local shiftUp = -(shaftLength + pos[2])
    if(shiftUp < 1 or Move(sides.up, shiftUp)) then
        print("Уровень выработки.")
        if((pos[1] == 0 or Move(sides.left, pos[1])) and (pos[3] == 0 or Move(sides.back, pos[3]))) then
            print("Вертикальный подъем.")
            if(Move(sides.up, -pos[2])) then
                print("Дом, милый дом! :)")             
                return true
            end
        end
    end
    print("A-a-a, спасите помогите, я потреялся!")
    return false
end

--endregion

--region CheckState
local needDurability = 0
local lastDurability = 0

function CheckPickaxe() --returns прочность и на сколько еще проходов еще хватит
    local durability, eror = robot.durability()
    while(durability == nil) do
        if(eror == "tool cannot be damaged") then
            lastDurability = 1
            print("Ого, какой инструмент, и где такие выдают?!")
            return 1, 100500
        end
        print("Нужна палка-копалка, дай одну!")
        io.read()
        durability, eror = robot.durability()
    end

    if(durability > 0.9999) then
        needDurability = 0
        lastDurability = durability
        print("Кирка блестит как новенькая! Пойду проверю как копает...")
        return durability, 100500 
    end
    
    if(lastDurability < durability) then
        needDurability = 0
        lastDurability = durability

        if(durability < 0.2) then 
            print("Да это просто мусор, а не кирка! Или ты думаешь, что я камни зубами грызть буду?..")
            io.read()
            return CheckPickaxe()
        end

        print("Кирка, не новенькая, ну чем богаты тем и рады :)")
        return durability, 100500
    end 

    needDurability = (needDurability + lastDurability - durability) * 0.5
    lastDurability = durability
    local numberOfPasses = durability / needDurability

    --print("Кирка " .. math.floor(lastDurability * 100) .. "% хватит на " .. math.floor(numberOfPasses) .. " проходов.")
    return durability, numberOfPasses
end

local needEnergy = 0
local lastEnergy = 0
local shaftPos = {0, 0, 0}

function CheckState() -- true если продолжаем копку
    picDur, picCount = CheckPickaxe()
    if(picCount < 2) then 
        print("Кирка износилась, пора на базу!")
        return false
    end

    if(lastEnergy < computer.energy()) then
        needEnergy = (needEnergy + 1000)  * 0.5
    else
        needEnergy = (needEnergy + lastEnergy - computer.energy()) * 0.5      
    end 
    lastEnergy = computer.energy()
    energyFor = lastEnergy / needEnergy
    if(energyFor < 2)then
        print("Батарейки на исходе, нужно возвращаться!")
        return false
    end

    progress = (shaftPos[1] * mineSize + shaftPos[3]) / (mineSize^2) * 100
    print("Прогресс: "..math.floor(progress).."% Кирка: "..math.floor(picDur * 100).."%")
    return true  
end

function FindChest() -- true если нашел и сторона куда повернут, и сторона с которой взаимодействовать
    local minSize = 5
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

function PrintTable(table)
    for name, val in pairs(table) do
        print(name, val)
    end
end

--endregion

function Mine()
    local isWorking = true
    while (isWorking and shaftPos[1] < mineSize) do
        while (isWorking and shaftPos[3] < mineSize) do
            Move(sides.down, downSize)
            Move(sides.up, -(shaftLength + pos[2]))

            isWorking = CheckState()
            if(isWorking) then
                Move(sides.forward, 1)
                UpdatePos(shaftPos, sides.forward)
            end
        end
        Move(sides.back, pos[3])
        if(isWorking) then
            Move(sides.right, 1)
            shaftPos[3] = 0
            UpdatePos(shaftPos, sides.right)
        end
    end
    if(isWorking) then
        print("Работа выполнена, теперь можно и расслабиться...")
        return true
    end
    return false
end

function DropHabar()
    local isChestPersist, sideBack, side = FindChest()
    if(isChestPersist ~= true) then
        print("Нет сундука, поставьте рядом с роботом сундук!")
        return false
    end
        
    print("Ага, сундучок на месте!")
    local chestSize = ic.getInventorySize(side)
    -- выгружаем пытаемся все выгружать
    for i=1, robot.inventorySize() do
        robot.select(i)
        local info = ic.getStackInInternalSlot()
        if(info ~= nil)then
            local c = 1
            repeat
                local chestInfo = ic.getStackInSlot(side, c)
                if(chestInfo == nil or (chestInfo.name == info.name and chestInfo.size < chestInfo.maxSize)) then
                    ic.dropIntoSlot(side, c)
                    info = ic.getStackInInternalSlot()
                end
                c = c + 1
            until (info == nil or c > chestSize)
            if(info ~= nil) then
                print("Не нашлось места для " .. info.name)
                robot.rotate(sideBack, true)
                return false
            end    
        end
    end

    robot.rotate(sideBack, true)
    return true
end

function TakeTool(side, itemPos)
    robot.select(robot.inventorySize()) -- select last robot slot
    ic.suckFromSlot(side, itemPos)
    ic.equip()
    ic.dropIntoSlot(side, itemPos)    
    print("Взял из сундука, слот № " .. itemPos)
end

function Recharge()
    while(computer.energy() < computer.maxEnergy() * 0.99)do
        print("Перезарядка аккомуляторов, еще 30 сек.")
        os.sleep(30)
    end

    local minDurability, minPasses = 0.1 , 10
    local durability, passes = CheckPickaxe()
    if (durability < minDurability or passes < minPasses) then
        print("Кирка износилась, новая нужна, проверю в сундучке...")
        local isChest, sideBack, side = FindChest()
        if(isChest)then
            local chestSize = ic.getInventorySize(side)
            for c=(chestSize - 5), chestSize do 
                local chestInfo = ic.getStackInSlot(side, c)
                if(chestInfo and string.find(chestInfo.name, "ickaxe")) then
                    if((1 - chestInfo.damage/chestInfo.maxDamage) > minDurability) then
                        TakeTool(side, c)
                        break 
--                    else
--                        PrintTable(chestInfo)
--                        print("calcDamage:" .. (1 - chestInfo.damage/chestInfo.maxDamage))
                    end
                elseif (chestInfo and string.find(chestInfo.name, "Dril")) then
                    if((chestInfo.charge/chestInfo.maxCharge) > minDurability) then
                        TakeTool(side, c)
                        break 
--                    else
--                        PrintTable(chestInfo)
--                        print("calcDamage:" .. (1 - chestInfo.charge/chestInfo.maxCharge))
                    end
                end
            end
            print("повернуться в обратную сторону от " .. sides[sideBack])
            robot.rotate(sideBack, true)          
        end
    end 
    durability, passes = CheckPickaxe()
    if(durability >= minDurability) then
        return true
    end       
    return false
end

function Start()
    Initialize()
    isDone = false

    CheckPickaxe()
    while true do
        print("Погружаюсь...")
        Move(sides.down, shaftLength)
        Move(sides.right, shaftPos[1])
        Move(sides.forward, shaftPos[3])
        isDone = Mine()
        GotoBase()
        while(pos[1]~=0 or pos[2]~=0 or pos[3]~=0) do            
            print("Ждем 30 сек.")
            os.sleep(30)
            GotoBase()
        end
        while(DropHabar() ~= true) do 
            print("Некуда грузить! Начальнике давай тару, выгружать буде!")
            io.read();
        end
        if(isDone)then
            print("Принимай работу, начальник!")
            return
        end
        while(Recharge() ~= true) do
            print("Начальнике, патроны закончились! Дай мне кирку и энергии!")
            io.read();
        end
        print("Все хорошо, можно приступать к работе.")
    end
end

Start()