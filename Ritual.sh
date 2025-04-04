#!/usr/bin/env bash

# 检查是否以 root 用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以 root 用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到 root 用户，然后再次运行此脚本。"
    exit 1
fi

# 脚本保存路径
SCRIPT_PATH="$HOME/Ritual.sh"

# 日志文件路径
LOG_FILE="/root/ritual_install.log"
DOCKER_LOG_FILE="/root/infernet_node.log"

# 初始化日志文件
echo "Ritual 脚本日志 - $(date)" > "$LOG_FILE"
echo "Docker 容器日志 - $(date)" > "$DOCKER_LOG_FILE"

# 主菜单函数
function main_menu() {
    while true; do
        clear
        echo "脚本由大赌社区哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费" | tee -a "$LOG_FILE"
        echo "如有问题，可联系推特，仅此只有一个号" | tee -a "$LOG_FILE"
        echo "================================================================" | tee -a "$LOG_FILE"
        echo "退出脚本，请按键盘 ctrl + C 退出即可" | tee -a "$LOG_FILE"
        echo "请选择要执行的操作:" | tee -a "$LOG_FILE"
        echo "1) 安装 Ritual 节点" | tee -a "$LOG_FILE"
        echo "2. 查看 Ritual 节点日志" | tee -a "$LOG_FILE"
        echo "3. 删除 Ritual 节点" | tee -a "$LOG_FILE"
        echo "4. 退出脚本" | tee -a "$LOG_FILE"
        
        read -p "请输入您的选择: " choice
        echo "用户选择: $choice" >> "$LOG_FILE"

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
                echo "退出脚本！" | tee -a "$LOG_FILE"
                exit 0
                ;;
            *)
                echo "无效选项，请重新选择。" | tee -a "$LOG_FILE"
                ;;
        esac

        echo "按任意键继续..." | tee -a "$LOG_FILE"
        read -n 1 -s
    done
}

# 安装 Ritual 节点函数
function install_ritual_node() {
    # 请求输入私钥，隐藏输入内容
    echo "请输入您的私钥（如果需要，请带上 0x 前缀）"
    echo "注意：为安全起见，输入内容将隐藏"
    read -s private_key
    echo "已接收私钥（为安全起见已隐藏）"

    # 如果缺少 0x 前缀，自动添加
    if [[ ! $private_key =~ ^0x ]]; then
        private_key="0x$private_key"
        echo "已为私钥添加 0x 前缀"
    fi

    echo "正在安装依赖项..."

    # 更新软件包和构建工具
    sudo apt update && sudo apt upgrade -y
    sudo apt -qy install curl git jq lz4 build-essential screen

    # 安装 Docker
    echo "正在安装 Docker..."
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker $USER
    docker run hello-world

    # 安装 Docker Compose
    echo "正在安装 Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    docker compose version

    # 克隆仓库
    echo "正在克隆仓库..."
    git clone https://github.com/ritual-net/infernet-container-starter
    cd ~/infernet-container-starter || exit 1

    # 创建配置文件
    echo "正在创建配置文件..."
    cat > deploy/config.json << EOL
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
          "private_key": "${private_key}",
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

    # 将配置复制到容器文件夹
    cp deploy/config.json projects/hello-world/container/config.json

    # 创建 Deploy.s.sol
    cat > projects/hello-world/contracts/script/Deploy.s.sol << EOL
// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {SaysGM} from "../src/SaysGM.sol";

contract Deploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address deployerAddress = vm.addr(deployerPrivateKey);
        console2.log("已加载部署者: ", deployerAddress);
        address registry = 0x3B1554f346DFe5c482Bb4BA31b880c1C18412170;
        SaysGM saysGm = new SaysGM(registry);
        console2.log("已部署 SaysHello: ", address(saysGm));
        vm.stopBroadcast();
        vm.broadcast();
    }
}
EOL

    # 创建 Makefile
    cat > projects/hello-world/contracts/Makefile << EOL
.PHONY: deploy call-contract

sender := ${private_key}
RPC_URL := https://mainnet.base.org/

deploy:
    @PRIVATE_KEY=\$(sender) forge script script/Deploy.s.sol:Deploy --broadcast --rpc-url \$(RPC_URL)

call-contract:
    @PRIVATE_KEY=\$(sender) forge script script/CallContract.s.sol:CallContract --broadcast --rpc-url \$(RPC_URL)
EOL

    # 编辑 docker-compose.yaml 中的节点版本
    sed -i 's/infernet-node:.*/infernet-node:1.4.0/g' deploy/docker-compose.yaml

    # 使用 systemd 部署容器
    echo "正在为 Ritual Network 创建 systemd 服务..."
    cat > ~/ritual-service.sh << EOL
#!/bin/bash
cd ~/infernet-container-starter
echo "在 \$(date) 开始容器部署" > ~/ritual-deployment.log
project=hello-world make deploy-container >> ~/ritual-deployment.log 2>&1
echo "容器部署在 \$(date) 完成" >> ~/ritual-deployment.log

while true; do
  echo "在 \$(date) 检查容器" >> ~/ritual-deployment.log
  if ! docker ps | grep -q "infernet"; then
    echo "容器已停止。在 \$(date) 重启" >> ~/ritual-deployment.log
    docker compose -f deploy/docker-compose.yaml up -d >> ~/ritual-deployment.log 2>&1
  else
    echo "容器在 \$(date) 正常运行" >> ~/ritual-deployment.log
  fi
  sleep 300
done
EOL

    chmod +x ~/ritual-service.sh

    # 创建 systemd 服务文件
    sudo tee /etc/systemd/system/ritual-network.service > /dev/null << EOL
[Unit]
Description=Ritual Network Infernet 服务
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=root
ExecStart=/bin/bash /root/ritual-service.sh
Restart=always
RestartSec=30
StandardOutput=append:/root/ritual-service.log
StandardError=append:/root/ritual-service.log

[Install]
WantedBy=multi-user.target
EOL

    # 启动 systemd 服务
    sudo systemctl daemon-reload
    sudo systemctl enable ritual-network.service
    sudo systemctl start ritual-network.service

    # 验证服务状态
    sleep 5
    if sudo systemctl is-active --quiet ritual-network.service; then
        echo "✔ Ritual Network 服务启动成功！"
    else
        echo "⚠ 警告：服务可能未正确启动。正在检查状态..."
        sudo systemctl status ritual-network.service
    fi
    echo "服务日志正在保存到 ~/ritual-deployment.log"

    # 安装 Foundry
    echo "正在安装 Foundry..."
    cd ~ || exit 1
    mkdir -p foundry && cd foundry
    pkill anvil 2>/dev/null || true
    sleep 2
    curl -L https://foundry.paradigm.xyz | bash
    export PATH="$HOME/.foundry/bin:$PATH"
    $HOME/.foundry/bin/foundryup || foundryup
    if ! command -v forge &> /dev/null; then
        echo 'export PATH="$PATH:$HOME/.foundry/bin"' >> ~/.bashrc
        source ~/.bashrc
    fi
    if [ -f /usr/bin/forge ]; then
        sudo rm /usr/bin/forge
    fi

    # 安装 Forge 依赖
    echo "正在安装 Forge 依赖..."
    cd ~/infernet-container-starter/projects/hello-world/contracts || exit 1
    rm -rf lib/forge-std lib/infernet-sdk 2>/dev/null || true
    forge install --no-commit foundry-rs/forge-std
    forge install --no-commit ritual-net/infernet-sdk

    # 重启容器
    echo "正在重启容器..."
    cd ~/infernet-container-starter || exit 1
    docker compose -f deploy/docker-compose.yaml down
    docker compose -f deploy/docker-compose.yaml up -d

    # 部署合约并捕获地址
    echo "正在部署消费者合约..."
    export PRIVATE_KEY="${private_key#0x}"
    deployment_output=$(project=hello-world make deploy-contracts 2>&1)
    echo "$deployment_output" > ~/deployment-output.log
    contract_address=$(echo "$deployment_output" | grep -oE "已部署 SaysHello: 0x[a-fA-F0-9]{40}" | awk '{print $4}')

    if [ -z "$contract_address" ]; then
        echo "⚠ 无法自动提取合约地址。请检查 ~/deployment-output.log 并手动输入："
        read -p "请输入合约地址（格式为 0x...）： " contract_address
    else
        echo "✔ 成功提取合约地址：$contract_address"
    fi
    echo "$contract_address" > ~/contract-address.txt

    # 更新 CallContract.s.sol
    echo "使用合约地址更新 CallContract.s.sol：$contract_address"
    cat > projects/hello-world/contracts/script/CallContract.s.sol << EOL
// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {SaysGM} from "../src/SaysGM.sol";

contract CallContract is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        SaysGM saysGm = SaysGM($contract_address);
        saysGm.sayGM();
        vm.stopBroadcast();
        vm.broadcast();
    }
}
EOL

    # 调用合约
    echo "调用合约以测试功能..."
    project=hello-world make call-contract

    # 检查容器和日志
    echo "检查容器是否正在运行..."
    docker ps | grep infernet
    echo "检查节点日志..."
    docker logs infernet-node 2>&1 | tail -n 20

    echo "===== Ritual Node 安装完成 ====="
    read -n 1 -s -r -p "按任意键返回主菜单..."
    main_menu
}

# 查看 Ritual 节点日志
function view_logs() {
    echo "正在查看 Ritual 节点日志（实时输出到 $DOCKER_LOG_FILE）..." | tee -a "$LOG_FILE"
    tail -f "$DOCKER_LOG_FILE"
}

# 删除 Ritual 节点
function remove_ritual_node() {
    echo "正在删除 Ritual 节点 - $(date)" | tee -a "$LOG_FILE"

    # 停止并移除 Docker 容器
    echo "停止并移除 Docker 容器..." | tee -a "$LOG_FILE"
    cd /root/infernet-container-starter || echo "目录不存在，跳过 docker compose down" | tee -a "$LOG_FILE"
    if [ -d "/root/infernet-container-starter" ]; then
        docker compose down >> "$LOG_FILE" 2>&1
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
            echo "Stopping and removing $container..." | tee -a "$LOG_FILE"
            docker stop "$container" >> "$LOG_FILE" 2>&1
            docker rm "$container" >> "$LOG_FILE" 2>&1
        fi
    done

    # 删除相关文件
    echo "删除相关文件..." | tee -a "$LOG_FILE"
    rm -rf ~/infernet-container-starter >> "$LOG_FILE" 2>&1

    # 删除 Docker 镜像
    echo "删除 Docker 镜像..." | tee -a "$LOG_FILE"
    docker rmi -f ritualnetwork/hello-world-infernet:latest >> "$LOG_FILE" 2>&1
    docker rmi -f ritualnetwork/infernet-node:latest >> "$LOG_FILE" 2>&1
    docker rmi -f fluent/fluent-bit:3.1.4 >> "$LOG_FILE" 2>&1
    docker rmi -f redis:7.4.0 >> "$LOG_FILE" 2>&1
    docker rmi -f ritualnetwork/infernet-anvil:1.0.0 >> "$LOG_FILE" 2>&1

    # 清理后台日志进程
    echo "清理后台日志进程..." | tee -a "$LOG_FILE"
    pkill -f "docker logs -f infernet-node" 2>/dev/null || echo "无后台日志进程需要清理" | tee -a "$LOG_FILE"

    echo "Ritual 节点已成功删除！" | tee -a "$LOG_FILE"
}

# 调用主菜单函数
main_menu
