#!/bin/bash

RELATIVE_PATH="`dirname \"$0\"`"
ABSOLUTE_PATH="`realpath \"$0\"`"
ABSOLUTE_DIR="`dirname $ABSOLUTE_PATH`"
echo "Script Path: $ABSOLUTE_PATH"

FOLDER_NAME="qu-os"
NUC_DETECTED=0

cmd=$1
if [[ -z $cmd ]]; then
  if [[ $ABSOLUTE_PATH == *"/home/qu/"* ]]; then
    cmd="local"
    NUC_DETECTED=1
    echo "Detected Target, do local installation"
  else
    cmd="remote"
    echo "Target no detected, do remote installation"
  fi
fi

function uninstall {
  apt remove -y mosquitto
  find qu-os/install/etc/ -type f | cut -sd / -f 4- | xargs -I % rm -v "/etc/%"
  rm -fv "/etc/mosquitto/passwd"
  rm -rfv "$FOLDER_NAME"
}

case $cmd in
  "remote") ;;
  "local") ;;
  "docker") ;;
  "update") ;;
  "uninstall") 
    uninstall
    exit
    ;;
  *) echo "
  install [option]

  option:
    [empty]   remote/local depending on execution path
    remote    Basic install on remote device
    local     Do Install locally
    docker    Do Install docker (ATTENTION: experimental)
    update    Pull update from GitHub
  "
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

if [[ $cmd == "update" ]]; then
  read -p "Check & Update qu-os(y/n)? [y]: " response
  if [ -z $response ] || [ $response != "n" ]; then
    cd $FOLDER_NAME
    pull=`su -c "git pull" qu`
    cd ~
    echo "$pull"
    if [[ $pull != "Already up to date." ]]; then
      echo "Restart updated script..."
      $ABSOLUTE_PATH
      exit
    fi
  fi
fi

mosquitto_restart=0
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
  mosquitto_restart=1
fi

read -p "Want to add another mqtt user(username)? [SKIP]: " response
if [[ ! -z $response ]]; then
  mosquitto_passwd /etc/mosquitto/passwd "$response"
  mosquitto_restart=1
fi

read -p "Want to delete mqtt user(username)? [SKIP]: " response
if [[ ! -z $response ]]; then
  mosquitto_passwd -D /etc/mosquitto/passwd "$response"
  mosquitto_restart=1
fi

read -p "copy several scripts(y/n)? [y]: " response
if [ -z $response ] || [ $response != "n" ]; then
  cp -r -v $ABSOLUTE_DIR/etc/* /etc
  mosquitto_restart=1
fi

if [[ $mosquitto_restart -ne 0 ]]; then
  echo "Mosquitto will be restarted ..."
  systemctl stop mosquitto
  systemctl start mosquitto
  systemctl status mosquitto
fi

exit
read -p "(y/n)? [y]: " response
if [ -z $response ] || [ $response != "n" ]; then
  #
fi
read -p "(y/n)? [n]: " response
if [[ $response == "y" ]]; then
  #
fi

