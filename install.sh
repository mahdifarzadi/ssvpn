#!/bin/bash

# vars
V2RAY_VERSION=v1.3.2

SERVER_HOST=0.0.0.0
SERVER_PORT=443
SERVER_ADDRESS=$SERVER_HOST:$SERVER_PORT # can be unix socket
SERVER_PASSWORD=VERYVERYSTRONGPASS
SERVER_ENC_METHOD=chacha20-ietf-poly1305
SERVER_PLUGIN=v2ray-plugin

SERVER_IP=$(hostname -I | awk '{print $1}')

MANAGER_HOST=0.0.0.0
MANAGER_PORT=4000
MANAGER_ADDRESS=$MANAGER_HOST:$MANAGER_PORT
MANAGER_PASSWORD=VERYVERYSTRONGPASSFORMANAGER

TELEGRAM_TOKEN=INVALID

# TODO add flags

###
# install dependencies
###

apt update

# install shadowsocks-libev from repository
apt install shadowsocks-libev -y

# install v2ray-plugin
wget https://github.com/shadowsocks/v2ray-plugin/releases/download/$V2RAY_VERSION/v2ray-plugin-linux-amd64-$V2RAY_VERSION.tar.gz
tar -xzf v2ray-plugin-linux-amd64-$V2RAY_VERSION.tar.gz
mv v2ray-plugin_linux_amd64 /usr/local/bin/v2ray-plugin
chmod +x /usr/local/bin/v2ray-plugin
rm v2ray-plugin-linux-amd64-$V2RAY_VERSION.tar.gz

# install nodejs
apt install nodejs -y
apt install npm -y

# install redis
apt install redis-server -y

# install shadowsocks-manager
npm i -g shadowsocks-manager --unsafe-perm


###
# run services
###

# disable default service
systemctl stop shadowsocks-libev.service && systemctl disable shadowsocks-libev.service

# TODO remove ?
# create ss-server service
cat << EOF > /etc/systemd/system/ss-server.service
[Unit]
Description=Daemon to Shadowsocks Server
Wants=network-online.target
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/ss-server -s $SERVER_HOST -p $SERVER_PORT -k $SERVER_PASSWORD -m $SERVER_ENC_METHOD -u --plugin $SERVER_PLUGIN --plugin-opts "server"

[Install]
WantedBy=multi-user.target
EOF

# TODO use unix socket
# create ss-manager service
cat << EOF > /etc/systemd/system/ss-manager.service
[Unit]
Description=Daemon to Shadowsocks Manager
Wants=network-online.target
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/ss-manager -m $SERVER_ENC_METHOD -u --plugin $SERVER_PLUGIN --plugin-opts "server" --manager-address $SERVER_ADDRESS

[Install]
WantedBy=multi-user.target
EOF

# create ssmgr config file
cat << EOF > ~/.ssmgr/ssmgr.yml
type: s

shadowsocks:
  address: $SERVER_ADDRESS
manager:
  address: $MANAGER_ADDRESS
  password: $MANAGER_PASSWORD
db: 'ssmgr.sqlite'
EOF


# create ssmgr service
cat << EOF > /etc/systemd/system/ssmgr.service
[Unit]
Description=Daemon to ssmgr type s
Wants=network-online.target
After=network.target

[Service]
Type=simple
ExecStart=ssmgr -c /root/.ssmgr/ssmgr.yml

[Install]
WantedBy=multi-user.target
EOF

# create ssmgr-tel config file
cat << EOF > ~/.ssmgr/ssmgr-tel.yml
type: m

manager:
  address: $SERVER_IP:$MANAGER_PORT
  password: $MANAGER_PASSWORD

plugins:
  telegram:
    token: $TELEGRAM_TOKEN
    use: true
db: 'tel.sqlite'
EOF

# create telegram ssmgr service
cat << EOF > /etc/systemd/system/ssmgr-tel.service
[Unit]
Description=Daemon to ssmgr type m for telegram bot
Wants=network-online.target
After=network.target

[Service]
Type=simple
ExecStart=ssmgr -c /root/.ssmgr/ssmgr-tel.yml

[Install]
WantedBy=multi-user.target
EOF


# enable and run services
systemctl daemon-reload
systemctl enable ss-server.service ss-manager.service ssmgr.service ssmgr-tel.service
systemctl restart ss-server.service ss-manager.service ssmgr.service ssmgr-tel.service