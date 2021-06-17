--Setting up pin 4 for config boot override.
gpio.mode(1,gpio.INPUT)
--set flag
is_mqtt_connected=false
--Microcontroller-specific config & Hardcoded Values
--PINARRAY is hardcoded due to issues with the configuration fomr
PINARRAY = {0,2,3,4,5,6,7,8}
MQTTCLIENTID=node.chipid()
topic_main=node.chipid()

for i, arrayitem in pairs(PINARRAY) do
    gpio.mode(arrayitem,gpio.OUTPUT)
    gpio.write(arrayitem,gpio.HIGH)
end
if file.exists("config.ini") then
    dofile("config.ini")
    ConfigCheck=1
else
    BootDelay=10
    ConfigCheck=0
    print("Could not load configuration file, using fallback bootdelay. ("..BootDelay.."sec.)")
end

function startup()
    if (ConfigCheck == 0) or (gpio.read(1) == 1) then
        print("Booting in configuration mode")
        if gpio.read(1) == 1 then
          print("'CONFIG MODE' Reason : Boot override pin triggered")
        end
        if not file.exists("config.ini") then
            print("'CONFIG MODE' Reason : Config file missing.")
        end
        wifi.sta.clearconfig()
        wifi.setmode(wifi.SOFTAP)
        wifi.ap.config({ssid="NODEMCU-"..node.chipid().."-CONFIG", pwd="password", save=false})
        wifi.ap.setip({ip="192.168.1.254", netmask="255.255.255.0", gateway="192.168.1.254"})
        wifi.ap.dhcp.config({start="192.168.1.100"})
        wifi.ap.dhcp.start()
        print("'CONFIG MODE' Access point and DHCP online")
        t = {}
        if(ConfigCheck == 1) then
            s = file.getcontents('config.ini')
            for k, v in string.gmatch(s, "([%w%p]+)%s*=%s*([%p%b%w]+)") do
                t[k] = v
            end
        else
            --set fallback (default) list
            t[BootDelay] = ""
            t[DHTPIN] = ""
            t[WIFISSID] = ""
            t[WIFIPASSWORD] = ""
            t[MQTTIP] = ""
            t[MQTTPORT] = ""
            t[MQTTUSERNAME] = ""
            t[MQTTPASSWORD] = ""
        end
        --WEBCODE
         web="<!DOCTYPE html><html><head><title>Configuration NodeMCU</title></head><body><h3>Bienvenue sur l'interface de configuration du NodeMCU n°"..node.chipid().."</h3><FORM METHOD=\"get\" ACTION=\"/form_send\"><TABLE BORDER=\"1\">"
         for i, pin in pairs(t) do
            web=web.."<TR><TD>"..i.."</TD><TD><INPUT TYPE=\"TEXT\" NAME=\""..i.."\" VALUE="..pin.." SIZE=\"20\"></TD></TR>"
         end
         web=web.."<tfoot><tr><td colspan=\"2\"><INPUT TYPE=\"SUBMIT\" VALUE=\"Mettre à jour la configuration\" style=\"width: 100%;\"></td></tr></tfoot></TABLE></FORM></body></html>"
         srv=net.createServer(net.TCP)
         srv:listen(80,function(conn)
              conn:on("receive", function(client,request)
                   local buf = "";
                   local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)%?(.-) HTTP");
                   if(method == nil)then _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP"); end
                   local _GET = {}
                   if (vars ~= nil)then for k, v in string.gmatch(vars, "(%w+)=([%_%\\.%\\-%{%}%w]+)&*") do _GET[k] = v end end
                   -- Now we can use _GET['name'] or _GET.name
                   print("\nMethod: "..method);
                   print("Path: "..path);
                   if(path == "/form_send")then
                          print("writing to (placeholder) config file")
                          file.open("config.ini","w+")
                          web=web.."<br><p>Configuration mise à jour !</p><br><p>Nouvelle configuration :</p><br><br>"
                          for i, pin in pairs(_GET) do
                              file.writeline(i.."=".."\""..pin.."\"")
                              web=web..i.."=".."\""..pin.."\"<br>"
                          end
                          file.close()
                   end
                   for i, pin in pairs(_GET) do
                        print(i.." = "..pin)
                   end
                   client:send(web)
                   end)
              conn:on("sent",function(client)
                  client:close()
                  collectgarbage()
              end)
end)
    else
        print("Booting in normal mode")
        wifi.setmode(wifi.STATION)
        wifi.sta.config({ssid=WIFISSID, pwd=WIFIPASSWORD, save=false})
        wifi.sta.connect()
        print ("Connecting to Wi-Fi "..WIFISSID.."...")
        count=1
        ConnectionLoop = tmr.create()
        ConnectionLoop:register(1 * 1000, tmr.ALARM_AUTO, function()
            if count>9 then
                print("Try "..count.."/10 failed.\nERROR : could not connect to access point.")
                ConnectionLoop:stop()
            elseif wifi.sta.getip()== nil then
                print("Try "..count.."/10 failed, retrying..")
                count = count+1
            else
                ConnectionLoop:stop()
                print("Try "..count.."/10 successful !\nConnected to "..WIFISSID.." !")
                print("IP : "..wifi.sta.getip())
                print("MAC address : " .. wifi.ap.getmac())
                print("Hostname : "..wifi.sta.gethostname())
                dofile("mqtt.lua")
            end
        end)
        ConnectionLoop:start()
    end
end
print ("init.lua started : "..(BootDelay).." sec. delay before running main program")
tmr.create():alarm(BootDelay * 1000, tmr.ALARM_SINGLE, startup)
