local dht = require 'dht'

message="Not checked yet."
temp = 0.0
humi = 0.0

function GetInformationFromText(response, tag)
    return
       ((response:match((("<@>(.-)</@>"):gsub("@",tag))) or "")
       :gsub("&(%w+);", {lt = "<", gt = ">", amp = "&"}))
 end
 
 -- exemple de message
 -- <IOPORT>4</IOPORT>
 -- <ACTION>SETVALUE</ACTION>
 -- <VALUE>HIGH</VALUE>
 
function InArray(input,array)
    for i, arrayitem in pairs(array) do
        if(arrayitem==input) then
            return true
        elseif(type(arrayitem)~=type(input)) then
            print("'WARNING :' type mismatch, attempting conversion to string...")
            print("Array entry n°"..i.." ; Contains : "..arrayitem.." ; Type : "..type(arrayitem))
            print("Variable : "..input.." ; Type : "..type(input))
            if(tostring(arrayitem)==tostring(input)) then
                print("'Automatic Resolution Successful !'")
                return true
            end
        end
    end
end
 
function ProcessPin(topic, data)
    local ioport
    local operation
    local parametre
    data = string.upper(data)
    ioport = GetInformationFromText(data,"IOPORT")
    operation = GetInformationFromText(data,"ACTION")
    parametre = GetInformationFromText(data,"VALUE")
--pinarray may be wrong
    if InArray(tonumber(ioport),PINARRAY) and operation~="" then
        if operation == "SETVALUE" and parametre~="" then
            gpio.mode(ioport,gpio.OUTPUT)
            if parametre == "HIGH" then
                gpio.write(ioport,gpio.HIGH)
                print("Pin "..ioport.." Set to "..gpio.read(ioport))
                mqtt_client:publish(topic_main.."-pinstate-"..ioport,gpio.read(ioport), 0, 0, function(client) print("Sent pin state to MQTT broker") end)
            end   
            if parametre == "LOW" then
               gpio.write(ioport,gpio.LOW)
               print("Pin "..ioport.." Set to "..gpio.read(ioport))
               mqtt_client:publish(topic_main.."-pinstate-"..ioport,gpio.read(ioport), 0, 0, function(client) print("Sent pin state to MQTT broker") end)
            end
        end
    end
end

function send_atmo_to_mqtt(temp, humi, temp_dec, humi_dec)
    if(is_mqtt_connected) then
        mqtt_client:publish(topic_main.."-dht",
                "{\"temperature\":"..temp.." , \"humidity\":"..humi.."}", 0, 0, function(client) print("Atmospheric Data sent to MQTT broker") end)
    else
        print("Atmospheric Data not sent to MQTT broker : not connected")
    end
end
check_dht = tmr.create()
check_dht:register(5 * 1000, tmr.ALARM_AUTO, function()
    gpio.mode(DHTPIN,gpio.INPUT)
    print("Reading data from DHT...")
    status, temp, humi, temp_dec, humi_dec = dht.read(DHTPIN)
    if status == dht.OK then
        message = ("DHT Temperature:"..temp.."°c ".."Humidity:"..humi.."%")
        send_atmo_to_mqtt(temp, humi, temp_dec, humi_dec)
    elseif status == dht.ERROR_CHECKSUM then
        message = "Checksum error."
    elseif status == dht.ERROR_TIMEOUT then
        message = "Timed out."
    end
    print("Data read from DHT : "..message)
    -- Also update the state of the switches
    for i, pin in pairs(PINARRAY) do
        mqtt_client:publish(topic_main.."-pinstate-"..pin,gpio.read(pin), 0, 0, 0)
    end
end)
check_dht:start()

total_allocated, estimated_used = node.egc.meminfo()

srv=net.createServer(net.TCP)
srv:listen(80,function(conn)
    conn:on("receive",function(client,payload)
        url_suffix = string.sub(payload,string.find(payload,"GET /") + 5,string.find(payload,"HTTP/")-2)
        text = "Currently Allocated Memory : "..total_allocated.." bytes ("..(total_allocated/1000).." kb)\n"
        text = text.."DHT22 Readings : "..message .. "\n"
        for i, pin in pairs(PINARRAY) do
            text = text .. "Pin "..pin.." : "..gpio.read(pin).."\n"
      end
        client:send(text)
    end)
    conn:on("sent",function(client)
        client:close()
        collectgarbage()
    end)
end)
