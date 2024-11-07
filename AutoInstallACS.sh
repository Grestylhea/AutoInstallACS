#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
local_ip=$(hostname -I | awk '{print $1}')
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}==================== Script Install GenieACS All In One. ===================${NC}"
echo -e "${GREEN}======================== NodeJS, MongoDB, GenieACS, ========================${NC}"
echo -e "${GREEN}======================== By Gresty | Ibnu Ato'illah ========================${NC}"
echo -e "${RED}===================== Dilarang menjual kembali script ini ====================${NC}"
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}Sebelum melanjutkan, silahkan baca terlebih dahulu. Apakah anda ingin melanjutkan? (y/n)${NC}"
read confirmation
if [ "$confirmation" != "y" ]; then
    echo -e "${GREEN}Install dibatalkan. Tidak ada perubahan dalam ubuntu server anda.${NC}"
    exit 1
fi
for ((i = 5; i >= 1; i--)); do
    sleep 1
    echo "Melanjutkan dalam $i. Tekan ctrl+c untuk membatalkan"
done

#Install NodeJS
check_node_version() {
    if command -v node > /dev/null 2>&1; then
        NODE_VERSION=$(node -v | cut -d 'v' -f 2)
        NODE_MAJOR_VERSION=$(echo $NODE_VERSION | cut -d '.' -f 1)
        NODE_MINOR_VERSION=$(echo $NODE_VERSION | cut -d '.' -f 2)

        if [ "$NODE_MAJOR_VERSION" -lt 12 ] || { [ "$NODE_MAJOR_VERSION" -eq 12 ] && [ "$NODE_MINOR_VERSION" -lt 13 ]; } || [ "$NODE_MAJOR_VERSION" -gt 22 ]; then
            return 1
        else
            return 0
        fi
    else
        return 1
    fi
}

if ! check_node_version; then
    echo -e "${GREEN}================== Menginstall NodeJS ==================${NC}"
    curl -sL https://deb.nodesource.com/setup_14.x -o nodesource_setup.sh
    chmod +x nodesource_setup.sh
    ./nodesource_setup.sh
    apt install nodejs -y
    rm nodesource_setup.sh
    echo -e "${GREEN}================== Sukses NodeJS ==================${NC}"
else
    NODE_VERSION=$(node -v | cut -d 'v' -f 2)
    echo -e "${GREEN}============================================================================${NC}"
    echo -e "${GREEN}============== NodeJS sudah terinstall versi ${NODE_VERSION}. ==============${NC}"
    echo -e "${GREEN}========================= Lanjut install GenieACS ==========================${NC}"
fi

# MongoDB
if ! command -v mongod &> /dev/null; then
    echo -e "${GREEN}================== Menginstall MongoDB ==================${NC}"

    # Menambahkan kunci PGP MongoDB untuk verifikasi paket
    curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -

    # Memilih repository berdasarkan versi Ubuntu
    echo "${GREEN}Pilih versi Ubuntu Anda:"
    echo "1. Ubuntu Precise (12.04)"
    echo "2. Ubuntu Trusty (14.04)"
    echo "3. Ubuntu Xenial (16.04)"
    echo "4. Ubuntu Bionic (18.04)"
    echo "5. Ubuntu Focal (20.04)"
    echo "6. Ubuntu Jammy (22.04)"
    read -p "Masukkan nomor pilihan: " ubuntu_version

    # Menambahkan repository sesuai dengan versi Ubuntu yang dipilih
    case $ubuntu_version in
        1) echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu precise/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list ;;
        2) echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list ;;
        3) echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list ;;
        4) echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list ;;
        5) echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list ;;
        6) echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list ;;
        *) echo "Pilihan tidak valid"; exit 1 ;;
    esac

    # Update dan install MongoDB
    sudo apt update
    sudo apt install mongodb-org -y

    # Cek status MongoDB
    sudo systemctl start mongod
    sudo systemctl enable mongod

    echo -e "${GREEN}================== Sukses MongoDB ==================${NC}"
else
    echo -e "${GREEN}============================================================================${NC}"
    echo -e "${GREEN}=================== MongoDB sudah terinstall sebelumnya. ===================${NC}"
fi

#GenieACS
if ! systemctl is-active --quiet genieacs-{cwmp,fs,ui,nbi}; then
    echo -e "${GREEN}================== Menginstall GenieACS CWMP, FS, NBI, UI ==================${NC}"
    npm install -g genieacs@1.2.9
    useradd --system --no-create-home --user-group genieacs || true
    mkdir -p /opt/genieacs
    mkdir -p /opt/genieacs/ext
    chown genieacs:genieacs /opt/genieacs/ext
    cat << EOF > /opt/genieacs/genieacs.env
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
GENIEACS_EXT_DIR=/opt/genieacs/ext
GENIEACS_UI_JWT_SECRET=secret
EOF
    chown genieacs:genieacs /opt/genieacs/genieacs.env
    chmod 600 /opt/genieacs/genieacs.env
    mkdir -p /var/log/genieacs
    chown genieacs: /var/log/genieacs

    # create systemd unit files
    for service in cwmp nbi fs ui; do
        cat << EOF > /etc/systemd/system/genieacs-$service.service
[Unit]
Description=GenieACS $service
After=network.target

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-$service

[Install]
WantedBy=default.target
EOF
    done

    # config logrotate
    cat << EOF > /etc/logrotate.d/genieacs
/var/log/genieacs/*.log /var/log/genieacs/*.yaml {
    daily
    rotate 30
    compress
    delaycompress
    dateext
}
EOF
    echo -e "${GREEN}========== Install APP GenieACS selesai... ==============${NC}"
    systemctl daemon-reload
    systemctl enable --now genieacs-{cwmp,fs,ui,nbi}
    echo -e "${GREEN}================== Sukses GenieACS CWMP, FS, NBI, UI ==================${NC}"
else
    echo -e "${GREEN}============================================================================${NC}"
    echo -e "${GREEN}=================== GenieACS sudah terinstall sebelumnya. ==================${NC}"
fi

# Sukses
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN}========== GenieACS UI akses port 3000: http://$local_ip:3000 ==============${NC}"
echo -e "${GREEN}================ Script by Gresty | Ibnu Ato'illah =========================${NC}"
echo -e "${GREEN}=================== Info : grestylhea@gmail.com ============================${NC}"
echo -e "${RED}================== Dilarang menjual kembali script ini =======================${NC}"
echo -e "${GREEN}============================================================================${NC}"
