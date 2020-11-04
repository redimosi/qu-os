# qu-os

## Use NUC

1. Connect NUC to same LAN as Shellies  
2. Power ON  
3. NUC will startup and be ready in about 30s  
4. MQTT-Broker is ready to use

## Test MQTT Broker  

1. Install MQTT.FX:  
   https://mqttfx.jensd.de/index.php/download
2. Setup connection profile:  
   File -> Edit Connection Profiles  
   Left lower corner +  
   Profile Type = MQTT Broker  
   Broker Address = IP or nuc-mqtt-1  
   Broker Port = 1883  
   Client ID = Choose one, but must be unique  
   General = Default settings are fine  
   User Credentials = the ones u choosen within install script  
3. Connect with profile  
4. Subscribe to Topic #  
   If Shellies already communicate you should see the messages on the right side
5. Publish  
   e.g. to switch relay:  
   Topic: shellies/shelly1pm-F26D85/relay/0/command
   Data: on/off

## Edit MQTT Broker

1. Connect to NUC with `ssh qu@nuc-mqtt-1`  
2. Check what you can do with `sudo qu-os/install/install.sh`  

## Produce fresh NUC  

1. Prepare NUC with Debian 10 (buster)  
   Easiest way is to clone with Clonezilla  
   If you need to install from scratch, make sure "qu" user exists and is in sudoers group  
2. Install "qu-os" on NUC  
   1. Login to you favourite linux shell  
   2. Clone https://github.com/redimosi/qu-os.git  
   3. Execute qu-os/install/install.sh
   4. Follow the guidance
3. Setup Shelly  
   1. Add shelly to same network as your NUC  
   2. Go to Internet & Security -> Advanced - Developer Settings
   3. Setup correct mqtt server settings:  
       enable":true,  
       "server":"192.168.?.?:1883",  
       "user":"qu",  
       "password":"??"  
4. Test with MQTT.fx  


