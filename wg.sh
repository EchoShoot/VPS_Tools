#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#=================================================================#
#   System Required:  Debian 9                                    #
#   Description: One click Install WireGuard Server               #
#   Author: EchoShoot <https://github.com/EchoShoot>              #
#   Thanks: @hongwenjun <https://github.com/hongwenjun>           #
#   Intro:  http://tools.tisrop.com                               #
#=================================================================#

clear
echo
echo "#############################################################"
echo "# One click Install WireGuard Server                        #"
echo "# Intro: http://tools.tisrop.com                            #"
echo "# Author: EchoShoot                                         #"
echo "# Github: https://github.com/Echoshoot/tools                #"
echo "#############################################################"
echo

# Make sure only root can run our script
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] This script must be run as root!" && exit 1


# 获得服务器ip
# Get public IP address
get_ip(){
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    [ ! -z ${IP} ] && echo ${IP} || echo
}


#Config Table
Default_DNS="8.8.8.8"
Default_MTU="1420"
Server_Ip=$(get_ip)
Server_Port="443"


# Config WireGuard Server
config_wireguard_server(){
    cat > /etc/wireguard/wg0.conf<<-EOF
[Interface]
PrivateKey = ${Server_PrivateKey}
Address = 10.0.0.1/24
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
ListenPort = ${Server_Port}
DNS = ${Default_DNS}
MTU = $mtu

[Peer]
PublicKey = ${Client_PublicKey}
AllowedIPs = 10.0.0.2/32    
EOF
}


# Config WireGuard Client
config_wireguard_client(){
    cat > /etc/wireguard/client.conf<<-EOF
[Interface]
PrivateKey = ${Client_PrivateKey}
Address = 10.0.0.2/24
DNS = ${Default_DNS}
#  MTU = ${Default_MTU}
#  PreUp =  start   .\route\routes-up.bat
#  PostDown = start  .\route\routes-down.bat

[Peer]
PublicKey = ${Server_PublicKey}
Endpoint = ${Server_Ip}:${Server_Port}
AllowedIPs = 0.0.0.0/0, ::0/0
PersistentKeepalive = 25
EOF
}


# Install cleanup
install_cleanup(){
    echo
    echo "$(cat /etc/wireguard/client.conf)"
    echo
}


# install WireGuard
install(){
    # 添加 unstable 软件包源，以确保安装版本是最新的
    echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable.list
    printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' > /etc/apt/preferences.d/limit-unstable
    # 更新软件包源
    apt update
    # 安装和 linux-image 内核版本相对于的 linux-headers 内核
    apt install linux-headers-$(uname -r) -y
    # Debian9 安装后内核列表
    dpkg -l|grep linux-headers
    # 开始安装 WireGuard ，和辅助库 resolvconf
    apt install wireguard resolvconf -y
    # 验证是否安装成功
    modprobe wireguard && lsmod | grep wireguard
}


# Uninstall WireGuard
uninstall_WireGuard(){
    printf "Are you sure uninstall WireGuard? (y/n)"
    printf "\n"
    read -p "(Default: n):" answer
    [ -z ${answer} ] && answer="n"
    if [ "${answer}" == "y" ] || [ "${answer}" == "Y" ]; then
        echo "Sorry! Not Support yet"
        echo "WireGuard uninstall failed!"
    else
        echo
        echo "uninstall cancelled, nothing to do..."
        echo
    fi
}


sysctl_config() {
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
}


# Install WireGuard
install_WireGuard(){
    install
    # 配置文件夹
    mkdir -p /etc/wireguard
    cd /etc/wireguard
    # 然后开始生成 密匙对(公匙+私匙)。
    wg genkey | tee sprivatekey | wg pubkey > spublickey
    wg genkey | tee cprivatekey | wg pubkey > cpublickey
    Client_PublicKey=$(cat cpublickey)
    Client_PrivateKey=$(cat cprivatekey)
    Server_PublicKey=$(cat spublickey)
    Server_PrivateKey=$(cat sprivatekey)
    config_wireguard_server
    config_wireguard_client
    # 开启 BBR
    sysctl_config
    lsmod | grep bbr
    # 打开防火墙转发功能
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p
    # 启动 WireGuard
    wg-quick down wg0
    wg-quick up wg0
    # 设置开机启动
    systemctl enable wg-quick@wg0
    # 清理工作
    install_cleanup
}


# Initialization step
action=$1
[ -z $1 ] && action=install
case "$action" in
    install|uninstall)
        ${action}_WireGuard
        ;;
    *)
        echo "Arguments error! [${action}]"
        echo "Usage: `basename $0` [install|uninstall]"
        ;;
esac
