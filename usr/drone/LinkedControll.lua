-- provide UI for interaction with instance(drone, robot, controller) thought linked card
-- Author Multirez

local component = require("component")
local computer = require("computer")
local event = require("event")
local term = require("term")
local tunnel = component.proxy(component.list("tunnel")())
local infoSize = 3

-- queue lib
local queue = {}

function queue.new()
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

-- messages
local messageList = queue.new()

function Time2String(time)
    local seconds = time / 100
    local minutes = seconds / 60
    local hours = minutes / 60
    local days = hours / 24
    return string.format("%i:%02i:%02i", (hours % 24), (minutes % 60), (seconds % 60))
end

function onMessage(_, _, senderAddress, _, distance, status, result , ...)   
    messageList:push(string.format(" msg:%s %s from:%s  ", status, Time2String(os.time()), senderAddress) .. (result or "") .. "\n")
    if(messageList:count() > infoSize) then
        messageList:pull()
    end
    drawInfo()
end

function drawInfo()
    local gpu = component.gpu  
    local x, y = gpu.getResolution()
    gpu.fill(1,1, x, infoSize+2, "*")
    for i=1, infoSize do
        gpu.set(2, i+1, messageList[messageList.firstIndex + i - 1])
    end
end


print("Input size for info panel (rows):") 
local input = tonumber(io.read())
if (input ~= nil and input > 1) then
    infoSize = input
end

-- init info data
for i=1, infoSize do
    messageList:push("-empty-")
end
-- move user cursor down
local posX, posY = term.getCursor()
while(posY <= (infoSize+2)) do
    print("")
    posY = posY+1
end
-- draw info panel
drawInfo()

-- listen to modem messages
if event.listen("modem_message", onMessage) then
    print("Successfully subscribe to modem messages!")
else
    print("Can't to subscribe to modem messages!")
end

-- send user input wia tunnel
while true do
    local message = io.read()
        tunnel.send(message)
end
