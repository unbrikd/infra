#!/usr/bin/env bash
set -e
source <(curl -s https://raw.githubusercontent.com/unbrikd/infra/refs/heads/feature/add-pve-helper-for-yocto-kvm/proxmox/misc/common.sh)

# KVM Setup Details
GEN_MAC=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
NEXTID=$(pvesh get /cluster/nextid)
WHIPTAIL_BACKTITLE="${FOOTER}"
WHIPTAIL_TITLE="Yocto Linux KVM"

# KVM Default Settings


# Set the trap handlers
# When an ERR signal is received, call the error_handler function
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
# When the script exits unexpectedly or (Ctrl+C), call the cleanup function
trap cleanup EXIT

# Set default settings for the machine to be created and print them to the console
# It allows the user to create the machine in a quick and easy way
function default_settings() {
  VMID="$NEXTID"
  FORMAT=",efitype=4m"
  MACHINE=""
  DISK_CACHE=""
  HN="yocto-kvm"
  CPU_TYPE=""
  CORE_COUNT="4"
  RAM_SIZE="4096"
  BRG="vmbr0"
  MAC="$GEN_MAC"
  VLAN=""
  MTU=""
  START_VM="yes"

  echo -e "${DGN}Using Virtual Machine ID: ${BGN}${VMID}${CL}"
  echo -e "${DGN}Using Machine Type:       ${BGN}i440fx${CL}"
  echo -e "${DGN}Using Disk Cache:         ${BGN}None${CL}"
  echo -e "${DGN}Using Hostname:           ${BGN}${HN}${CL}"
  echo -e "${DGN}Using CPU Model:          ${BGN}KVM64${CL}"
  echo -e "${DGN}Allocated Cores:          ${BGN}${CORE_COUNT}${CL}"
  echo -e "${DGN}Allocated RAM:            ${BGN}${RAM_SIZE}${CL}"
  echo -e "${DGN}Using Bridge:             ${BGN}${BRG}${CL}"
  echo -e "${DGN}Using MAC Address:        ${BGN}${MAC}${CL}"
  echo -e "${DGN}Using VLAN:               ${BGN}Default${CL}"
  echo -e "${DGN}Using Interface MTU Size: ${BGN}Default${CL}"
  echo -e "${DGN}Start VM when completed:  ${BGN}yes${CL}"

  echo -e "${BL}Creating a Yocto Linux KVM using the above default settings${CL}"
}

function get_vm_hn() {
  if VM_NAME=$(whiptail --backtitle "${WHIPTAIL_BACKTITLE}" --inputbox "Set Hostname" 8 58 gems-linux --title "HOSTNAME" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VM_NAME ]; then
      HN="yocto-kvm"
      echo -e "${DGN}Using Hostname: ${BGN}$HN${CL}"
    else
      HN=$(echo ${VM_NAME,,} | tr -d ' ')
      echo -e "${DGN}Using Hostname: ${BGN}$HN${CL}"
    fi
  else
    exit-script
  fi
}

function advanced_settings() {
  while true; do
    if VMID=$(whiptail --backtitle "${WHIPTAIL_BACKTITLE}" --inputbox "Set Virtual Machine ID" 8 58 $NEXTID --title "VIRTUAL MACHINE ID" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
      if [ -z "$VMID" ]; then
        VMID="$NEXTID"
      fi
      if pct status "$VMID" &>/dev/null || qm status "$VMID" &>/dev/null; then
        echo -e "${CROSS}${RD} ID $VMID is already in use${CL}"
        sleep 2
        continue
      fi
      echo -e "${DGN}Virtual Machine ID: ${BGN}$VMID${CL}"
      break
    else
      exit-script
    fi
  done

  if MACH=$(whiptail --backtitle "${WHIPTAIL_BACKTITLE}" --title "MACHINE TYPE" --radiolist --cancel-button Exit-Script "Choose Type" 10 58 2 \
    "i440fx" "Machine i440fx" ON \
    "q35" "Machine q35" OFF \
    3>&1 1>&2 2>&3); then
    if [ $MACH = q35 ]; then
      echo -e "${DGN}Using Machine Type: ${BGN}$MACH${CL}"
      FORMAT=""
      MACHINE=" -machine q35"
    else
      echo -e "${DGN}Using Machine Type: ${BGN}$MACH${CL}"
      FORMAT=",efitype=4m"
      MACHINE=""
    fi
  else
    exit-script
  fi

  if DISK_CACHE=$(whiptail --backtitle "${WHIPTAIL_BACKTITLE}" --title "DISK CACHE" --radiolist "Choose" --cancel-button Exit-Script 10 58 2 \
    "0" "None (Default)" ON \
    "1" "Write Through" OFF \
    3>&1 1>&2 2>&3); then
    if [ $DISK_CACHE = "1" ]; then
      echo -e "${DGN}Using Disk Cache: ${BGN}Write Through${CL}"
      DISK_CACHE="cache=writethrough,"
    else
      echo -e "${DGN}Using Disk Cache: ${BGN}None${CL}"
      DISK_CACHE=""
    fi
  else
    exit-script
  fi

  if VM_NAME=$(whiptail --backtitle "${WHIPTAIL_BACKTITLE}" --inputbox "Set Hostname" 8 58 gems-linux --title "HOSTNAME" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VM_NAME ]; then
      HN="gems-linux"
      echo -e "${DGN}Using Hostname: ${BGN}$HN${CL}"
    else
      HN=$(echo ${VM_NAME,,} | tr -d ' ')
      echo -e "${DGN}Using Hostname: ${BGN}$HN${CL}"
    fi
  else
    exit-script
  fi

  if CPU_TYPE1=$(whiptail --backtitle "${WHIPTAIL_BACKTITLE}" --title "CPU MODEL" --radiolist "Choose" --cancel-button Exit-Script 10 58 2 \
    "0" "KVM64 (Default)" ON \
    "1" "Host" OFF \
    3>&1 1>&2 2>&3); then
    if [ $CPU_TYPE1 = "1" ]; then
      echo -e "${DGN}Using CPU Model: ${BGN}Host${CL}"
      CPU_TYPE=" -cpu host"
    else
      echo -e "${DGN}Using CPU Model: ${BGN}KVM64${CL}"
      CPU_TYPE=""
    fi
  else
    exit-script
  fi

  if CORE_COUNT=$(whiptail --backtitle "${WHIPTAIL_BACKTITLE}" --inputbox "Allocate CPU Cores" 8 58 2 --title "CORE COUNT" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $CORE_COUNT ]; then
      CORE_COUNT="2"
      echo -e "${DGN}Allocated Cores: ${BGN}$CORE_COUNT${CL}"
    else
      echo -e "${DGN}Allocated Cores: ${BGN}$CORE_COUNT${CL}"
    fi
  else
    exit-script
  fi

  if RAM_SIZE=$(whiptail --backtitle "${WHIPTAIL_BACKTITLE}" --inputbox "Allocate RAM in MiB" 8 58 2048 --title "RAM" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $RAM_SIZE ]; then
      RAM_SIZE="4096"
      echo -e "${DGN}Allocated RAM: ${BGN}$RAM_SIZE${CL}"
    else
      echo -e "${DGN}Allocated RAM: ${BGN}$RAM_SIZE${CL}"
    fi
  else
    exit-script
  fi

  if BRG=$(whiptail --backtitle "${WHIPTAIL_BACKTITLE}" --inputbox "Set a Bridge" 8 58 vmbr0 --title "BRIDGE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $BRG ]; then
      BRG="vmbr0"
      echo -e "${DGN}Using Bridge: ${BGN}$BRG${CL}"
    else
      echo -e "${DGN}Using Bridge: ${BGN}$BRG${CL}"
    fi
  else
    exit-script
  fi

  if MAC1=$(whiptail --backtitle "${WHIPTAIL_BACKTITLE}" --inputbox "Set a MAC Address" 8 58 $GEN_MAC --title "MAC ADDRESS" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $MAC1 ]; then
      MAC="$GEN_MAC"
      echo -e "${DGN}Using MAC Address: ${BGN}$MAC${CL}"
    else
      MAC="$MAC1"
      echo -e "${DGN}Using MAC Address: ${BGN}$MAC1${CL}"
    fi
  else
    exit-script
  fi

  if VLAN1=$(whiptail --backtitle "${WHIPTAIL_BACKTITLE}" --inputbox "Set a Vlan(leave blank for default)" 8 58 --title "VLAN" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VLAN1 ]; then
      VLAN1="Default"
      VLAN=""
      echo -e "${DGN}Using Vlan: ${BGN}$VLAN1${CL}"
    else
      VLAN=",tag=$VLAN1"
      echo -e "${DGN}Using Vlan: ${BGN}$VLAN1${CL}"
    fi
  else
    exit-script
  fi

  if MTU1=$(whiptail --backtitle "${WHIPTAIL_BACKTITLE}" --inputbox "Set Interface MTU Size (leave blank for default)" 8 58 --title "MTU SIZE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $MTU1 ]; then
      MTU1="Default"
      MTU=""
      echo -e "${DGN}Using Interface MTU Size: ${BGN}$MTU1${CL}"
    else
      MTU=",mtu=$MTU1"
      echo -e "${DGN}Using Interface MTU Size: ${BGN}$MTU1${CL}"
    fi
  else
    exit-script
  fi

  if (whiptail --backtitle "${WHIPTAIL_BACKTITLE}" --title "START VIRTUAL MACHINE" --yesno "Start VM when completed?" 10 58); then
    echo -e "${DGN}Start VM when completed: ${BGN}yes${CL}"
    START_VM="yes"
  else
    echo -e "${DGN}Start VM when completed: ${BGN}no${CL}"
    START_VM="no"
  fi

  if (whiptail --backtitle "${WHIPTAIL_BACKTITLE}" --title "ADVANCED SETTINGS COMPLETE" --yesno "Ready to create a Debian 12 VM?" --no-button Do-Over 10 58); then
    echo -e "${RD}Creating a Yocto Linux KVM using the above advanced settings${CL}"
  else
    header_info
    echo -e "${RD}Using Advanced Settings${CL}"
    advanced_settings
  fi
}

function start_script() {
  year=$(date +%Y)
  if (whiptail --backtitle "${WHIPTAIL_BACKTITLE}" --title "SETTINGS" --yesno "Use Default Settings?" --no-button Advanced 10 58); then
    header_info
    echo -e "${BL}Using Default Settings${CL}"
    default_settings
  else
    header_info
    echo -e "${RD}Using Advanced Settings${CL}"
    advanced_settings
  fi
}

function set_download_url() {
  while true; do
    if URL=$(whiptail --backtitle "${WHIPTAIL_BACKTITLE}" --inputbox "Download URL" 8 58 "" --title "DOWNLOAD URL" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
      # if URL is not empty, then break the loop
      if [ -n "$URL" ]; then
        # check if the URL is valid
        if curl -s -I $URL | grep -q "200 OK"; then
          echo -e "${DGN}Using Download URL: ${BGN}$URL${CL}"
          break
        else
          echo -e "${CROSS}${RD} Invalid URL${CL}"
          sleep 2
          continue
        fi
      fi
    else
      exit-script
    fi
  done
}

# SCRIPT INITIALIZATION
header_info
echo -e "\n Loading..."

# Create a temporary directory and jump into it
TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null

# Check if the user wants to proceed with the script
if whiptail --backtitle "${WHIPTAIL_BACKTITLE}" --title "Yocto Linux KVM" --yesno "This will create a new Yocto Linux KVM. Proceed?" 10 58; then
  : # do nothing and continue
else
  header_info && echo -e "⚠ User exited script \n" && exit
fi

check_root
arch_check
pve_check
ssh_check
start_script

msg_info "Validating Storage"
validate_storage

msg_ok "Using ${CL}${BL}$STORAGE${CL} ${GN}for Storage Location."

msg_ok "Virtual Machine ID is ${CL}${BL}$VMID${CL}."
msg_info "Retrieving the URL for the Yocto Linux .qcow2 Disk Image\n"
set_download_url

FILE="${HN}.qcow2"
sleep 2
msg_ok "${CL}${BL}${URL}${CL}"
wget -q --show-progress $URL -O $FILE
echo -en "\e[1A\e[0K"

msg_ok "Downloaded ${CL}${BL}${FILE}${CL}"

STORAGE_TYPE=$(pvesm status -storage $STORAGE | awk 'NR>1 {print $2}')
case $STORAGE_TYPE in
nfs | dir)
  DISK_EXT=".qcow2"
  DISK_REF="$VMID/"
  DISK_IMPORT="-format qcow2"
  THIN=""
  ;;
btrfs)
  DISK_EXT=".raw"
  DISK_REF="$VMID/"
  DISK_IMPORT="-format raw"
  FORMAT=",efitype=4m"
  THIN=""
  ;;
esac
for i in {0,1}; do
  disk="DISK$i"
  eval DISK${i}=vm-${VMID}-disk-${i}${DISK_EXT:-}
  eval DISK${i}_REF=${STORAGE}:${DISK_REF:-}${!disk}
done

msg_info "Creating a Yocto Linux KVM"
qm create $VMID -agent 1${MACHINE} -tablet 0 -localtime 1 -bios ovmf${CPU_TYPE} -cores $CORE_COUNT -memory $RAM_SIZE \
  -name $HN -tags unbrikd -net0 virtio,bridge=$BRG,macaddr=$MAC$VLAN$MTU -onboot 1 -ostype l26 -scsihw virtio-scsi-pci
pvesm alloc $STORAGE $VMID $DISK0 4M 1>&/dev/null
qm importdisk $VMID ${FILE} $STORAGE ${DISK_IMPORT:-} 1>&/dev/null
qm set $VMID \
  -efidisk0 ${DISK0_REF}${FORMAT} \
  -scsi0 ${DISK1_REF},${DISK_CACHE}${THIN}size=32G \
  -boot order=scsi0 \
  -serial0 socket \
  -description "Unbrikd, ${YEAR} (c)" >/dev/null

msg_ok "Created a Yocto Linux KVM ${CL}${BL}(${HN})"
if [ "$START_VM" == "yes" ]; then
  msg_info "Starting Yocto Linux KVM"
  qm start $VMID
  msg_ok "Started Yocto Linux KVM"
fi

msg_ok "Completed Successfully!\n"