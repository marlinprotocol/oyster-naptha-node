#!/bin/sh

set -e

# setting an address for loopback
ifconfig lo 127.0.0.1
ip addr

echo "127.0.0.1 localhost" > /etc/hosts

# adding a default route
ip route add default dev lo src 127.0.0.1
ip route

# iptables rules to route traffic to transparent proxy
iptables -A OUTPUT -t nat -p tcp --dport 1:65535 ! -d 127.0.0.1  -j DNAT --to-destination 127.0.0.1:1200
iptables -L -t nat

# generate identity key
/app/keygen-ed25519 --secret /app/id.sec --public /app/id.pub

# your custom setup goes here

# rabbitmq setup
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export LANGUAGE=C.UTF-8

RMQ_USER="username"
RMQ_PASSWORD="password"

echo "RMQ: Starting server"
export HOME=/app
export XDG_CONFIG_HOME=/app
rabbitmq-server &
RMQ_PID=$!
echo "RMD: PID: " $RMQ_PID
sleep 5
ps ax

echo "RMQ: Enabling management plugin"
mkdir -p /etc/rabbitmq/
rabbitmq-plugins enable rabbitmq_management

echo "RMQ: Setting up user"
rabbitmqctl add_user "$RMQ_USER" "$RMQ_PASSWORD"
rabbitmqctl set_user_tags "$RMQ_USER" "$RMQ_PASSWORD"
rabbitmqctl set_permissions -p / "$RMQ_USER" ".*" ".*" ".*"

echo "RMQ: Clean up"
# kill -15 -$RMQ_PID
rabbitmqctl stop
ps ax

# node env file
export SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
export LD_LIBRARY_PATH=$(ls -d /nix/store/*gcc-*-lib)/lib

cd /app/node

/app/ip-to-vsock-transparent --vsock-addr 3:1200 --ip-addr 127.0.0.1:1200 &
PROXY_PID=$!
echo "PROXY: PID: " $PROXY_PID
/app/dnsproxy -u https://1.1.1.1/dns-query -v &
DNS_PID=$!
echo "DNS: PID: " $DNS_PID

poetry lock
# poetry config installer.no-binary tokenizers

poetry install

kill $DNS_PID
kill $PROXY_PID

chmod +x scripts/generate_user.py
PK=$(poetry run python scripts/generate_user.py)
echo $PK
echo -e "PRIVATE_KEY=$PK\n" > /app/node.env
cat << EOF >> /app/node.env
# Worker Node
NODE_TYPE=indirect
NODE_IP=http://localhost
NODE_PORT=7001
NODE_ROUTING=ws://node.naptha.ai:8765
BASE_OUTPUT_DIR=./storage/fs
OLLAMA_MODELS=phi
# OLLAMA_MODELS=phi,gemma
OPENAI_API_KEY=
STABILITY_API_KEY=
MODULES_PATH=./storage/hub/modules
# true or false
DEV_MODE=true
# /dns/ENDPOINT/tcp/PORT/http
IPFS_GATEWAY_URL=/dns/provider.akash.pro/tcp/31832/http
DOCKER_JOBS=false

#MQ
RMQ_USER=username
RMQ_PASSWORD=password
CELERY_BROKER_URL=amqp://localhost:5672/

# Hub
LOCAL_HUB=false
LOCAL_HUB_URL=ws://localhost:3001/rpc
PUBLIC_HUB_URL=ws://node.naptha.ai:3001/rpc
HUB_DB_PORT=3001
HUB_NS=naptha
HUB_DB=naptha
HUB_ROOT_USER=root
HUB_ROOT_PASS=root
HUB_USERNAME=seller1
HUB_PASSWORD=great-password

# SurrealDB
SURREALDB_PORT=3002
DB_NS=naptha
DB_DB=naptha
DB_URL=ws://localhost:3002/rpc
DB_ROOT_USER=root
DB_ROOT_PASS=root

# Payments
MARKETPLACE_AUTH_TOKEN=
SESSION_KEY=
PAIDPLAN_DID=
EOF
echo -e "\nLD_LIBRARY_PATH=$LD_LIBRARY_PATH\n"
cat /app/node.env

cd

mkdir -p /app/ollama-tmp/

# starting supervisord
cat /etc/supervisord.conf
/app/supervisord
