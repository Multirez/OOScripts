--//БЕЗ Апгрейда инвентрь.
--//БЕЗ зарядки из ресурсов в инвентре
--//Зарядка от зарядной станции на месте старта.
--// В 1 слот нужно положить сундук.
 
 --//объявляем прочие переменные 
local alternate = 0
local done = false
local robot = require("robot");
--//иницианализируем генератор
local component = require("component")
local gen = component.generator

local COMP = require("computer")

local depth = 0
local unloaded = 0
local collected = 0

local xPos,zPos = 0,0
local xDir,zDir = 0,1

--//вводим и проверяем данные: размер и глубину
local size

function Collect()	
	local bFull = true
	local ISize = robot.inventorySize()
	--local nTotalItems = 0
	for n = 3, ISize do
		if robot.count(n) == 0 then
			bFull = false
		end

	end
	
	if bFull then
		print( "No empty slots left." )
		--return false
	end
	--return true
	return not bFull
end

function Unload()
	local ISize = robot.inventorySize()
	--проверяем на наличие сундука перед перед роботом
	robot.select(1)
	while not robot.compare() do
		print("Ждем появление сундука 1 минуту")
		os.sleep(60)	
	end
	
	print( "Unloading items..." )
	for n = 3 , ISize do
		robot.select(n)
		while robot.count(n) > 0 do
			robot.drop()
		end
	end
	--collected = 0
	robot.select(3)
end

function GoTo( x, y, z, xd, zd )
	while depth > y do
		if robot.up() then
			depth = depth - 1
		elseif robot.swingUp() then
			Collect()
		else
			os.sleep( 0.5 )
		end
	end

	if xPos > x then
		while xDir ~= -1 do
			TurnLeft()
		end
		while xPos > x do
			if robot.forward() then
				xPos = xPos - 1
			elseif robot.swing() then
				Collect()
			else
				os.sleep( 0.5 )
			end
		end
	elseif xPos < x then
		while xDir ~= 1 do
			TurnLeft()
		end
		while xPos < x do
			if robot.forward() then
				xPos = xPos + 1
			elseif robot.swing() then
				Collect()
			else
				os.sleep( 0.5 )
			end
		end
	end
	
	if zPos > z then
		while zDir ~= -1 do
			TurnLeft()
		end
		while zPos > z do
			if robot.forward() then
				zPos = zPos - 1
			elseif robot.swing() then
				Collect()
			else
				os.sleep( 0.5 )
			end
		end
	elseif zPos < z then
		while zDir ~= 1 do
			TurnLeft()
		end
		while zPos < z do
			if robot.forward() then
				zPos = zPos + 1
			elseif robot.swing() then
				Collect()
			else
				os.sleep( 0.5 )
			end
		end	
	end
	
	while depth < y do
		if robot.down() then
			depth = depth + 1
		elseif robot.swingDown() then
			Collect()
		else
			os.sleep( 0.5 )
		end
	end
	
	while zDir ~= zd or xDir ~= xd do
		TurnLeft()
	end
end

local function ReturnStart()
	local x,y,z,xd,zd = xPos,depth,zPos,xDir,zDir
	print( "Returning to surface...", x,y,z,xd,zd)
	GoTo( 0,0,0,0,-1 )
	
	Unload()
	
	print( "Resuming mining..." )
	GoTo( x,y,z,xd,zd )
end

function RobotDown()
	if not Collect() then
		ReturnStart()
		--return false
	end	
	
	local i = 1
	repeat
		robot.swingDown()
		i = i + 1
		if i == 30 then
			return false
		end  
	until not robot.detectDown()

	robot.down()
  
  	depth = depth + 1
	if math.fmod( depth, 10 ) == 0 then
		print( "Descended " .. depth .. " metres." )
	end
	return true
end

function RobotForward()
	if not Collect() then
		ReturnStart()
		--return false
	end

	local i = 0
 
	if COMP.energy() < 5000 then
		Refuel()
	end
	
    repeat
		robot.swing()
		i = i + 1
		if i == 50 then
			return false
		end			
    until not robot.detect()
    robot.forward()

	xPos = xPos + xDir
	zPos = zPos + zDir	
	
	return true
end

function TurnLeft()
	robot.turnLeft()
	xDir, zDir = -zDir, xDir
end

function TurnRight()
	robot.turnRight()
	xDir, zDir = zDir, -xDir
end

function Refuel()
	--local selectedSlot = robot.select()
	--begin
	--print("Refuel...")
	--robot.select(16)
	--gen.insert(8)
	--robot.select(selectedSlot)
	
	-- зарядка от "зарядника"
	local x,y,z,xd,zd = xPos,depth,zPos,xDir,zDir
	print( "Returning to surface...", x,y,z,xd,zd)
	GoTo( 0,0,0,0,-1 )
	
	Unload()
	
	while COMP.energy() < 20200 do
		print("Пробуем зарядиться...")
		os.sleep(60)	
	end	
		
	print( "Resuming mining..." )
	GoTo( x,y,z,xd,zd )	
	
 end

function StartQuarry(size)
	while not done do
		
		if COMP.energy() < 5000 then
			Refuel()
		end
		
		for n = 1, size do
			for m=1, size - 1 do
				if not RobotForward() then
					done = true
					print("Done")
					break
				end		
			end
		  
			if n < size then
				if math.fmod(n + alternate,2) == 0 then
					TurnLeft()
					if not RobotForward() then
						done = true
						break
					end
					TurnLeft()
				else
					TurnRight()
					if not RobotForward() then
						done = true
						break
					end
					TurnRight()
				end
			end
			
			if done == true then
				print("Done")
				break
			end
		end
		
		if size > 1 then
			if math.fmod(size,2) == 0 then
				TurnRight()
			else
				if alternate == 0 then
					TurnLeft()
				else
					TurnRight()
				end
				alternate = 1 - alternate
			end
	end	
	
    print("Level " .. depth)
	
	if done == true then
	  print("Done")
	end
	
	if not RobotDown() then
	  done = true
	  print("Done")
	  break
	end	
  end
end

print("Enter size")
size = tonumber(io.read())
if size == nil then
  print("No correct size. Program close")
  return
end
--size = io.read("*n")
--assert (size, "Invalid parametr size")

if size < 1 then
  print("Error: size < 1. Program close")
  return
end

print("Enter level start ")
--LevelStart = io.read("*n")
LevelStart = tonumber(io.read())
if LevelStart ~= nil then
	GoTo( 0, LevelStart, 0, xDir, zDir )
end

if COMP.energy() < 5000 then
	Refuel()
end

print( "Excavating..." )
if not RobotDown() then
	print("Done")
else
	robot.select(3)
	StartQuarry(size)
end

-- Return to where we started
GoTo( 0,0,0,0,-1 )
Unload()
GoTo( 0,0,0,0,1 )