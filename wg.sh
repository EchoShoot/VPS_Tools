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


# 颜色
# Color
Color_error='\033[0;91m'
Color_info='\033[0;92m'
Color_warning='\033[0;93m'
Color_title='\033[0;96m'
Color_end='\033[0m'


help_info(){
echo
echo -e "=============================================================="
echo -e "|      \      ${Color_title}One click Install WireGuard Server${Color_end}      /      |"
echo -e "|     Intro:  ${Color_info}http://tools.tisrop.com           ${Color_end}             |"
echo -e "|     Author: ${Color_info}EchoShoot                         ${Color_end}             |"
echo -e "|     Github: ${Color_info}https://github.com/Echoshoot/tools${Color_end}             |"
echo -e "=============================================================="
echo
}


# 获取公网IP地址
# Get public Server IP address
get_ip(){
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    [ ! -z ${IP} ] && echo ${IP} || echo
}


# 配置表
# Config Table
Default_DNS="8.8.8.8"
Default_MTU="1420"
Server_Ip=$(get_ip)
Server_Port="443"
Install_Path="/etc/wireguard"


# 配置 WireGuard 服务端
# Config WireGuard Server
config_wireguard_server(){
serverConf=${1}
serverIp=${2}

wg genkey | tee sprivatekey | wg pubkey > spublickey
    cat > "${Install_Path}/${serverConf}"<<-EOF
[Interface]
PrivateKey = $(cat sprivatekey)
Address = ${serverIp}/24
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
ListenPort = ${Server_Port}
DNS = ${Default_DNS}
MTU = ${Default_MTU}

EOF
}


# 配置 WireGuard 客户端
# Config WireGuard Client
config_wireguard_client(){
serverConf=${1}
clientConf=${2}
clientIp=${3}

# 生成秘钥对
wg genkey | tee cprivatekey | wg pubkey > cpublickey
    cat >> "${Install_Path}/${serverConf}"<<-EOF

[Peer]
PublicKey = $(cat cpublickey)
AllowedIPs = ${clientIp}/32
EOF

# 生成新的client配置文件
    cat > "${Install_Path}/${clientConf}"<<-EOF
[Interface]
PrivateKey = $(cat cprivatekey)
Address = ${clientIp}/24
DNS = ${Default_DNS}
#  MTU = ${Default_MTU}
#  PreUp =  start   .\route\routes-up.bat
#  PostDown = start  .\route\routes-down.bat

[Peer]
PublicKey = $(cat spublickey)
Endpoint = ${Server_Ip}:${Server_Port}
AllowedIPs = 0.0.0.0/0, ::0/0
PersistentKeepalive = 25
EOF

# 依据配置信息生成二维码
cat "${Install_Path}/${clientConf}" | qrencode -o "${Install_Path}/${clientConf}.png"
# 移除秘钥对
rm cprivatekey cpublickey
}


# 安装前的准备
# before install WireGuard
before_install(){
    # 确保当前环境以root权限运行
    [[ $EUID -ne 0 ]] && echo -e "${Color_error}[Error] This script must be run as root!${Color_end}" && exit 1
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
    # 安装qrencode方便生成二维码.
    apt install qrencode -y
    # 配置文件夹
    mkdir -p ${Install_Path}
}


# 进行安装与配置
# config WireGuard
config_wireguard(){
    cd ${Install_Path}
    config_wireguard_server "wg0.conf" "10.0.0.1"
    config_wireguard_client "wg0.conf" "client.conf" "10.0.0.2"
    config_wireguard_client "wg0.conf" "qrcode.conf" "10.0.0.5"
}


# 安装后的处理
# after installed WireGuard
after_installed(){
    # 开启 BBR
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    lsmod | grep bbr
    # 打开防火墙转发功能
    echo 1 > /proc/sys/net/ipv4/ip_forward
    sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p
    # 设置开机启动
    systemctl enable wg-quick@wg0
}


# 安装 WireGuard
# Install WireGuard
install_WireGuard(){
    # 安装前的准备
    before_install
    # 配置
    config_wireguard
    # 安装后的处理
    after_installed
    # 显示配置方案
    show_WireGuard
    # 重启 WireGuard
    wg-quick down wg0
    wg-quick up wg0
}


# 卸载 WireGuard
# Uninstall WireGuard
uninstall_WireGuard(){
    printf "Are you sure uninstall WireGuard? (y/n)"
    printf "\n"
    read -p "(Default: n):" answer
    [ -z ${answer} ] && answer="n"
    if [ "${answer}" == "y" ] || [ "${answer}" == "Y" ]; then
        echo "Sorry! Not Support yet!"
        echo "WireGuard uninstall failed!"
    else
        echo
        echo "uninstall cancelled, nothing to do..."
        echo
    fi
}


# 显示配置
# Show WireGuard
show_WireGuard(){
    cd ${Install_Path}
    clear
    help_info
    
    echo -e "${Color_title}> 二维码配置请访问:${Color_end}"
    for conffile in $(ls ${Install_Path} | grep ".*\.conf\.png$")
    do
        echo -e "      ${Color_info}http://${Server_Ip}:${Server_Port}/${conffile}${Color_end}"
    done
    
    echo -e "${Color_title}> 下载配置请访问:${Color_end}"
    for conffile in $(ls ${Install_Path} | grep ".*\.conf$")
    do
        echo -e "      ${Color_info}http://${Server_Ip}:${Server_Port}/${conffile}${Color_end}"
    done
    echo
    echo -e "${Color_warning}配置完毕后请手动: ctrl+c 之后才开始生效!${Color_end}"
    echo
    python -m SimpleHTTPServer ${Server_Port}
    clear
}


# 脚本带参数运行
# Initialization step
action=$1
[ -z $1 ] && action=install
case "$action" in
    install|uninstall|show)
        ${action}_WireGuard
        ;;
    *)
        help_info
        echo "Arguments error! [${action}]"
        echo -e "Usage: ${Color_warning}bash `basename $0` [install|uninstall|show]${Color_end}"
        ;;
esac
