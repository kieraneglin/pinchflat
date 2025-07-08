#!/usr/bin/env bash

# Source common functions
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

# Constants and default settings
APP="Pinchflat"
var_tags="${var_tags:-arr;}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-8G}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"
var_template="debian-12-standard_12.0-1_amd64.tar.zst"  # Define the template name

# Function to prompt for storage selection
function prompt_storage_selection() {
    echo -e "${CYAN}--- Available Storage Options ---${NC}"
    pvesm status | awk '{print $1}' | sed '1d'  # Exclude header
    read -p "Please select storage (enter the name): " STORAGE
    echo "Using storage: $STORAGE"
}

# Function to create the LXC container
function create_container() {
    echo -e "\n${GREEN}Creating LXC Container...${NC}"
    pct create $CTID $var_template \
        --hostname $HN \
        --cores $var_cpu \
        --memory $var_ram \
        --swap 512 \
        --rootfs $STORAGE:$var_disk \
        --net0 name=eth0,bridge=$var_bridge,ip=$var_ip \
        --unprivileged $var_unprivileged \
        --features nesting=1 \
        --start 1 \
        --onboot 1 \
        --ostype $var_os

    echo -e "\n${GREEN}Container created successfully!${NC}"
}

# Function to install Pinchflat inside the LXC
function install_pinchflat() {
    echo -e "\n${BLUE}Installing Pinchflat inside LXC...${NC}"
    pct exec $CTID -- bash -c "\
        apt update && \
        apt install -y git curl bash && \
        git clone https://github.com/kieraneglin/pinchflat /opt/pinchflat && \
        chmod +x /opt/pinchflat/pinchflat.sh && \
        ln -s /opt/pinchflat/pinchflat.sh /usr/local/bin/pinchflat"

    echo -e "\n${GREEN}Pinchflat installation completed!${NC}"
}

# Main function
function main() {
    echo -e "${BLUE}Proxmox VE LXC Installer for $APP${NC}"
    echo -e "Choose setup mode:"
    
    select opt in "Default Setup" "Advanced Setup"; do
        case $opt in
            "Default Setup")
                CTID=124
                HN="pinchflat"
                var_disk="8G"
                var_ram="1024"
                var_cpu="2"
                var_bridge="vmbr0"
                var_ip="dhcp"
                prompt_storage_selection
                break
                ;;
            "Advanced Setup")
                read -p "Container ID [Default: 124]: " CTID
                CTID=${CTID:-124}
                read -p "Hostname [Default: pinchflat]: " HN
                HN=${HN:-"pinchflat"}
                read -p "Disk Size (e.g. 8G) [Default: 8G]: " var_disk
                var_disk=${var_disk:-"8G"}
                read -p "RAM Size in MB [Default: 1024]: " var_ram
                var_ram=${var_ram:-1024}
                read -p "CPU Cores [Default: 2]: " var_cpu
                var_cpu=${var_cpu:-2}
                read -p "Network Bridge [Default: vmbr0]: " var_bridge
                var_bridge=${var_bridge:-"vmbr0"}
                read -p "IP Address [Default: dhcp]: " var_ip
                var_ip=${var_ip:-"dhcp"}
                prompt_storage_selection
                break
                ;;
            *)
                echo "Invalid option. Please select 1 or 2."
                ;;
        esac
    done

    create_container
    install_pinchflat

    echo -e "\n${GREEN}Pinchflat LXC ($CTID) is ready!${NC}"
    echo -e "Access it via: ${CYAN}pct console $CTID${NC}"
    echo -e "Run the script with: ${CYAN}pinchflat${NC}"
}

# Execute the main function
main
