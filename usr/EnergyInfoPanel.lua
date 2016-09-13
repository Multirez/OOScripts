--[[ Energy storage panel
    Author: Multirez ]]--

local computer = require("computer")
local component = require("component")
local term = require("term")
local event = require("event")
local gpu = component.gpu

local storages = {}
local lastStored = 0
local updateTimePoint = computer.uptime()
local updateInterval = 10 -- seconds

function table.add(target, source)
  for a, n in pairs(source) do 
    target[a] = n 
  end
end

function printt(table)
  for a, n in pairs(table) do
    print(a, n)
  end
end

table.add(storages, component.list("afsu"))
table.add(storages, component.list("mfsu"))
table.add(storages, component.list("mfu"))

function printStorage()
  local p, s, c = nil, 0, 0
  -- sum data from all storages
  for a, n in pairs(storages) do
    p = component.proxy(a)
    s = s + p.getStored()
    c = c + p.getCapacity()
  end
  -- time interval
  local newTimePoint = computer.uptime()
  local timeInterval = newTimePoint - updateTimePoint
  updateTimePoint = newTimePoint
  -- calc in/out diff
  local inout = (s - lastStored) / timeInterval / 20
  lastStored = s
  local progress = math.floor(s / c * 10)
  local bar = string.rep("+", progress) .. string.rep("-", 10 - progress)
  -- print results
  print(string.format(" Capacity: %10i", c))
  print(string.format("   Energy: %10i", s))
  print(string.format("     Fill: %10s", bar))
  print(string.format("   In/Out: %10i", inout))
end

print("storage list:")
printt(storages)
printStorage()

print("Show info panel? (1/0)")
local input = tonumber(io.read())
if (input ~= nil and input == 1) then
  gpu.setResolution(22, 5)
  gpu.setForeground(0x000000)
  gpu.setBackground(0xFFFFFF)
  term.clear()
  local eName = nil
  while eName == nil do
    term.setCursor(1, 2)
    printStorage()
    eName = event.pull(updateInterval, "interrupted")
  end
  gpu.setResolution(gpu.maxResolution())
end
