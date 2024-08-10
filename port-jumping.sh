#!/bin/bash

# 脚本名称: manage-iptables.sh

# 检查是否以 root 用户身份运行
if [ "$(id -u)" -ne "0" ]; then
    echo "请以 root 用户身份运行此脚本"
    exit 1
fi

# 配置文件路径
CONFIG_FILE="/etc/iptables/custom-rules.conf"

# 安装 iptables-persistent
install_persistent() {
    if [ -x "$(command -v apt-get)" ]; then
        apt-get update
        apt-get install -y iptables-persistent
    elif [ -x "$(command -v yum)" ]; then
        yum install -y iptables-services
    else
        echo "不支持的操作系统，请手动安装 iptables-persistent 或 iptables-services"
        exit 1
    fi
}

# 添加规则
add_rules() {
    read -p "请输入 UDP 端口范围（格式：20000:50000）： " PORT_RANGE
    read -p "请输入 UDP 目标端口： " TARGET_PORT

    if [ -z "$PORT_RANGE" ] || [ -z "$TARGET_PORT" ]; then
        echo "端口范围和目标端口不能为空"
        exit 1
    fi

    # 添加规则到配置文件
    echo "iptables -A INPUT -p udp --dport $TARGET_PORT -j ACCEPT" >> $CONFIG_FILE
    echo "iptables -A INPUT -p udp --dport $PORT_RANGE -j ACCEPT" >> $CONFIG_FILE
    echo "iptables -t nat -A PREROUTING -p udp --dport $PORT_RANGE -j DNAT --to-destination :$TARGET_PORT" >> $CONFIG_FILE
    echo "规则已添加到 $CONFIG_FILE"
}

# 查看规则
view_rules() {
    if [ -f "$CONFIG_FILE" ]; then
        echo "当前规则配置:"
        cat $CONFIG_FILE
    else
        echo "没有找到配置文件 $CONFIG_FILE"
    fi
}

# 删除规则
delete_rules() {
    if [ -f "$CONFIG_FILE" ]; then
        echo "正在删除配置文件中的规则..."
        
        # 清除现有的 iptables 规则
        while read -r rule; do
            # 删除 NAT 规则
            if echo "$rule" | grep -q "iptables -t nat -D PREROUTING"; then
                eval "$rule"
            fi
        done < $CONFIG_FILE

        # 清除规则文件
        rm $CONFIG_FILE
        echo "规则已从 $CONFIG_FILE 中删除"
    else
        echo "没有找到配置文件 $CONFIG_FILE"
    fi
}

# 应用规则
apply_rules() {
    if [ -f "$CONFIG_FILE" ]; then
        # 清除现有规则
        iptables -F
        iptables -t nat -F
        
        # 应用配置文件中的规则
        while read -r rule; do
            eval "$rule"
        done < $CONFIG_FILE
        
        # 保存规则
        iptables-save > /etc/iptables/rules.v4
        
        echo "规则已应用并保存"
    else
        echo "没有找到配置文件 $CONFIG_FILE"
    fi
}

# 重启 iptables-persistent
restart_persistent() {
    if [ -x "$(command -v systemctl)" ]; then
        systemctl restart netfilter-persistent
    elif [ -x "$(command -v service)" ]; then
        service netfilter-persistent restart
    else
        echo "无法重启 iptables-persistent，您需要手动重启服务"
    fi
}

# 主菜单
echo "请选择操作:"
echo "1. 安装 iptables-persistent"
echo "2. 添加规则"
echo "3. 查看规则"
echo "4. 删除规则"
echo "5. 应用规则"
echo "6. 重启 iptables-persistent"
read -p "请输入选项 (1-6): " OPTION

case $OPTION in
    1) install_persistent ;;
    2) add_rules ;;
    3) view_rules ;;
    4) delete_rules ;;
    5) apply_rules ;;
    6) restart_persistent ;;
    *) echo "无效选项" ;;
esac
