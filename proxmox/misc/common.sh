# Common informations to standardize the output of the scripts
YEAR=$(date +%Y)
FOOTER="Unbrikd, ${YEAR} (c)"

# Colors
YW=$(echo "\033[33m")
YWB=$(echo "\033[93m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
DGN=$(echo "\033[32m")

# Formatting
CL=$(echo "\033[m")
UL=$(echo "\033[4m")
BOLD=$(echo "\033[1m")
BFR="\\r\\033[K"
HOLD=" "
TAB="  "

# Icons
CM="${TAB}✔️${TAB}${CL}"
CROSS="${TAB}✖️${TAB}${CL}"
INFO="${TAB}💡${TAB}${CL}"
OS="${TAB}🖥️${TAB}${CL}"
OSVERSION="${TAB}🌟${TAB}${CL}"
CONTAINERTYPE="${TAB}📦${TAB}${CL}"
DISKSIZE="${TAB}💾${TAB}${CL}"
CPUCORE="${TAB}🧠${TAB}${CL}"
RAMSIZE="${TAB}🛠️${TAB}${CL}"
SEARCH="${TAB}🔍${TAB}${CL}"
VERIFYPW="${TAB}🔐${TAB}${CL}"
CONTAINERID="${TAB}🆔${TAB}${CL}"
HOSTNAME="${TAB}🏠${TAB}${CL}"
BRIDGE="${TAB}🌉${TAB}${CL}"
NETWORK="${TAB}📡${TAB}${CL}"
GATEWAY="${TAB}🌐${TAB}${CL}"
DISABLEIPV6="${TAB}🚫${TAB}${CL}"
DEFAULT="${TAB}⚙️${TAB}${CL}"
MACADDRESS="${TAB}🔗${TAB}${CL}"
VLANTAG="${TAB}🏷️${TAB}${CL}"
ROOTSSH="${TAB}🔑${TAB}${CL}"
CREATING="${TAB}🚀${TAB}${CL}"
ADVANCED="${TAB}🧩${TAB}${CL}"

function header_info {
  clear
  cat <<EOF
            
        ↖↗↑↗            ←↑↑↑↙                    
        ↗↑↑↑↗          →↑↑↗↓↓                    
        ↑↗↖↑↑        ↖↑↑↓ ↑↑↓                    
        ↓↑↑↑↘       ↘↑↑ ↙↑↑←                     
                  ↑↑→ ↑↑↗                       
        ←↑↑↑←    ↙↑↑↓ ↑↑↙                        
        ↗↑→↑↑   →↑↑↖ ↖↑↘                         
        ↑↗ ↑↑ ←↑↑↙↖↑↘ ↗↑↘                        
        ↑↗ ↑↑↓↑↑ →↑↑↑↑ →↑→                       
        ↑↗ ↗↑↑→ ↑↑↓ ↓↑↑ →↑↑↙                     
        ↑↗  ↓ ←↑↑↖   ↙↑↑ ↙↑↑↑↙                   
        ↗↑↑↑↑↑↑↗      ←↑↑↑↗↙↓↓                   
        ↖↗↑↑↑↑↙         →↑↑↑↗↖                   

          ${FOOTER}    
                                                                                           
EOF
}

function error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  echo -e "\n$error_message\n"
  cleanup_vmid
}

function cleanup_vmid() {
  if qm status $VMID &>/dev/null; then
    qm stop $VMID &>/dev/null
    qm destroy $VMID &>/dev/null
  fi
}

function cleanup() {
  popd >/dev/null
  rm -rf $TEMP_DIR
}

# Setup message functions 
function msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

function msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

function msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

# Check if the user is root otherwise clear the screen and exit
function check_root() {
  if [[ "$(id -u)" -ne 0 || $(ps -o comm= -p $PPID) == "sudo" ]]; then
    clear
    msg_error "Please run this script as root."
    echo -e "\nExiting..."
    sleep 2
    exit
  fi
}

# Check if the user is using a supported version of Proxmox Virtual Environment
# If the version is not supported, prints an error message and exits
function pve_check() {
  if ! pveversion | grep -Eq "pve-manager/8.[1-3]"; then
    msg_error "This version of Proxmox Virtual Environment is not supported"
    echo -e "Requires Proxmox Virtual Environment Version 8.1 or later."
    echo -e "Exiting..."
    sleep 2
    exit
  fi
}

# Check if the user is using a supported architecture
# If the architecture is not supported, prints an error message and exits
function arch_check() {
  if [ "$(dpkg --print-architecture)" != "amd64" ]; then
    msg_error "This script will not work with PiMox! \n"
    echo -e "Exiting..."
    sleep 2
    exit
  fi
}

# Check if the user is using SSH
# If the user is using SSH, warns the user that SSH can create issues with the installation but allows the user to proceed with SSH if they choose to
# If the user chooses to not use SSH, clears the screen and exits
function ssh_check() {
  if command -v pveversion >/dev/null 2>&1; then
    if [ -n "${SSH_CLIENT:+x}" ]; then
      if whiptail --backtitle "${WHIPTAIL_BACKTITLE}" --defaultno --title "SSH DETECTED" --yesno "It's suggested to use the Proxmox shell instead of SSH, since SSH can create issues while gathering variables. Would you like to proceed with using SSH?" 10 62; then
        echo "you've been warned"
      else
        clear
        exit
      fi
    fi
  fi
}

# Handle the exit of the script
function exit-script() {
  clear
  echo -e "⚠  User exited script \n"
  exit
}

function validate_storage() {
  while read -r line; do
    TAG=$(echo $line | awk '{print $1}')
    TYPE=$(echo $line | awk '{printf "%-10s", $2}')
    FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
    ITEM="  Type: $TYPE Free: $FREE "
    OFFSET=2
    if [[ $((${#ITEM} + $OFFSET)) -gt ${MSG_MAX_LENGTH:-} ]]; then
      MSG_MAX_LENGTH=$((${#ITEM} + $OFFSET))
    fi
    STORAGE_MENU+=("$TAG" "$ITEM" "OFF")
  done < <(pvesm status -content images | awk 'NR>1')

  VALID=$(pvesm status -content images | awk 'NR>1')
  if [ -z "$VALID" ]; then
    msg_error "Unable to detect a valid storage location."
    exit
  elif [ $((${#STORAGE_MENU[@]} / 3)) -eq 1 ]; then
    STORAGE=${STORAGE_MENU[0]}
  else
    while [ -z "${STORAGE:+x}" ]; do
      STORAGE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Storage Pools" --radiolist \
        "Which storage pool you would like to use for ${HN}?\nTo make a selection, use the Spacebar.\n" \
        16 $(($MSG_MAX_LENGTH + 23)) 6 \
        "${STORAGE_MENU[@]}" 3>&1 1>&2 2>&3) || exit
    done
  fi
}