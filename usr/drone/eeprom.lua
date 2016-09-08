--[[ eeprom for wireless controll of drone, robot or oany other devise from opencomputers
	Author: Multirezonator]]

modem = component.proxy(component.list("modem")())
eeprom = component.proxy(component.list("eeprom")())

basePort = 10
port = 14
modem.open(port)
modem.broadcast(basePort, "init_" .. eeprom.getLabel())

while true do
    _, targetAddress, remoteAddress, msgPort, distance, payload = computer.pullSignal("modem_message")
    
    if targetAddress == modem.address then 
        local isOk, result = pcall(load(payload))
                
        modem.send(remoteAddress, basePort, isOk, result)
    end
end

