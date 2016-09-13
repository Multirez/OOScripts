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
table.add(storages, component.list("mfe"))

function printStorage(isColorBar)
  local p, s, c = nil, 0, 0
  -- sum data from all storages
  for a, n in pairs(storages) do
    p = component.proxy(a)
    if p ~= nil then
      s = s + p.getStored()
      c = c + p.getCapacity()
    end
  end
  if(c<=0) then c = 1 end
  -- time interval
  local newTimePoint = computer.uptime()
  local timeInterval = newTimePoint - updateTimePoint
  updateTimePoint = newTimePoint
  -- calc in/out diff
  local inout = (s - lastStored) / timeInterval / 20
  lastStored = s
  local progress = math.floor(s / c * 12)
  local bar = string.rep("+", progress) .. string.rep("-", 12 - progress)
  -- print results
  gpu.setForeground(0x76E2FF)
  print(string.format(" Capacity: %4i %03i %03i", c/1000000, (c % 1000000)/1000, c % 1000))
  print(string.format("   Energy: %4i %03i %03i", s/1000000, (s % 1000000)/1000, s % 1000))
  print(string.format("%3i%% Fill: %12s", math.floor(s / c * 100), bar))
  if(isColorBar) then
    gpu.setForeground(0xFFA500)
    gpu.setForeground(0xFFD376)
    gpu.set(12, 4, string.rep("+", progress))
  end
  if (inout < 0) then
    gpu.setForeground(0xFF0000)
    gpu.setForeground(0xFF7676)
  else
    gpu.setForeground(0x00FF00)
    gpu.setForeground(0x76FF88)
  end
  print(string.format("   In/Out: %12i", inout))
end

print("storage list:")
printt(storages)
printStorage()
gpu.setForeground(0xFFFFFF)

print("Show info panel? (1/0)")
local input = tonumber(io.read())
if (input ~= nil and input == 1) then
  gpu.setResolution(24, 5)
  gpu.setBackground(0x000000)
  term.clear()
  local eName = nil
  while eName == nil do
    term.setCursor(1, 2)
    printStorage(true)
    eName = event.pull(updateInterval, "interrupted")
  end
  gpu.setResolution(gpu.maxResolution())
  gpu.setForeground(0xFFFFFF)
end
