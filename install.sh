#!/bin/bash

# 版本号
TS3_VERSION="3.13.7"

# 检查操作系统类型
os_type=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)

# 安装依赖项和创建用户
install_dependencies() {
    if [ "$os_type" = "debian" ] || [ "$os_type" = "ubuntu" ]; then
        sudo apt-get update || { echo "更新软件包列表失败"; exit 1; }
        sudo apt-get install -y wget tar ufw || { echo "安装依赖项失败"; exit 1; }
        sudo adduser --disabled-login --gecos "" ts3user || { echo "创建用户失败"; exit 1; }
    elif [ "$os_type" = "centos" ]; then
        sudo yum update -y || { echo "更新软件包列表失败"; exit 1; }
        sudo yum install -y wget tar || { echo "安装依赖项失败"; exit 1; }
        sudo adduser ts3user || { echo "创建用户失败"; exit 1; }
    else
        echo "不支持的操作系统类型: $os_type"
        exit 1
    fi
}

# 下载并安装TS3
install_ts3() {
    cd /home/ts3user || { echo "进入目录失败"; exit 1; }
    wget https://files.teamspeak-services.com/releases/server/$TS3_VERSION/teamspeak3-server_linux_amd64-$TS3_VERSION.tar.bz2 || { echo "下载文件失败"; exit 1; }
    tar xvjf teamspeak3-server_linux_amd64-$TS3_VERSION.tar.bz2 || { echo "解压文件失败"; exit 1; }
    rm teamspeak3-server_linux_amd64-$TS3_VERSION.tar.bz2
    sudo chown -R ts3user:ts3user teamspeak3-server_linux_amd64
    echo "TS3 安装完成"
}

# 设置TS3为系统服务
setup_service() {
    sudo bash -c 'cat <<EOL >/etc/systemd/system/ts3server.service
[Unit]
Description=TeamSpeak 3 Server
After=network.target

[Service]
Environment="TS3SERVER_LICENSE=accept"
WorkingDirectory=/home/ts3user/teamspeak3-server_linux_amd64
User=ts3user
Group=ts3user
Type=forking
ExecStart=/home/ts3user/teamspeak3-server_linux_amd64/ts3server_startscript.sh start
ExecStop=/home/ts3user/teamspeak3-server_linux_amd64/ts3server_startscript.sh stop
ExecReload=/bin/kill -s HUP $MAINPID
PIDFile=/home/ts3user/teamspeak3-server_linux_amd64/ts3server.pid
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL'

    sudo systemctl daemon-reload
    sudo systemctl enable ts3server
    sudo systemctl start ts3server
    echo "TS3 服务已启动并设置为开机自启动"
}

# 配置防火墙
configure_firewall() {
    if [ "$os_type" = "debian" ] || [ "$os_type" = "ubuntu" ]; then
        sudo ufw allow 9987/udp
        sudo ufw allow 10011/tcp
        sudo ufw allow 30033/tcp
        sudo ufw reload
    elif [ "$os_type" = "centos" ]; then
        sudo firewall-cmd --zone=public --add-port=9987/udp --permanent
        sudo firewall-cmd --zone=public --add-port=10011/tcp --permanent
        sudo firewall-cmd --zone=public --add-port=30033/tcp --permanent
        sudo firewall-cmd --reload
    fi
    echo "防火墙规则已更新"
}

# 查询初始化token
query_token() {
    sudo cat /home/ts3user/teamspeak3-server_linux_amd64/logs/*.log | grep "token="
}

# 设置WebQuery配置
setup_webquery() {
    sudo bash -c 'echo "query_protocols=raw,ssh" >> /home/ts3user/teamspeak3-server_linux_amd64/ts3server.ini'
    sudo bash -c 'echo "query_ip_whitelist=query_ip_whitelist.txt" >> /home/ts3user/teamspeak3-server_linux_amd64/ts3server.ini'
    sudo bash -c 'echo "query_ip_blacklist=query_ip_blacklist.txt" >> /home/ts3user/teamspeak3-server_linux_amd64/ts3server.ini'
    sudo bash -c 'echo "query_timeout=300" >> /home/ts3user/teamspeak3-server_linux_amd64/ts3server.ini'
    sudo bash -c 'echo "query_ssh_rsa_host_key=query_ssh_rsa_host_key" >> /home/ts3user/teamspeak3-server_linux_amd64/ts3server.ini'
    sudo systemctl restart ts3server
    echo "WebQuery 已配置并重启服务器"
}

# 卸载TS3服务器
uninstall_ts3() {
    sudo systemctl stop ts3server
    sudo systemctl disable ts3server
    sudo rm -rf /etc/systemd/system/ts3server.service
    sudo rm -rf /home/ts3user/teamspeak3-server_linux_amd64
    sudo userdel -r ts3user
    sudo systemctl daemon-reload
    echo "TS3服务器已卸载"
    exit 0
}

# 显示菜单
show_menu() {
    echo "选择操作："
    echo "1) 安装TS3服务器"
    echo "2) 启动TS3服务器"
    echo "3) 停止TS3服务器"
    echo "4) 重启TS3服务器"
    echo "5) 查询初始化Token"
    echo "6) 设置WebQuery"
    echo "7) 卸载TS3服务器"
    echo "8) 退出"
    read -p "请输入选项 [1-8]: " choice

    case $choice in
        1) 
            install_dependencies
            install_ts3
            setup_service
            configure_firewall
            ;;
        2) sudo systemctl start ts3server ;;
        3) sudo systemctl stop ts3server ;;
        4) sudo systemctl restart ts3server ;;
        5) query_token ;;
        6) setup_webquery ;;
        7) uninstall_ts3 ;;
        8) exit 0 ;;
        *) echo "无效选项，请重新输入。" ;;
    esac
}

# 主函数
main() {
    while true; do
        show_menu
    done
}
