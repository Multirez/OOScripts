-- FORKED FROM http://pastebin.com/gqZ1Qdqi
-- http://computercraft.ru/topic/1031-geokopatel-ili-stan-millionerom/
-- v0.5.1
-- edited by Multirez - fixed bug with electric tools UwJTGUcM

local shell = require "shell"
local sides = require("sides")
local term = require("term")
local r = require("robot")
local comp = require("component")
local event = require("event")
local computer = require("computer")
local inv = comp.inventory_controller
local KOPALKA = {}
local inv_size = r.inventorySize()
local inv_side = sides.back
local charge_side = sides.left
local battery_side = sides.bottom
local temp_state = {x=0, y=0, z=0, dr=3}
local lc = {x=0, y=0, z=0, dr=3, xMax = 0, zMax = 0}
local way = 0
local ore_count = 0
local warp = false
local messages = {}
local bedrockWidth = 5
local back_to_the_future_mode = false
local minHardness = 2.05
local maxHardness = 40
local directives = {
  pause = false,
  home = false,
  report = false,
  move = false    
}

local scrap = {
  "minecraft:stone", 
  "minecraft:cobblestone",
  "minecraft:dirt",
  "minecraft:gravel",
  "minecraft:sand",
  "minecraft:grass",
  "minecraft:sandstone",
  "minecraft:mossy_cobblestone",
  "minecraft:stonebrick",
  "minecraft:brown_mushroom",
  "minecraft:red_mushroom",
  "minecraft:netherrack"
}

local fuel_list = {
  "minecraft:fence",
  "minecraft:planks",
  "minecraft:log",
  "minecraft:coal_block",
  "minecraft:coal"
}

local mining_tools_list = {
  "minecraft:iron_pickaxe",
  "minecraft:golden_pickaxe",
  "appliedenergistics2:item.ToolCertusQuartzPickaxe",
  "appliedenergistics2:item.ToolNetherQuartzPickaxe",
  "IC2:itemToolBronzePickaxe",
  "Forestry:bronzePickaxe",
  "minecraft:diamond_pickaxe",
  "IC2:itemToolDrill",
  "IC2:itemToolDDrill",
  "IC2:itemToolIridiumDrill",
  "GraviSuite:advDDrill"
}

local function sprintf(s, ...)
  return s:format(...)
end 

function pause()
  os.sleep(0)
end

local function sendSt(message) -- ОТПРАВКА СТАТУСНОГО СООБЩЕНИЯ ЧЕРЕЗ ТУННЕЛЬ
  print(message)
  if warp == true then
    pcall(comp.tunnel.send(message))
  end
end

function KOPALKA.duster(tmr)
  while true do
    for i=1,7 do
      local temp = inv.getStackInSlot(3,i)
      if temp then
        if temp.name == "IC2:itemDustSmall" and math.floor(temp.size/9) > 0 then
          for j=1,3 do
            r.select(j)
            inv.suckFromSlot(3,i,math.floor(temp.size/9))
          end
          for j=5,7 do
            r.select(j)
            inv.suckFromSlot(3,i,math.floor(temp.size/9))
          end
          for j=9,11 do
            r.select(j)
            inv.suckFromSlot(3,i,math.floor(temp.size/9))
          end
            r.select(4)
            require("component").crafting.craft(math.floor(temp.size/9))
            r.drop()
        end
      end
    end
    os.sleep(tmr) 
  end
end

function KOPALKA.charge(charge_side)
  while computer.energy() < (computer.maxEnergy()/2) do
    term.clear()
    KOPALKA.use(charge_side)
    sendSt("Зарядка...")
    os.sleep(60)
    KOPALKA.use(charge_side)
  end
  sendSt("Батарея заряжена")
  return true
end

function KOPALKA.charge_tool(chargerSide, slot)
  local side = 3
  local tool = nil
  
  if chargerSide == 1 then 
    side=1
  elseif chargerSide == 0 then
    side=0
  end
  
  if r.durability() == nil then
    return false
  end
  
  if r.durability() < 0.3 then 
    r.select(slot)
    inv.equip()
    tool = inv.getStackInInternalSlot(slot) 
    inv.equip()
    if not(lc.x == 0 and lc.y == 0 and lc.z == 0) then
      return true
    end
  else
    return false
  end

  local function isElectric(device)
    if device.maxCharge ~= nil then
      return true
    else 
      return false
    end
  end

  local function find_new_tool()
    KOPALKA.rot(inv_side)
    local temp = KOPALKA.inv_scaner(mining_tools_list, false, start_slot)
    sendSt("Поиск замены инструменту в сундуке.")
    while temp ~= 0 do
      local temp_device = inv.getStackInSlot(3, temp)
      if isElectric(temp_device) then 
        if temp_device.charge/temp_device.maxCharge > 0.6 then
          break
        else
          temp = KOPALKA.inv_scaner(mining_tools_list, false, temp+1)
        end
      else
        if temp_device.damage/temp_device.maxDamage < 0.4 then
          break
        else
          temp = KOPALKA.inv_scaner(mining_tools_list, false, temp+1)
        end
      end
    end
    return temp
  end

  local function service(device)
    if isElectric(device) then 
      KOPALKA.rot(chargerSide)
      if not inv.getInventorySize(3) == nil then
        sendSt("Зарядник не найден. Установите зарядник.")
        while not inv.getInventorySize(3) == nil do
          os.sleep(5)
        end
      end
      r.select(slot)
      inv.equip()
      inv.dropIntoSlot(3,1)
      sendSt("Зарядка инструмента.")
      while inv.getStackInSlot(3,1).charge < device.maxCharge do
        os.sleep(10)
      end
      inv.suckFromSlot(3,1)
      inv.equip()            
    else
      sendSt("Поиск инструмента в сундуке.")
      KOPALKA.rot(inv_side)
      while true do
        local temp = find_new_tool()
        if temp ~= 0 then
          r.select(slot)
          inv.equip()
          if not r.drop() then
            sendSt("Нет места в сундуке. Освободите место.")
            while not r.drop() do
              os.sleep(10)
            end
          end
          inv.suckFromSlot(3, temp)
          inv.equip()
          r.select(1)
          break
        end
      end
    end
  end

  if lc.x == 0 and lc.y == 0 and lc.z == 0 then
	sendSt("Сервис инструмента.")
    service(tool)
  else
    return false
  end  
end

function KOPALKA.use(s)
  if s == 1 then
    r.useUp()
  elseif s == 2 then
    r.turnAround()
    r.use()
    r.turnAround()
  elseif s == 3 then
    r.use()
  elseif s == 4 then
    r.turnRight()
    r.use()
    r.turnLeft()
  elseif s==5 then
    r.turnLeft()
    r.use()
    r.turnRight()
  else
    r.useDown()
  end
end

function KOPALKA.drop() --функция дропа всего инвентаря в сундук, если таковой стоит перед носом
  while true do 
    if r.detect() then
      if inv.getInventorySize(3) ~= nil then
        for i=1,inv_size-1 do
          if inv.getStackInInternalSlot(i) ~= nil then
            r.select(i) 
            if not r.drop() then
              sendSt("Сундук переполнен. Освободите место под складирование.")
              while not r.drop() do
                os.sleep(5)
              end
            end
          end
        end
        break
      else
        sendSt("Блок не является сундуком.")
        os.sleep(5)
      end 
    else
      sendSt("Установите сундук!")
      os.sleep(5)
    end
  end 
end

function KOPALKA.isScrap(name) -- ПРОВЕРКА ПРЕДМЕТА, ЯВЛЯЕТСЯ ЛИ ОН МУСОРОМ
  for i, nm in pairs(scrap) do
    if name == nm then   
      return true
    end
  end
  return false
end

function KOPALKA.ore_analyze(arg) -- АНАЛИЗ БЛОКА, ЯВЛЯЕТСЯ ЛИ ОН МУСОРОМ
  if arg ~= nil then
    if comp.isAvailable("geolyzer") then
      local lyz = comp.geolyzer
      if KOPALKA.isScrap(lyz.analyze(arg).name) then
        return false
      else
        return true
      end
    else
      print("Геолайзер не обнаружен в системе.")
      return false
    end
  else
    print("Не указан аргумент(сторона проверки).")
  end
end

function KOPALKA.drop_scrap()
  for i=1, inv_size do   
    local slot = inv.getStackInInternalSlot(i) 
    if slot ~= nil then   
      if KOPALKA.isScrap(slot.name) then
        r.select(i)
        r.dropDown()
      end
    end
  end
  return KOPALKA.inv_sorting()  
end


-----------------------------------ДВИЖЕНИЕ СКВОЗЬ ПОРОДУ [BEGIN]
local function hiver(a_side) --ДОБЫЧА УЛЬЯ
  if comp.geolyzer.analyze(a_side).name == "ExtraBees:hive" then
    if pcall(r.select, KOPALKA.inv_scaner("Forestry:scoop", true)) then
      inv.equip()
      comp.robot.swing(a_side)
      inv.equip()
      r.select(1)
    end
  end
end

function KOPALKA.mUp()
  local try = 1
  repeat 
    r.swingUp()
    try = try + 1
    if try >= 15 then
      sendSt("Препятствие у точки: x="..lc.x.." z="..lc.z.." y="..lc.y.." Направление Dr=вверх"..lc.dr)
      local _, det = r.detectUp()
      sendSt(det.." сверху.")
      sendSt(comp.geolyzer.analyze(1).name)
      KOPALKA.mTo(lc.x+2,lc.y,lc.z)
      if not back_to_the_future_mode then
        os.exit(1)
        --KOPALKA.back_to_the_future()
        return false
      else
	try = 1
      end
    elseif try > 12 then
      hiver(1)
    end
  until not r.detectUp()
  while try < 15 and not r.up() do
    r.swingUp()
    try = try + 1
  end
  if try < 15 then
    lc.y = lc.y + 1
    way = way + 1
    return true
   end
end

function KOPALKA.mDown(action, arg)
  local try = 1
  if action ~= nil then 
    action(arg)
  end
  repeat
    r.swingDown()
    try = try + 1
    if try >= 15 then
      sendSt("Препятствие у точки: x="..lc.x.." z="..lc.z.." y="..lc.y.." Направление Dr= вниз"..lc.dr)
      local _, det = r.detectDown()
      sendSt(det.." снизу.")
      sendSt(comp.geolyzer.analyze(0).name)
      if not back_to_the_future_mode then
        os.exit(1)
        --KOPALKA.back_to_the_future()
        return false
      else
	try = 1
      end
    elseif try > 12 then
      hiver(0)
    end
  until not r.detectDown()
  while try < 15 and not r.down() do
    r.swingDown()
    try = try + 1
  end
  if try < 15 then
    lc.y = lc.y - 1
    way = way + 1
    return true
  end
end

function KOPALKA.mForw(action, arg)
  local try = 1
  if action ~= nil then 
    action(arg)
  end
  repeat
    r.swing()
    try = try + 1
    if try >= 15 then
      sendSt("Препятствие у точки: x="..lc.x.." z="..lc.z.." y="..lc.y.." Направление Dr="..lc.dr)
      local _, det = r.detect()
      sendSt(det.." спереди.")
      sendSt(comp.geolyzer.analyze(3).name)
      if not back_to_the_future_mode then
        os.exit(1)
        --KOPALKA.back_to_the_future()
        return false
      else
	try = 1
      end
    elseif try > 12 then
      hiver(3)
    end
  until not r.detect()
  while try < 15 and not r.forward() do
    r.swing()
    try = try + 1
  end
  if try < 15 then
    way = way + 1
    if lc.dr==2 then
      lc.x = lc.x - 1
    elseif lc.dr==3 then
      lc.x = lc.x + 1
    elseif lc.dr==4 then
      lc.z = lc.z + 1
    elseif lc.dr==5 then
      lc.z = lc.z - 1
    end
    return true
  end
end
-----------------------------------ДВИЖЕНИЕ СКВОЗЬ ПОРОДУ [END]


-----------------------------------ВРАЩЕНИЕ К ПРОГРАММНОЙ НАВИГАЦИИ [BEGIN]
function KOPALKA.turnLeft()
  r.turnLeft()
  if lc.dr == 3 then
    lc.dr = 5
  elseif lc.dr == 4 then
    lc.dr = 3
  elseif lc.dr == 2 then
    lc.dr = 4
  elseif lc.dr == 5 then
    lc.dr = 2
  end
end

function KOPALKA.turnRight()
  r.turnRight()
  if lc.dr == 3 then
    lc.dr = 4
  elseif lc.dr == 4 then
    lc.dr = 2
  elseif lc.dr == 2 then
    lc.dr = 5
  elseif lc.dr == 5 then
    lc.dr = 3
  end
end

function KOPALKA.turnAround()
  r.turnAround()
  if lc.dr == 3 then
    lc.dr = 2
  elseif lc.dr == 4 then
    lc.dr = 5
  elseif lc.dr == 2 then
    lc.dr = 3
  elseif lc.dr == 5 then
    lc.dr = 4
  end
end

function KOPALKA.rot(side) -- ВРАЩЕНИЕ С ЗАПОМИНАНИЕМ НАПРАВЛЕНИЯ
  if (side ~= 1) and (side ~= 0) and lc.dr-side ~=0 then
    if lc.dr == 3 then
      if side == 4 then
	    KOPALKA.turnRight() 
      elseif side == 2 then
	    KOPALKA.turnAround()
      elseif side == 5 then
	    KOPALKA.turnLeft()
      end
    elseif lc.dr == 4 then
      if side == 2 then
	    KOPALKA.turnRight() 
      elseif side == 5 then
	    KOPALKA.turnAround()
      elseif side == 3 then
	    KOPALKA.turnLeft()
      end
    elseif lc.dr == 2 then
      if side == 5 then
	    KOPALKA.turnRight() 
      elseif side == 3 then
	    KOPALKA.turnAround()
      elseif side == 4 then
	    KOPALKA.turnLeft()
      end
    else
      if side == 3 then
	    KOPALKA.turnRight() 
      elseif side == 4 then
	    KOPALKA.turnAround()
      elseif side == 2 then
	    KOPALKA.turnLeft()
      end
    end
  end
end
-----------------------------------ВРАЩЕНИЕ К ПРОГРАММНОЙ НАВИГАЦИИ [END]


-----------------------------------ДВИЖЕНИЕ С ПРОГРАММНОЙ НАВИГАЦИЕЙ [BEGIN]
function KOPALKA.mTo(x, y, z, action, arg)
  if directives.pause then
    KOPALKA.execDirective()
  end
  if lc.x > x then
    KOPALKA.rot(sides.back)
    while lc.x > x do
      KOPALKA.mForw(action,arg)
    end
  end
  if lc.x < x then
    KOPALKA.rot(sides.forward)
    while lc.x < x do
      KOPALKA.mForw(action,arg)
    end
  end
  if lc.z > z then
    KOPALKA.rot(sides.left)
    while lc.z > z do
      KOPALKA.mForw(action,arg)
    end  
  end
  if lc.z < z then
    KOPALKA.rot(sides.right)
    while lc.z < z do
      KOPALKA.mForw(action,arg)
    end
  end
  while lc.y > y do
    KOPALKA.mDown(action,arg)
  end
  while lc.y < y do
    KOPALKA.mUp(action,arg)
  end
end

function KOPALKA.home(action, arg)
  temp_state.x = lc.x
  temp_state.y = lc.y
  temp_state.z = lc.z
  temp_state.dr = lc.dr
  KOPALKA.mTo(0, 0, 0, action, arg)
  KOPALKA.rot(2) 
  KOPALKA.drop_scrap()
  KOPALKA.drop()
  --KOPALKA.rot(3)
end

function KOPALKA.back_to_mine(action, arg)
  KOPALKA.mTo(0, temp_state.y, 0, action, arg)
  KOPALKA.mTo(temp_state.x, temp_state.y, temp_state.z, action, arg)
  KOPALKA.rot(temp_state.dr)
  temp_state.x = 0
  temp_state.y = 0 
  temp_state.z = 0 
  temp_state.dr = 3
end

-----------------------------------ДВИЖЕНИЕ С ПРОГРАММНОЙ НАВИГАЦИЕЙ [END]

-----------------------------------ОЧЕРЕДЬ СООБЩЕНИЙ [BEGIN]
function create_queue()
    local queue = {}
    queue.firstIndex = 1
    queue.lastIndex = 0

    function queue:count()
        return self.lastIndex - self.firstIndex + 1
    end

    function queue:push(obj)
        local last = self.lastIndex + 1
        self.lastIndex = last
        self[last] = obj
    end

    function queue:pull()
        if self:count() <= 0 then error("queue is empty or corrupted") end
        local first = self.firstIndex
        local result = self[first]
        self[first] = nil
        self.firstIndex = first + 1
        return result
    end

    return queue
end
-----------------------------------ОЧЕРЕДЬ СООБЩЕНИЙ [END]

function KOPALKA.check_inv()
  return r.inventorySize()
end

function KOPALKA.inv_sorting()
  local items_stored = 0

  for i=1, inv_size-1 do
    if r.count(i) == 0 then
      for j=inv_size-1, 1, -1 do
        if r.count(j) > 0 then
          if j<i then 
            break
          end
          r.select(j)
          r.transferTo(i)
          break
        end
      end
    end
  end
  for i=1,inv_size do
    if r.count(i) > 0 then
      items_stored = items_stored + 1
    end
  end
  r.select(1) 
  return items_stored/inv_size
end

function KOPALKA.check_state()
  sendSt(sprintf("keep-alive x=%i z=%i y=%i", lc.x, lc.z, lc.y))
  local need_fuel = computer.energy() < (computer.maxEnergy()*0.90)
  
  local function inventory()
    local need_to_home = false
    if (r.count(inv_size-2) > 0) then   
      if KOPALKA.drop_scrap() > 0.9 then
        need_to_home = true
      else
        need_to_home = false
      end
    end 
    return need_to_home
  end

  local function fuel(internal) 
    local need_to_home = false
    if need_fuel and comp.isAvailable("generator") and comp.generator.count() == 0 then
      local slt = KOPALKA.inv_scaner(fuel_list, internal)
      if slt ~= 0 and not internal then
        r.select(inv_size-2)
        inv.suckFromSlot(3, slt) 
        comp.generator.insert()
        r.select(1)
        need_to_home = false
      else 
        slt = KOPALKA.inv_scaner(fuel_list, internal)
        if slt ~= 0 and internal then  
          r.select(slt)
          comp.generator.insert()
          r.select(1)
          need_to_home = false
        else
          need_to_home = true
        end 
      end 
    elseif not comp.isAvailable("generator") and need_fuel then
      need_to_home = true 
    end
    return need_to_home
  end

  if inventory() or fuel(true) or KOPALKA.charge_tool(charge_side, inv_size-2) then
    KOPALKA.home()
    os.sleep(15)
    KOPALKA.charge_tool(charge_side, inv_size-2)  
    fuel(false)
    KOPALKA.back_to_mine()
  end  
    
  if KOPALKA.check_home_command() then
    KOPALKA.home()
    print("Экстренный вызов домой, вернуться в шахту? (0/1)")
    print('> ')
    if tonumber(io.read()) ~= 1 then
      os.exit()
    end
    KOPALKA.charge_tool(charge_side, inv_size-2)  
    fuel(false)
    KOPALKA.back_to_mine()
  end 
end 

function OnModemMessage(_, _, _, _, _, message, ...)
    print(message, ...)
    messages:push(message)
end

function KOPALKA.check_home_command()
    if warp == true then
        while messages:count() > 0 do
            local message = messages:pull()
            if(message == "home") then 
                return true
            else
                sendSt("Неизвестная команда: " .. message)
            end
        end
    end
    return false;
end

function KOPALKA.inv_scaner(filter, internal, start_slot) --автопоисковик заданного итема в своем инвентаре по системному имени. возвращает номер ячейки итема, первого найденного от начала ивентаря.
  ins = inv.getInventorySize(3)
  if start_slot == nil then
    start_slot = 1
  end
  if filter == "empty" then
    if internal then
      for i=start_slot, inv_size do
        if inv.getStackInInternalSlot(i) == nil then
          return i
        end
      end
    else
      for i=start_slot, inv.getInventorySize(3) do
        if inv.getStackInSlot(3, i) == nil then
          return i
        end
      end
    end
  end  
  if internal then
    for i=start_slot, inv_size do
      if inv.getStackInInternalSlot(i) ~= nil then
        if pcall(pairs, filter) then
          for j, name in pairs(filter) do
            if inv.getStackInInternalSlot(i).name == name then
              return i
            end
          end
        else
          if inv.getStackInInternalSlot(i).name == filter then
            return i
          end
        end
      end
    end
    return 0   
  else
    if ins ~= nil  then
      for i=start_slot, ins do
        if inv.getStackInSlot(3, i) ~= nil then
          if pcall(pairs, filter) then
            for j, name in pairs(filter) do
              if inv.getStackInSlot(3, i).name == name then
                return i
              end
            end
          else
            if inv.getStackInSlot(3, i).name == filter then
              return i
            end
          end
        end
      end
      return 0
    else
      return 0
    end
  end
end

function KOPALKA.distance(blockA, blockB)
  local dist = math.sqrt(math.pow(blockA.x - blockB.x,2) + 
  math.pow(blockA.z - blockB.z,2) + math.pow(blockA.y - blockB.y,2))
  return dist
end

function KOPALKA.closest_point(point, points)
  local cl_num = 1
  local length = KOPALKA.distance(point, points[1])
  for i=1, #points do
    local l = KOPALKA.distance(point, points[i])
    if l < length then
      cl_num = i
      length = l
    end
  end
  return cl_num
end

function KOPALKA.waypoints(ores_table, last)
  local yeildGuard = 0
  local way_table = {}
  local count = #ores_table
  table.insert(way_table, {x=lc.x, z=lc.z, y=lc.y})
  while count ~= #way_table - 1 do
    yeildGuard = yeildGuard + 1
    if yeildGuard == 100 then
      yeildGuard = 0
      pause()
    end
    local j = KOPALKA.closest_point(way_table[#way_table], ores_table)
    table.insert(way_table, ores_table[j])
    table.remove(ores_table, j)
  end
  return way_table, last
end

function KOPALKA.scanVolume(xn, zn, bedrock, side, hight_border) --сканирование карьерного "этажа" заданного радиуса -10 блоков вниз+сканер+10 блоков вверх; bedrock - верхний уровень бедрока
  local geo = comp.geolyzer
  local ores_table = {} 
  local last = false
  local x_limit = 0
  local z_limit = 0
  local x_increment = 1
  local z_increment = 1
  if side == "north" or side == "север" then 
    x_limit = zn
    x_increment = 1 
    z_limit = -xn
    z_increment = -1
  elseif side == "west" or side == "запад" then
    x_limit = -xn
    x_increment = -1 
    z_limit = -zn
    z_increment = -1
  elseif side == "south" or side == "юг" then
    x_limit = -zn
    x_increment = -1 
    z_limit = xn
    z_increment = 1
   elseif side == "east" or side == "восток" or side == nil then
     x_limit = xn
     x_increment = 1 
    z_limit = zn
    z_increment = 1
  end

  for xt=0,x_limit,x_increment do
    for zt=0,z_limit,z_increment do
      local scan = geo.scan(xt,zt,true)
      for yt=hight_border+33, 33+math.abs(hight_border) do
        if scan[yt] > minHardness and scan[yt] < maxHardness and ((yt-33)+lc.y) > bedrock then
          if side == "north" or side == "север" then 
            table.insert(ores_table, {x=math.abs(zt)+lc.x, z=math.abs(xt)+lc.z, y=(yt-33)+lc.y}) 
          elseif side == "west" or side == "запад" then
            table.insert(ores_table, {x=math.abs(xt)+lc.x, z=math.abs(zt)+lc.z, y=(yt-33)+lc.y}) 
          elseif side == "south" or side == "юг" then
            table.insert(ores_table, {x=math.abs(zt)+lc.x, z=math.abs(xt)+lc.z, y=(yt-33)+lc.y}) 
          elseif side == "east" or side == "восток" or side == nil then
            table.insert(ores_table, {x=math.abs(xt)+lc.x, z=math.abs(zt)+lc.z, y=(yt-33)+lc.y}) 
          end     
        end
      end 
    end
  end 
  return ores_table
end

function KOPALKA.whatsSide()
  local geo = comp.geolyzer
  local function isBlock(dens)
    if dens ~= nil and dens ~= 0 then
      return 1
    elseif dens == 0 then
      return 0
    end
  end

  local function check(fig, front) 
    local figure1 = {
      east = isBlock(geo.scan(1,0)[33]),
      south = isBlock(geo.scan(0,1)[33]),
      west = isBlock(geo.scan(-1,0)[33]),   
      north = isBlock(geo.scan(0,-1)[33])
    }   
    if front then
      if fig.east > figure1.east  then
        return "east"
      elseif fig.south > figure1.south then
        return "south"
      elseif fig.west > figure1.west then
        return "west"
      elseif fig.north > figure1.north then
        return "north"
      end 
    elseif not front then
      if fig.east < figure1.east  then
        return "east"
      elseif fig.south < figure1.south then
        return "south"
      elseif fig.west < figure1.west then
        return "west"
      elseif fig.north < figure1.north then
        return "north"
      end  
    end
  end
  local figure = {
    east = isBlock(geo.scan(1,0)[33]),
    south = isBlock(geo.scan(0,1)[33]),
    west = isBlock(geo.scan(-1,0)[33]),   
    north = isBlock(geo.scan(0,-1)[33])
  }
  KOPALKA.rot(3)
  while true do
    if r.detect() then
      r.swing()
      local direction = check(figure, true)
      r.place()
      return direction 
    elseif r.detectDown() then
      r.swingDown()
      r.place()
      local direction = check(figure, false)
      r.swing()
      r.placeDown()
      return direction
    end
    sendSt("Для ориентирования в пространстве недостаточно данных.")
    sendSt("Пожалуйста установите любой блок перед или под роботом и повторите попытку")
    os.exit(1)
  end
end

function KOPALKA.findoutBedrockLevel() -- нижний уровень бедрока
  local bedrock = -1
  local start_level = lc.y
  local geo = comp.geolyzer
  local function scan()
    local tempr=geo.scan(0,0)
    for i = 10, 1, -1 do
      if tempr[33 - i] < -0.3 then
        return lc.y - i, true
      end
    end
    return 0, false
  end
  for i = lc.y, -256, -10 do
    local bed, catch = scan()
    if not catch then
      KOPALKA.mTo(lc.x, i, lc.z)
    else
      bedrock = bed
      break
    end
  end
  KOPALKA.mTo(lc.x, start_level, lc.z)
  return bedrock
end

function KOPALKA.clusterDigger(start_point, x, z, bedrock, side)
  sendSt(sprintf("cluster: %d %d %d (%d %d %d) %s", start_point.x, start_point.y, start_point.z, x, bedrock, z, side))
  sendSt("Сканирование заданного объема, может занять несколько минут...")
  if side == nil then
    side = KOPALKA.whatsSide()
  end
  if start_point == nil then
    start_point = lc
  end
  KOPALKA.mTo(start_point.x, start_point.y, start_point.z)
  for Y=lc.y, bedrock+bedrockWidth+1, -1 do
    if Y%21 == 0 or Y == bedrock + 9 then
      KOPALKA.mTo(start_point.x, Y, start_point.z) 
      KOPALKA.rot(3)
      arr=KOPALKA.waypoints(KOPALKA.scanVolume(x-1,z-1, bedrock+bedrockWidth-1, side, -11))
      ore_count = ore_count + (#arr-1) 
      for i=1, #arr do
        KOPALKA.mTo(arr[i].x, arr[i].y, arr[i].z)
        if i%10 == 0 then
          KOPALKA.check_state()
        end
        if way%30 == 0 then
          KOPALKA.check_state()
        end
      end
    end 
  end
end

function KOPALKA.geoMiner(x, z, bedrock, side, x_lim, z_lim)
  if bedrock == nil then
    sendSt("Проверка уровня бедрока. Вертикальная шахта до дна и обратно.")
    bedrock = KOPALKA.findoutBedrockLevel()
  end
  sendSt(sprintf("bedrock= %d\n", bedrock))
  local start_point = {x=0, y=0, z=0}
  local x_limit = x_lim
  local z_limit = z_lim
  if x_lim == nil then
    x_limit = 32
  end
  if z_lim == nil then
    z_limit = 32
  end
  if side == nil then
    side = KOPALKA.whatsSide() 
  end

  local function z_glide()
    if z/z_limit < 1 then
      KOPALKA.clusterDigger(start_point, x_limit, z, bedrock, side)
    else
      for j=1, math.floor(z/z_limit) do
        KOPALKA.clusterDigger(start_point, x_limit, z_limit, bedrock, side)
        start_point.z = j*z_limit+1
      end
      if z%z_limit > 0 then
        KOPALKA.clusterDigger(start_point, x_limit, z%z_limit, bedrock, side)
      end
      start_point.z = 0
    end
  end

  if x/x_limit < 1 then
    local temp = x_limit
    x_limit = x
    z_glide()
    x_limit = temp
  else
    for i=1, math.floor(x/x_limit) do
      z_glide()
      start_point.x = i*x_limit+1
    end 
    if x%x_limit > 0 then 
      x_limit = x%x_limit
      z_glide()
    end
  end 
  KOPALKA.home()
  KOPALKA.rot(3)
  sendSt("Итого руды добыто: "..ore_count)
  sendSt("Всего блоков пройдено: "..way)
  sendSt('Робот '..r.name()..' завершил работу.')
end

function KOPALKA.check_components()
  local function stop()
    print('> ')
    if tonumber(io.read()) ~= 1 then
      os.exit()
    end
  end
  if comp.isAvailable("tunnel") then
    warp = true
    messages = create_queue()
    event.listen("modem_message", OnModemMessage)
	print("\t Связанная карта....доступна.")
  else
    print("\t Связанная карта не обнаружена. Начать работу? (0/1)")
    stop()
  end
  if comp.isAvailable("chunkloader") then
    comp.chunkloader.setActive(true)
    print("\t Чанклоадер....доступен.")
  else
    print("\t Чанклоадер не обнаружен, возможны проблемы и ошибки. Начать работу без чанклоадера? (0/1)")
    stop()
  end
  if comp.isAvailable("inventory_controller") then
    print("\t Контроллер инвентаря....доступен.")
  else
    print("\t Контроллер инвентаря не обнаружен, возможны проблемы и ошибки. Принудительная остановка программы.")
    os.exit()
  end
  if comp.isAvailable("generator") then
    print("\t Генератор....доступен.")
  else
    print("\t Генератор не обнаружен, возможны проблемы и ошибки. Начать работу без генератора? (0/1)")
    stop()
  end
  if comp.isAvailable("geolyzer") then
    print("\t Геосканер....доступен.")
  else
    print("\t Геосканер не обнаружен, возможны проблемы и ошибки. Принудительная остановка программы.")
    os.exit()
  end
  if pcall(r.select,KOPALKA.inv_scaner("Forestry:scoop", true)) then
    r.transferTo(inv_size)
    r.select(1)
    print("\t Сачок....доступен.")
  else
    print("\t Сачок не обнаружен, возможны проблемы и ошибки. Начать работу без сачка?")
    stop()
  end
  if r.durability() ~= nil then
    print("\t Инструмент....доступен.")
  else
    print("\t Инструмент не обнаружен, возможны проблемы и ошибки. Принудительная остановка программы.")
    os.exit()
  end
  print("\n Все компоненты в наличии.\n Программа может быть запущена.")
end

function KOPALKA.mine(x, z, bedrock, side, x_lim, z_lim)
  KOPALKA.check_components()
  lc.xMax = x
  lc.zMax = z
  way = 0
  term.clear()
  sendSt("Старт карьера: "..x.."x"..z.." блоков.")
  KOPALKA.check_state()
  local side = KOPALKA.whatsSide()
  local ok, err = pcall(KOPALKA.geoMiner, x, z, bedrock, side, x_lim, z_lim)
  if not ok then
    if type(err) ~= "table" then
      sendSt(err)
    end
    back_to_the_future_mode = true
    sendSt('Ошибка/препятствие. Возврат робота.')
    KOPALKA.mTo(lc.x, 0, lc.z)
    KOPALKA.home()
    KOPALKA.rot(3)
  end
  if warp then event.ignore("modem_message", OnModemMessage) end
end

function main(tArgs, options)
  local function argNumber(x)
    local v = tonumber(x)
    if type(v) ~= 'number' then
      io.write("Аргументы должны быть заданы в виде чисел.\n")
      os.exit(1)
    end
    return v
  end
  
  local function getNumberOption(name)
    local v = options[name]
    if v then
      v = argNumber(v)
    end
    return v
  end
  
  if #tArgs == 2 then
    bedrockWidth = getNumberOption("bedrock-width") or bedrockWidth
    minHardness = getNumberOption("min-hardness") or minHardness
    maxHardness = getNumberOption("max-hardness") or maxHardness
    local x = argNumber(tArgs[1])
    local z = argNumber(tArgs[2])
    KOPALKA.mine(x, z, getNumberOption("bedrock"))
  else
    io.write("Запуск: kopalka размер_вперёд размер_справа\n")
    io.write("Опции:\n")
    io.write("--min-hardness=<мин. плотность>\n")
    io.write("--max-hardness=<макс. плотность>\n")
    io.write("--bedrock=<нижний уровень бедрока относительно робота> ")
    io.write("= высота_нижнего_слоя_бедрока-высота_на_которой_стоит_робот> - \n")
    io.write("--bedrock-width=<ширина слоя бедрока>\n")
    io.write("Робот будет добывать блоки,\nплотность которых находится \nв интервале (<мин. плотность>, <макс. плотность>).\n")
    io.write("Значение по умолчанию: ("..minHardness..", "..maxHardness..").\n")
  end
end

main(shell.parse(...))