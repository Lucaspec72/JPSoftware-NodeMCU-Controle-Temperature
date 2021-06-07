mqtt_client = mqtt.Client(MQTTCLIENTID, 30, MQTTUSERNAME, MQTTPASSWORD)
function turnoffled()
    gpio.mode(4,gpio.OUTPUT)
    gpio.write(4,gpio.HIGH)   
end
mqtt_client:on("message", 
     function(client, topic, data)
         tmr.create():alarm(1, tmr.ALARM_SINGLE, turnoffled)
         gpio.mode(4,gpio.OUTPUT)
         gpio.write(4,gpio.LOW)
         if(topic == tostring(topic_main.."-pincontrol")) then
            print("Message received on pin control topic")
            ProcessPin(topic, data)
         end
     end
)
mqtt_client:on("overflow", 
    function(client, topic, data)
        tmr.create():alarm(1, tmr.ALARM_SINGLE, turnoffled)
        gpio.mode(4,gpio.OUTPUT)
        gpio.write(4,gpio.LOW)
        print(topic .. " partial overflowed message: " .. data )
    end
)
-- Callbacks for MQTT connection
function mqtt_connected(client)
    is_mqtt_connected = true
    print("Connected to MQTT broker")
    -- TOPIC SCHEMA
    --  topic
    --  |    -log           (NodeMCU -> MQTT (for debug))
    --  |    -dht           (NodeMCU -> Home Assistant)
    --  |    -pincontrol    (Home Assistant -> NodeMCU)
    --  |    -pinstate
    --  |             -0    (NodeMCU -> Home Assistant)
    --  |             -2    (NodeMCU -> Home Assistant)
    --  |             -3    (NodeMCU -> Home Assistant)
    --  |             -4    (NodeMCU -> Home Assistant)
    --  |             -5    (NodeMCU -> Home Assistant)
    --  |             -6    (NodeMCU -> Home Assistant)
    --  |             -7    (NodeMCU -> Home Assistant)
    --  |             -8    (NodeMCU -> Home Assistant)
    mqtt_client:subscribe({[topic_main.."-pincontrol"]=0,topic_main=0}, function(conn) print("subscribe success") end)
    dofile('main.lua')
end
function mqtt_connection_error(client, reason)
    is_mqtt_connected = false
    print("Could not connect, " ..reason)
    print("Retrying in 5 seconds...")
    tmr.create():alarm(5 * 1000, tmr.ALARM_SINGLE, do_mqtt_connect)
end
function mqtt_offline(client)
    is_mqtt_connected = false
    print("MQTT broker offline !")
    print("Retrying in 5 seconds...")
    tmr.create():alarm(5 * 1000, tmr.ALARM_SINGLE, do_mqtt_connect)
end
function do_mqtt_connect()
    if(is_mqtt_connected == false) then
        print("Connecting to MQTT broker...")
        mqtt_client:connect(MQTTIP, MQTTPORT, false, mqtt_connected, mqtt_connection_error)
    end
end

mqtt_client:on("offline", mqtt_offline)
do_mqtt_connect()
