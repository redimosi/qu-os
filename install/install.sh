#!/bin/bash

RELATIVE_PATH="`dirname \"$0\"`"
ABSOLUTE_PATH="`realpath \"$0\"`"
echo "Script Path: $ABSOLUTE_PATH"
FOLDER_NAME="qu-os"

cmd=$1
if [[ -z $cmd ]]; then
  if [[ $ABSOLUTE_PATH == *"/home/qu/"* ]]; then
    cmd="local"
    echo "Detected Target, do local installation"
  else
    cmd="remote"
    echo "Target no detected, do remote installation"
  fi
fi

case $cmd in
  "remote") ;;
  "local") ;;
  *) echo "
  install [option]

  option:
    remote    Basic install on remote device
    local     Do Install locally
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

# check run as root
if [ "$EUID" -ne 0 ]
    then echo "Please run as root"
    exit
fi

read -p "apt update(y/n)? [y]: " response
if [ -z $response ] || [ $response != "n" ]; then
  apt-get update
fi

read -p "apt install tools(y/n)? [y]: " response
if [ -z $response ] || [ $response != "n" ]; then
  apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
fi

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

read -p "Check & Update qu-os(y/n)? [y]: " response
if [ -z $response ] || [ $response != "n" ]; then
  cd $FOLDER_NAME
  pull=`git pull`
  echo "$pull"
  if [[ $pull -ne "Already up to date." ]]; then
    echo "Restart updated script..."
    sudo sh -c "$ABSOLUTE_PATH"
    exit
  fi
fi

read -p "copy several scripts(y/n)? [y]: " response
if [ -z $response ] || [ $response != "n" ]; then
  cp -r $RELATIVE_PATH
/etc/* /etc
fi

exit
read -p "(y/n)? [y]: " response
if [ -z $response ] || [ $response != "n" ]; then
  #
fi
