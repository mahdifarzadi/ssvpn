#!/bin/bash

# vars
INSTALL_DEP=false

V2RAY_VERSION=v1.3.2

JUST_SS=false
SERVER_HOST=127.0.0.1
SERVER_PORT=6000
SERVER_ADDRESS=$SERVER_HOST:$SERVER_PORT # can use unix socket path
SERVER_PASSWORD=VERYVERYSTRONGPASS
SERVER_ENC_METHOD=chacha20-ietf-poly1305
SERVER_PLUGIN=v2ray-plugin

SERVER_IP=$(hostname -I | awk '{print $1}')

MANAGER_HOST=0.0.0.0
MANAGER_PORT=4000
MANAGER_ADDRESS=$MANAGER_HOST:$MANAGER_PORT
MANAGER_PASSWORD=VERYVERYSTRONGPASSFORMANAGER

USE_TELEGRAM=false
TELEGRAM_TOKEN=INVALID

###
# read flags
###

function help {
    cat <<EOF
-i,--install              INSTALL_DEP=true
-s, --ss-server           JUST_SS=true
-h, --server-host         SERVER_HOST=$2
-p, --server-port         SERVER_PORT=$2
-a, --server-address      SERVER_ADDRESS=$2
-k, --server-password     SERVER_PASSWORD=$2
-m, --encrypt-method      SERVER_ENC_METHOD=$2
-H, --manager-host        MANAGER_HOST=$2
-P, --manager-port        MANAGER_PORT=$2
-A, --manager-address     MANAGER_ADDRESS=$2
-K, --manager-password    MANAGER_PASSWORD=$2
-t, --telegram            USE_TELEGRAM=true, TELEGRAM_TOKEN=$2
--v2ray-version           V2RAY_VERSION=$2
--plugin                  SERVER_PLUGIN=$2
--ip                      SERVER_IP=$2
--help                    Help
EOF
    exit 0
}



TEMP=$(
    getopt -o ish:p:a:k:m:H:P:A:K:t: \
        --long install,ss-server,server-host:,server-port:,server-address:,server-password:,encrypt-method:,manager-host:,manager-port:,manager-address:,manager-password:,telegram:,v2ray-version:,plugin:,ip:,help \
        -n 'javawrap' -- "$@"
)

if [ $? != 0 ]; then
    echo "Terminating..." >&2
    exit 1
fi

eval set -- "$TEMP"

while true; do
    case "$1" in
    -i | --install)
        INSTALL_DEP=true
        shift
        ;;
    -s | --ss-server)
        JUST_SS=true
        shift
        ;;
    -h | --server-host)
        SERVER_HOST="$2"
        shift 2
        ;;
    -p | --server-port)
        SERVER_PORT="$2"
        shift 2
        ;;
    -a | --server-address)
        SERVER_ADDRESS="$2"
        shift 2
        ;;
    -k | --server-password)
        SERVER_PASSWORD="$2"
        shift 2
        ;;
    -m | --encrypt-method)
        SERVER_ENC_METHOD="$2"
        shift 2
        ;;
    -H | --manager-host)
        MANAGER_HOST="$2"
        shift 2
        ;;
    -P | --manager-port)
        MANAGER_PORT="$2"
        shift 2
        ;;
    -A | --manager-address)
        MANAGER_ADDRESS="$2"
        shift 2
        ;;
    -K | --manager-password)
        MANAGER_PASSWORD="$2"
        shift 2
        ;;
    -t | --telegram)
        USE_TELEGRAM=true
        TELEGRAM_TOKEN="$2"
        shift 2
        ;;
    --v2ray-version)
        V2RAY_VERSION="$2"
        shift 2
        ;;
    --plugin)
        SERVER_PLUGIN="$2"
        shift 2
        ;;
    --ip)
        SERVER_IP="$2"
        shift 2
        ;;
    --help)
        help
        ;;
    --)
        shift
        break
        ;;
    *) break ;;
    esac
done

if $INSTALL_DEP; then
    ###
    # install dependencies
    ###

    apt update

    # install shadowsocks-libev from repository
    apt install shadowsocks-libev -y
    # disable default service
    systemctl stop shadowsocks-libev.service && systemctl disable shadowsocks-libev.service

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
fi

###
# run services
###
if $JUST_SS; then
    # create ss-server service
    cat <<EOF >/etc/systemd/system/ss-server.service
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
    # enable and run service
    systemctl daemon-reload
    systemctl enable ss-server.service
    systemctl restart ss-server.service

else
    # create ss-manager service
    # TODO add -k (password)
    cat <<EOF >/etc/systemd/system/ss-manager.service
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
    cat <<EOF >/root/.ssmgr/ssmgr.yml
type: s

shadowsocks:
  address: $SERVER_ADDRESS
manager:
  address: $MANAGER_ADDRESS
  password: $MANAGER_PASSWORD
db: 'ssmgr.sqlite'
EOF

    # create ssmgr service
    cat <<EOF >/etc/systemd/system/ssmgr.service
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

    # enable and run services
    systemctl daemon-reload
    systemctl enable ss-manager.service ssmgr.service
    systemctl restart ss-manager.service ssmgr.service

    if $USE_TELEGRAM; then
        # create ssmgr-tel config file
        cat <<EOF >/root/.ssmgr/ssmgr-tel.yml
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
        cat <<EOF >/etc/systemd/system/ssmgr-tel.service
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
        systemctl enable ssmgr-tel.service
        systemctl restart ssmgr-tel.service
    fi
fi
