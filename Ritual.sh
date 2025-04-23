#!/usr/bin/env bash

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
        echo "1) 安装 Ritual 节点"
        echo "2) 查看 Ritual 节点日志"
        echo "3) 删除 Ritual 节点"
        echo "4) 退出脚本"

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

# 安装 Ritual 节点函数
function install_ritual_node() {
    echo "开始安装 Ritual 节点 - $(date)"

    # 系统更新及必要的软件包安装 (包含 Python 和 pip)
    echo "系统更新及安装必要的包..."
    sudo apt update && sudo apt upgrade -y
    sudo apt -qy install curl git jq lz4 build-essential screen python3 python3-pip

    # 安装或升级 Python 包
    echo "[提示] 升级 pip3 并安装 infernet-cli / infernet-client"
    pip3 install --upgrade pip
    pip3 install infernet-cli infernet-client

    # 检查 Docker 是否已安装
    echo "检查 Docker 是否已安装..."
    if command -v docker &> /dev/null; then
        echo " - Docker 已安装，跳过此步骤。"
    else
        echo " - Docker 未安装，正在进行安装..."
        sudo apt update
        sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io
        sudo systemctl enable docker
        sudo systemctl start docker
        echo "Docker 安装完成，当前版本："
        docker --version
    fi

    # 检查 Docker Compose 安装情况
    echo "检查 Docker Compose 是否已安装..."
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo " - Docker Compose 未安装，正在进行安装..."
        sudo curl -L "https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        echo " - Docker Compose 已安装，跳过此步骤。"
    fi

    echo "[确认] Docker Compose 版本:"
    docker compose version || docker-compose version

    # 安装 Foundry 并设置环境变量
    echo "安装 Foundry "
    if pgrep anvil &>/dev/null; then
        echo "[警告] anvil 正在运行，正在关闭以更新 Foundry。"
        pkill anvil
        sleep 2
    fi

    cd ~ || exit 1
    mkdir -p foundry
    cd foundry
    curl -L https://foundry.paradigm.xyz | bash
    $HOME/.foundry/bin/foundryup
    if [[ ":$PATH:" != *":$HOME/.foundry/bin:"* ]]; then
        export PATH="$HOME/.foundry/bin:$PATH"
        echo 'export PATH="$HOME/.foundry/bin:$PATH"' >> ~/.bashrc
    fi

    echo "[确认] forge 版本:"
    forge --version || {
        echo "[错误] 无法找到 forge 命令，可能是 ~/.foundry/bin 未添加到 PATH 或安装失败。"
        exit 1
    }

    if [ -f /usr/bin/forge ]; then
        echo "[提示] 删除 /usr/bin/forge..."
        sudo rm /usr/bin/forge
    fi

    echo "[提示] Foundry 安装及环境变量配置完成。"
    cd ~ || exit 1

    # 克隆 infernet-container-starter
    if [ -d "infernet-container-starter" ]; then
        echo "目录 infernet-container-starter 已存在，正在删除..."
        rm -rf "infernet-container-starter"
    fi

    echo "克隆 infernet-container-starter..."
    git clone https://github.com/ritual-net/infernet-container-starter
    cd infernet-container-starter || { echo "[错误] 进入目录失败"; exit 1; }

    # 拉取 Docker 镜像
    echo "拉取 Docker 镜像..."
    docker pull ritualnetwork/hello-world-infernet:latest

    # 在 screen 会话中进行初始部署
    echo "检查 screen 会话 ritual 是否存在..."
    if screen -list | grep -q "ritual"; then
        echo "[提示] 发现 ritual 会话正在运行，正在终止..."
        screen -S ritual -X quit
        sleep 1
    fi

    echo "在 screen -S ritual 会话中开始容器部署..."
    screen -S ritual -dm bash -c 'project=hello-world make deploy-container; exec bash'
    echo "[提示] 部署工作正在后台的 screen 会话 (ritual) 中进行"

    # 用户输入 (Private Key)
    echo "配置 Ritual Node 文件..."
    read -p "请输入您的 Private Key (0x...): " PRIVATE_KEY
    echo "用户输入 Private Key: [隐藏]"

    # 修改 docker-compose.yaml 文件
    echo "修改 docker-compose.yaml 文件端口映射..."
    sed -i 's/ports:/ports:/' ~/infernet-container-starter/deploy/docker-compose.yaml
    sed -i 's/- "0.0.0.0:4000:4000"/- "0.0.0.0:4050:4000"/' ~/infernet-container-starter/deploy/docker-compose.yaml
    sed -i 's/- "8545:3000"/- "8550:3000"/' ~/infernet-container-starter/deploy/docker-compose.yaml

    # 默认设置
    RPC_URL="https://mainnet.base.org/"
    REGISTRY="0x3B1554f346DFe5c482Bb4BA31b880c1C18412170"
    SLEEP=3
    START_SUB_ID=240000
    BATCH_SIZE=50
    TRAIL_HEAD_BLOCKS=3

    # 修改配置文件
    sed -i "s|\"registry_address\": \".*\"|\"registry_address\": \"$REGISTRY\"|" deploy/config.json
    sed -i "s|\"private_key\": \".*\"|\"private_key\": \"$PRIVATE_KEY\"|" deploy/config.json
    sed -i "s|\"sleep\": [0-9]*|\"sleep\": $SLEEP|" deploy/config.json
    sed -i "s|\"starting_sub_id\": [0-9]*|\"starting_sub_id\": $START_SUB_ID|" deploy/config.json
    sed -i "s|\"batch_size\": [0-9]*|\"batch_size\": $BATCH_SIZE|" deploy/config.json
    sed -i "s|\"trail_head_blocks\": [0-9]*|\"trail_head_blocks\": $TRAIL_HEAD_BLOCKS|" deploy/config.json
    sed -i 's|"rpc_url": ".*"|"rpc_url": "https://mainnet.base.org"|' deploy/config.json
    sed -i 's|"rpc_url": ".*"|"rpc_url": "https://mainnet.base.org"|' projects/hello-world/container/config.json

    sed -i "s|\"registry_address\": \".*\"|\"registry_address\": \"$REGISTRY\"|" projects/hello-world/container/config.json
    sed -i "s|\"private_key\": \".*\"|\"private_key\": \"$PRIVATE_KEY\"|" projects/hello-world/container/config.json
    sed -i "s|\"sleep\": [0-9]*|\"sleep\": $SLEEP|" projects/hello-world/container/config.json
    sed -i "s|\"starting_sub_id\": [0-9]*|\"starting_sub_id\": $START_SUB_ID|" projects/hello-world/container/config.json
    sed -i "s|\"batch_size\": [0-9]*|\"batch_size\": $BATCH_SIZE|" projects/hello-world/container/config.json
    sed -i "s|\"trail_head_blocks\": [0-9]*|\"trail_head_blocks\": $TRAIL_HEAD_BLOCKS|" projects/hello-world/container/config.json

    sed -i "s|\(registry\s*=\s*\).*|\1$REGISTRY;|" projects/hello-world/contracts/script/Deploy.s.sol
    sed -i "s|\(RPC_URL\s*=\s*\).*|\1\"$RPC_URL\";|" projects/hello-world/contracts/script/Deploy.s.sol

    sed -i 's|ritualnetwork/infernet-node:[^"]*|ritualnetwork/infernet-node:latest|' deploy/docker-compose.yaml

    MAKEFILE_PATH="projects/hello-world/contracts/Makefile"
    sed -i "s|^sender := .*|sender := $PRIVATE_KEY|" "$MAKEFILE_PATH"
    sed -i "s|^RPC_URL := .*|RPC_URL := $RPC_URL|" "$MAKEFILE_PATH"

    # 启动容器
    cd ~/infernet-container-starter || exit 1
    echo "docker compose down & up..."
    docker compose -f deploy/docker-compose.yaml down
    docker compose -f deploy/docker-compose.yaml up -d
    echo "[提示] 容器正在后台 (-d) 运行"

    # 安装 Forge 库
    echo "安装 Forge (项目依赖)"
    cd projects/hello-world/contracts || exit 1
    rm -rf lib/forge-std
    rm -rf lib/infernet-sdk
    forge install --no-commit foundry-rs/forge-std
    forge install --no-commit ritual-net/infernet-sdk

    # 重启容器
    echo "重启 docker compose..."
    cd ~/infernet-container-starter || exit 1
    docker compose -f deploy/docker-compose.yaml down
    docker compose -f deploy/docker-compose.yaml up -d
    echo "[提示] 查看 infernet-node 日志：docker logs -f infernet-node"

    # 部署项目合约
    echo "部署项目合约..."
    DEPLOY_OUTPUT=$(project=hello-world make deploy-contracts 2>&1)
    echo "$DEPLOY_OUTPUT"

    NEW_ADDR=$(echo "$DEPLOY_OUTPUT" | grep -oP 'Deployed SaysHello:\s+\K0x[0-9a-fA-F]{40}')
    if [ -z "$NEW_ADDR" ]; then
        echo "[警告] 未找到新合约地址。可能需要手动更新 CallContract.s.sol。"
    else
        echo "[提示] 部署的 SaysHello 地址: $NEW_ADDR"
        sed -i "s|SaysGM saysGm = SaysGM(0x[0-9a-fA-F]\+);|SaysGM saysGm = SaysGM($NEW_ADDR);|" \
            projects/hello-world/contracts/script/CallContract.s.sol
        echo "使用新地址执行 call-contract..."
        project=hello-world make call-contract
    fi

    echo "===== Ritual Node 安装完成 ====="
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 查看 Ritual 节点日志
function view_logs() {
    echo "正在查看 Ritual 节点日志（实时输出）..."
    docker logs -f infernet-node
    echo "按任意键返回主菜单..."
    read -n 1 -s -r
    main_menu
}

# 删除 Ritual 节点
function remove_ritual_node() {
    echo "正在删除 Ritual 节点..."

    # 停止并移除 Docker 容器
    echo "停止并移除 Docker 容器..."
    if [ -d "~/infernet-container-starter" ]; then
        cd ~/infernet-container-starter || {
            echo "目录 ~/infernet-container-starter 不存在，跳过停止容器步骤。"
            return
        }
        docker compose down
    else
        echo "目录 ~/infernet-container-starter 不存在，跳过停止容器步骤。"
    fi

    # 逐个停止并删除容器
    containers=(
        "infernet-node"
        "infernet-fluentbit"
        "infernet-redis"
        "infernet-anvil"
        "hello-world"
    )

    for container in "${containers[@]}"; do
        if [ "$(docker ps -aq -f name=$container)" ]; then
            echo "Stopping and removing $container..."
            docker stop "$container"
            docker rm "$container"
        fi
    done

    # 删除相关文件
    echo "删除相关文件..."
    rm -rf ~/infernet-container-starter

    # 删除 Docker 镜像
    echo "删除 Docker 镜像..."
    docker rmi -f ritualnetwork/hello-world-infernet:latest
    docker rmi -f ritualnetwork/infernet-node:latest
    docker rmi -f fluent/fluent-bit:3.1.4
    docker rmi -f redis:7.4.0
    docker rmi -f ritualnetwork/infernet-anvil:1.0.0

    echo "Ritual 节点已成功删除！"
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 启动主菜单
main_menu
