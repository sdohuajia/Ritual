#!/bin/bash

# 检查是否以 root 用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以 root 用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到 root 用户，然后再次运行此脚本。"
    exit 1
fi

# 脚本保存路径
SCRIPT_PATH="$HOME/Ritual.sh"

# 主菜单函数
function main_menu() {
    while true; do
        clear
        echo "脚本由大赌社区哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
        echo "如有问题，可联系推特，仅此只有一个号"
        echo "================================================================"
        echo "退出脚本，请按键盘 ctrl + C 退出即可"
        echo "请选择要执行的操作:"
        echo "1. 安装 Ritual 节点"
        echo "2. 查看 Ritual 节点日志"
        echo "3. 删除 Ritual 节点"
        echo "4. 退出脚本"
        
        read -p "请输入您的选择: " choice

        case $choice in
            1) 
                install_ritual_node
                ;;
            2)
                view_logs
                ;;
            3)
                remove_ritual_node
                ;;
            4)
                echo "退出脚本！"
                exit 0
                ;;
            *)
                echo "无效选项，请重新选择。"
                ;;
        esac

        echo "按任意键继续..."
        read -n 1 -s
    done
}

# 安装 Ritual 节点
function install_ritual_node() {
    echo "开始安装 Ritual 节点..."

    # 更新系统并安装依赖包
    echo "更新系统..."
    sudo apt update && sudo apt upgrade -y

    echo "安装所需包..."
    sudo apt -qy install curl git jq lz4 build-essential screen

    # 检测 Docker 和 Docker Compose
    echo "检查 Docker 是否安装..."
    if ! command -v docker &> /dev/null
    then
        echo "Docker 没有安装，正在安装 Docker..."
        sudo apt -qy install docker.io
    else
        echo "Docker 已安装"
    fi

    echo "检查 Docker Compose 是否安装..."
    if ! command -v docker-compose &> /dev/null
    then
        echo "Docker Compose 没有安装，正在安装 Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        echo "Docker Compose 已安装"
    fi

    # 克隆 Git 仓库并配置
    echo "从 GitHub 拉取仓库..."
    git clone https://github.com/ritual-net/infernet-container-starter ~/infernet-container-starter
    cd ~/infernet-container-starter

    # 用户输入私钥，提示信息为不可见
    echo "请输入您的钱包私钥（私钥输入时不可见）："
    read -s PRIVATE_KEY

    # 配置文件内容
    echo "配置文件正在写入..."
    cat > deploy/config.json <<EOL
{
    "log_path": "infernet_node.log",
    "server": {
        "port": 4000,
        "rate_limit": {
            "num_requests": 100,
            "period": 100
        }
    },
    "chain": {
        "enabled": true,
        "trail_head_blocks": 3,
        "rpc_url": "https://mainnet.base.org/",
        "registry_address": "0x3B1554f346DFe5c482Bb4BA31b880c1C18412170",
        "wallet": {
          "max_gas_limit": 4000000,
          "private_key": "$PRIVATE_KEY",
          "allowed_sim_errors": []
        },
        "snapshot_sync": {
          "sleep": 3,
          "batch_size": 10000,
          "starting_sub_id": 180000,
          "sync_period": 30
        }
    },
    "startup_wait": 1.0,
    "redis": {
        "host": "redis",
        "port": 6379
    },
    "forward_stats": true,
    "containers": [
        {
            "id": "hello-world",
            "image": "ritualnetwork/hello-world-infernet:latest",
            "external": true,
            "port": "3000",
            "allowed_delegate_addresses": [],
            "allowed_addresses": [],
            "allowed_ips": [],
            "command": "--bind=0.0.0.0:3000 --workers=2",
            "env": {},
            "volumes": [],
            "accepted_payments": {},
            "generates_proofs": false
        }
    ]
}
EOL

    echo "配置文件已成功写入！"

    # 安装 Foundry
    echo "安装 Foundry..."
    mkdir -p ~/foundry && cd ~/foundry
    curl -L https://foundry.paradigm.xyz | bash

    # 立即加载新的环境变量
    source ~/.bashrc

    # 等待环境变量生效
    echo "等待 Foundry 环境变量生效..."
    sleep 2

    # 验证 `foundryup` 是否成功安装
    source ~/.bashrc
    foundryup
    if [ $? -ne 0 ]; then
        echo "foundryup 安装失败，无法找到该命令。请检查安装过程。"
        exit 1
    fi

    echo "Foundry 安装完成！"

    # 安装合约依赖
    echo "进入 contracts 目录并安装依赖..."
    cd ~/infernet-container-starter/projects/hello-world/contracts

    # 删除已存在的无效目录
    rm -rf lib/forge-std
    rm -rf lib/infernet-sdk

    if ! command -v forge &> /dev/null
    then
        echo "forge 命令未找到，正在尝试安装依赖..."
        forge install --no-commit foundry-rs/forge-std
        forge install --no-commit ritual-net/infernet-sdk
    else
        echo "forge 已安装，安装依赖..."
        forge install --no-commit foundry-rs/forge-std
        forge install --no-commit ritual-net/infernet-sdk
    fi
    echo "依赖安装完成！"

    # 启动 Docker Compose
    echo "启动 Docker Compose..."
    cd ~/infernet-container-starter
    docker compose -f deploy/docker-compose.yaml up -d
    echo "Docker Compose 启动完成！"

    # 部署合约
    echo "部署合约..."
    cd ~/infernet-container-starter
    project=hello-world make deploy-contracts
    echo "合约部署完成！"

    echo "Ritual 节点安装完成！"
}

# 查看 Ritual 节点日志
function view_logs() {
    echo "正在查看 Ritual 节点日志..."
    docker logs -f infernet-node
}

# 删除 Ritual 节点
function remove_ritual_node() {
    echo "正在删除 Ritual 节点..."

    # 停止并移除 Docker 容器
    echo "停止并移除 Docker 容器..."
    docker-compose -f ~/infernet-container-starter/deploy/docker-compose.yaml down

    # 删除仓库文件
    echo "删除相关文件..."
    rm -rf ~/infernet-container-starter

    # 删除 Docker 镜像
    echo "删除 Docker 镜像..."
    docker rmi ritualnetwork/hello-world-infernet:latest

    echo "Ritual 节点已成功删除！"
}

# 调用主菜单函数
main_menu
