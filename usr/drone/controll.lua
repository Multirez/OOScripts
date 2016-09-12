-- provide UI for wireless interaction with weeprom instance(drone, robot, controller)
local term = require("term")
local component = require("component")
local computer = require("computer")
local event = require("event")
local modem = component.proxy(component.list("modem")())
local targetPort = 14
local basePort = 10
 
modem.open(basePort)
 
function onModemMessage(_, _, senderAddress, _, distance, status, result , ...)
    print("from:" .. senderAddress, "distance:" .. distance, "status:".. status, "msg:", result, "other:", ...)
end
 
if event.listen("modem_message", onModemMessage) then
    print("Successfully subscribe to modem messages!")
else
    print("Can't to subscribe to modem messages!")
end
 
while true do
    local message = term.read()
    modem.broadcast(targetPort, message)
end
