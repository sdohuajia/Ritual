#!/bin/bash
# 提取 MergedDir
MERGED_DIR=$(docker inspect infernet-anvil | jq -r '.[0].GraphDriver.Data.MergedDir')

if [ -z "$MERGED_DIR" ]; then
    echo "无法获取 MergedDir 路径"
    exit 1
fi

echo "找到 MergedDir: $MERGED_DIR"

# 2. 确定目标
TARGET_DIR="${MERGED_DIR}/root/.foundry/anvil/tmp"

if [ ! -d "$TARGET_DIR" ]; then
    echo "目标目录不存在: $TARGET_DIR"
    exit 1
fi

echo "正在处理目录: $TARGET_DIR"

# 3. 重命名子文件夹
for folder in "$TARGET_DIR"/*; do
    if [ -d "$folder" ]; then
        NEW_NAME=$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 10)
        PARENT_DIR=$(dirname "$folder")
        mv "$folder" "$PARENT_DIR/$NEW_NAME"
        echo "将 $(basename "$folder") 重命名为 $NEW_NAME"
    fi
done

echo "所有文件夹已随机重命名"
