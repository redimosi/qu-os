# qu-os

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