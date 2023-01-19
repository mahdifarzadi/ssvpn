#!/bin/bash

USE_MANAGER=true

V2RAY_VERSION=v1.3.2
MANAGER_HOST=127.0.0.1
MANAGER_PORT=6000


# TODO add flags

###
# install dependencies
###

apt update

# install shadowsocks-libev from repository
apt install shadowsocks-libev -y

# install v2ray-plugin
wget https://github.com/shadowsocks/v2ray-plugin/releases/download/{$V2RAY_VERSION}/v2ray-plugin-linux-amd64-{$V2RAY_VERSION}.tar.gz
tar -xzf v2ray-plugin-linux-amd64-{$V2RAY_VERSION}.tar.gz
mv v2ray-plugin_linux_amd64 /usr/local/bin/v2ray-plugin
chmod +x /usr/local/bin/v2ray-plugin
rm v2ray-plugin-linux-amd64-{$V2RAY_VERSION}.tar.gz

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
# # create ss-server service
# cat << EOF > /etc/systemd/system/ss-server.service
# [Unit]
# Description=Daemon to Shadowsocks Server
# Wants=network-online.target
# After=network.target

# [Service]
# Type=simple
# ExecStart=/usr/bin/ss-server -s 0.0.0.0 -p 6000 -k ${PASSWORD:-test} -m aes-256-gcm -u --plugin v2ray-plugin --plugin-opts "server"

# [Install]
# WantedBy=multi-user.target
# EOF

# TODO use unix socket
# create ss-manager service
cat << EOF > /etc/systemd/system/ss-manager.service
[Unit]
Description=Daemon to Shadowsocks Manager
Wants=network-online.target
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/ss-manager -m aes-256-gcm -u --plugin v2ray-plugin --plugin-opts "server" --manager-address 127.0.0.1:6000

[Install]
WantedBy=multi-user.target
EOF

# create ssmgr config file
cat << EOF > ~/.ssmgr/ssmgr.yml
type: s

shadowsocks:
  address: 127.0.0.1:6000
manager:
  address: 0.0.0.0:4001
  password: 'feri'
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
  address: 141.94.55.134:4001
  password: 'feri'

plugins:
  telegram:
    token: '5891247135:AAF7npye_YeqSC7pEwtSpSHUqdS0Yp5f_nc'
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