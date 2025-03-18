#!/bin/bash

# Color codes for better readability
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}#############################################${NC}"
echo -e "${BLUE}#         T3RN EXECUTOR INSTALLER          #${NC}"
echo -e "${BLUE}#############################################${NC}"
echo ""

# Ask for executor user
read -p "$(echo -e ${YELLOW}"Masukkan nama user untuk menjalankan executor (default: root): "${NC})" EXECUTOR_USER
EXECUTOR_USER=${EXECUTOR_USER:-root}

# Ask for private key (securely)
echo -e "${YELLOW}Masukkan PRIVATE_KEY_LOCAL:${NC}"
read -sp "" PRIVATE_KEY_LOCAL
echo ""

# Set directory paths
INSTALL_DIR="/home/$EXECUTOR_USER/t3rn"
SERVICE_FILE="/etc/systemd/system/t3rn-executor.service"
ENV_FILE="/etc/t3rn-executor.env"

echo -e "${GREEN}[1/7] Membuat direktori instalasi...${NC}"
# Create installation directory and navigate to it
mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR"

echo -e "${GREEN}[2/7] Mendapatkan versi terbaru...${NC}"
# Get latest release tag
TAG=$(curl -s https://api.github.com/repos/t3rn/executor-release/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
echo -e "${GREEN}Versi terbaru: $TAG${NC}"

echo -e "${GREEN}[3/7] Mengunduh dan mengekstrak rilis...${NC}"
# Download and extract the release
wget -q "https://github.com/t3rn/executor-release/releases/download/$TAG/executor-linux-$TAG.tar.gz"
tar -xzf "executor-linux-$TAG.tar.gz"
cd executor/executor/bin

echo -e "${GREEN}[4/7] Membuat file konfigurasi...${NC}"
# Create environment file with RPC endpoints
sudo bash -c "cat > $ENV_FILE" <<EOL
RPC_ENDPOINTS="{\"l2rn\": [\"https://b2n.rpc.caldera.xyz/http\"], \"arbt\": [\"https://arbitrum-sepolia.drpc.org\", \"https://sepolia-rollup.arbitrum.io/rpc\"], \"bast\": [\"https://base-sepolia-rpc.publicnode.com\", \"https://base-sepolia.drpc.org\"], \"opst\": [\"https://sepolia.optimism.io\", \"https://optimism-sepolia.drpc.org\"], \"unit\": [\"https://unichain-sepolia.drpc.org\", \"https://sepolia.unichain.org\"]}"
EOL

echo -e "${GREEN}[5/7] Mengatur kepemilikan dan izin...${NC}"
# Set proper ownership and permissions
sudo chown -R "$EXECUTOR_USER":"$EXECUTOR_USER" "$INSTALL_DIR"
sudo chmod 600 "$ENV_FILE"

echo -e "${GREEN}[6/7] Membuat file service...${NC}"
# Create service file
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=t3rn Executor Service
After=network.target

[Service]
User=$EXECUTOR_USER
WorkingDirectory=$INSTALL_DIR/executor/executor/bin
ExecStart=$INSTALL_DIR/executor/executor/bin/executor
Restart=always
RestartSec=10
Environment=ENVIRONMENT=testnet
Environment=LOG_LEVEL=debug
Environment=LOG_PRETTY=false
Environment=EXECUTOR_PROCESS_BIDS_ENABLED=true
Environment=EXECUTOR_PROCESS_ORDERS_ENABLED=true
Environment=EXECUTOR_PROCESS_CLAIMS_ENABLED=true
Environment=EXECUTOR_MAX_L3_GAS_PRICE=100
Environment=PRIVATE_KEY_LOCAL=$PRIVATE_KEY_LOCAL
Environment=ENABLED_NETWORKS=arbitrum-sepolia,base-sepolia,optimism-sepolia,l2rn
EnvironmentFile=$ENV_FILE
Environment=EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=true

[Install]
WantedBy=multi-user.target
EOL

echo -e "${GREEN}[7/7] Memulai layanan...${NC}"
# Reload systemd, enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable t3rn-executor.service
sudo systemctl start t3rn-executor.service

echo -e "${GREEN}✅ Executor berhasil diinstall dan dijalankan!${NC}"
echo -e "${YELLOW}Menampilkan log real-time... (Tekan Ctrl+C untuk keluar)${NC}"
sudo journalctl -u t3rn-executor.service -f --no-hostname -o cat
