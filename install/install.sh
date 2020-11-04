#!/bin/bash

RELATIVE_PATH="`dirname \"$0\"`"
ABSOLUTE_PATH="`realpath \"$0\"`"
ABSOLUTE_DIR="`dirname $ABSOLUTE_PATH`"
echo "Script Path: $ABSOLUTE_PATH"

FOLDER_NAME="qu-os"
NUC_DETECTED=0
MOSQUITTO_CHANGED=0

if [[ $ABSOLUTE_PATH == *"/home/qu/"* ]]; then
    NUC_DETECTED=1
    echo "Detected Target"
  else
    echo "Target no detected"
  fi

cmd=$1
if [[ -z $cmd ]]; then
  if [[ $NUC_DETECTED -eq 0 ]]; then
    cmd="remote"
  else
    cmd="local"
  fi
fi

function uninstall {
  apt remove -y mosquitto
  find qu-os/install/etc/ -type f | cut -sd / -f 4- | xargs -I % rm -v "/etc/%"
  rm -fv "/etc/mosquitto/passwd"
  rm -rfv "$FOLDER_NAME"
}

function update {
    cd $FOLDER_NAME
    pull=`su -c "git pull" qu`
    cd ~
    echo "$pull"
    if [[ $pull != "Already up to date." ]]; then
      echo "Restart updated script..."
      $ABSOLUTE_PATH
      exit
    fi
}

function listMqttUsers {
  users=`cat /etc/mosquitto/passwd | cut -d':' -f1 | xargs -I % echo "% " | tr -d '\n'`
  echo "currently registered users are: $users"
}

function addMqttUser {
  listMqttUsers
  read -p "Enter mqtt username if you want to add one []: " response
  if [[ ! -z $response ]]; then
    mosquitto_passwd /etc/mosquitto/passwd "$response"
    MOSQUITTO_CHANGED=1
  fi
}

function deleteMqttUser {
  listMqttUsers
  read -p "Enter mqtt username if you want to delete one []: " response
  if [[ ! -z $response ]]; then
    mosquitto_passwd -D /etc/mosquitto/passwd "$response"
    MOSQUITTO_CHANGED=1
  fi
  listMqttUsers
}

function checkRestartMosquitto {
  if [[ $MOSQUITTO_CHANGED -ne 0 ]]; then
    echo "Mosquitto will be restarted ..."
    systemctl stop mosquitto
    systemctl start mosquitto
    systemctl status mosquitto
  fi
}

function enableMosquittoLogDebug {
  if grep -Fq "log_type" /etc/mosquitto/mosquitto.conf
  then
      sed -i 's/log_type[ a-z]*/log_type all/' "/etc/mosquitto/mosquitto.conf"
  else
      echo "log_type all" >> "/etc/mosquitto/mosquitto.conf"
  fi
  MOSQUITTO_CHANGED=1
}

function disableMosquittoLogDebug {
  if grep -Fq "log_type" /etc/mosquitto/mosquitto.conf
  then
      sed -i '/log_type[ a-zA-Z]*/d' "/etc/mosquitto/mosquitto.conf"
      MOSQUITTO_CHANGED=1
  fi
}

case $cmd in
  "remote") ;;
  "local") ;;
  "docker") ;;
  "logmqttall") 
    enableMosquittoLogDebug
    checkRestartMosquitto
    exit
    ;;
  "logmqttstd") 
    disableMosquittoLogDebug
    checkRestartMosquitto
    exit
    ;;
  "addmqttuser")
    addMqttUser
    checkRestartMosquitto
    exit
    ;;
  "delmqttuser")
    deleteMqttUser
    checkRestartMosquitto
    exit
    ;;
  "update") 
    update
    exit
    ;;
  "uninstall") 
    uninstall
    exit
    ;;
  *) echo "
  install.sh [option]

  option:
    [empty]     remote/local depending on execution path
    addmqttuser Adds a new mqtt user
    delmqttuser Deletes a new mqtt user
    logmqttall  mqtt log all
    logmqttstd  mqtt log default
    remote      Basic install on remote device
    local       Do Install locally
    docker      Do Install docker (ATTENTION: experimental)
    update      Pull update from GitHub
    uninstall   ATTENTION: Deletes everything
    help        Shows this help
  "
  exit
esac

if [[ $cmd == "remote" ]]; then
  read -p "TRY REMOTE INSTALLATION(y/n)? [y]: " response
  if [ -z $response ] || [ $response != "n" ]; then
    read -p "Enter Device IPv4 to install the script: " device_ip
    if [[ -z $device_ip ]]; then
      device_ip="nuc-mqtt-1"
      echo "no IP entered, try with $device_ip!"
    fi
    echo "YOU WILL BE ASKED TO ENTER THE PASSWORD SEVERAL TIMES!"
    code=`ssh "qu@$device_ip" "sh -c \"if [ -d $FOLDER_NAME ]; then echo 1 ; else echo 0 ; fi\" "`
    doClone=0
    if [[ $code -ne 0 ]]; then
      read -p "Folder $FOLDER_NAME already exists on target. Want to overwrite (y/n)? [n]: " response
      if [[ $response == "y" ]]; then 
        ssh "qu@$device_ip" "sh -c \"rm -rf $FOLDER_NAME\" "
        if [[ $? -eq 0 ]]; then
          echo "SUCCESS: folder deleted"
          doClone=1
        else
          echo "ERROR: on folder deletion"
        fi
      else
        read -p "Want to do git pull to update(y/n)? [y]: " response
        if [ -z $response ] || [ $response != "n" ]; then
          ssh "qu@$device_ip" "sh -c \"cd $FOLDER_NAME; git pull\" "
        fi
      fi
    else
      doClone=1
    fi
    if [[ doClone -eq 1 ]]; then
      echo "Clone files on target with git clone"
      ssh "qu@$device_ip" "sh -c \"git clone https://github.com/redimosi/qu-os.git\" "
      code=$?
      if [[ $code -ne 0 ]]; then
        echo "ERROR on Clone with code: $code"
        exit 1
      fi
    fi
    read -p "Want to proceed with installation on device(y/n)? [y]: " response
    if [ -z $response ] || [ $response != "n" ]; then
      ssh -t "qu@$device_ip" "sudo sh -c \"chmod +x $FOLDER_NAME/install/install.sh\" && sudo sh -c $FOLDER_NAME/install/install.sh"
    fi
  fi
  exit 0
fi

if [[ $NUC_DETECTED -eq 0 ]]; then
  read -p "script is not executed on target device, proceed(y/n)? [n]: " response
  if [[ $response != "y" ]]; then
    exit 
  fi
fi

# check run as root
if [ "$EUID" -ne 0 ]
    then echo "Please run as root"
    exit
fi

read -p "apt install tools(y/n)? [n]: " response
if [[ $response == "y" ]]; then
  apt-get update
  apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
fi

if [[ $cmd == "docker" ]]; then
  read -p "Docker needed?(y/n)? [n]: " response
  if [[ $response == "y" ]]; then 
    read -p "download & install docker gpg key(y/n)? [y]: " response
    if [ -z $response ] || [ $response != "n" ]; then
      curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
    fi

    read -p "add docker apt repo(y/n)? [y]: " response
    if [ -z $response ] || [ $response != "n" ]; then
      add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/debian \
        $(lsb_release -cs) \
        stable"
    fi

    read -p "apt install docker(y/n)? [y]: " response
    if [ -z $response ] || [ $response != "n" ]; then
      apt-get update
      apt-get install -y docker-ce docker-ce-cli containerd.io
    fi

    read -p "add current user to docker group(y/n)? [y]: " response
    if [ -z $response ] || [ $response != "n" ]; then
      usermod -aG docker qu
    fi

    read -p "create git function in .profile(y/n)? [y]: " response
    if [ -z $response ] || [ $response != "n" ]; then
      echo '
    function git () {
      (docker run -ti --rm -v ${HOME}:/root -v $(pwd):/git alpine/git "$@")
    }
    ' >> ~/.profile
    fi
  fi
fi


read -p "Check & Update qu-os(y/n)? [y]: " response
if [ -z $response ] || [ $response != "n" ]; then
  update
fi



read -p "Install mosquitto(y/n)? [y]: " response
if [ -z $response ] || [ $response != "n" ]; then
  apt get update
  apt install -y mosquitto
  systemctl stop mosquitto
  read -p "Add mqtt user(username)? [qu]: " response
  if [[ -z $response ]]; then
    response="qu"
  fi
  mosquitto_passwd -c /etc/mosquitto/passwd $response
  MOSQUITTO_CHANGED=1
fi

addMqttUser

deleteMqttUser

read -p "copy several scripts(y/n)? [y]: " response
if [ -z $response ] || [ $response != "n" ]; then
  cp -r -v $ABSOLUTE_DIR/etc/* /etc
  MOSQUITTO_CHANGED=1
fi

checkRestartMosquitto

exit
read -p "(y/n)? [y]: " response
if [ -z $response ] || [ $response != "n" ]; then
  #
fi
read -p "(y/n)? [n]: " response
if [[ $response == "y" ]]; then
  #
fi

