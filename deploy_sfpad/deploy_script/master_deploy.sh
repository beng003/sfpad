#!/bin/bash

# 设置错误处理：任何命令出错时立即退出
set -e

# 获取当前脚本的完整目录路径
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# Docker registry URL
REGISTRY_URL="crpi-84gohwg2zpoyckdg.cn-hangzhou.personal.cr.aliyuncs.com"

# 获取镜像版本号，默认为 "latest"
VERSION=${1:-latest}

# 定义镜像名称
REMOTE_IMAGE="$REGISTRY_URL/test-secretflow/sf-dev-anolis8:$VERSION"

# 函数：打印日志信息
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# 函数：拉取 Docker 镜像
docker_pull() {
    log "正在拉取镜像：$REMOTE_IMAGE"
    if docker pull "$REMOTE_IMAGE"; then
        log "镜像拉取成功：$REMOTE_IMAGE"
    else
        log "镜像拉取失败，请检查网络连接和镜像是否存在。"
        exit 1
    fi
}

# 主逻辑
log "脚本开始执行..."
docker_pull

# 提示拉取完成
log "Docker 镜像拉取完成：$REMOTE_IMAGE"

# Step 1: 更新 SecretFlow 组件
cd "$SCRIPT_DIR" || exit 1

# 检查并复制 `update-sf-components.sh`
UPDATE_SF_SCRIPT="update-sf-components.sh"

if [ ! -f "$UPDATE_SF_SCRIPT" ]; then
    log "$UPDATE_SF_SCRIPT 文件不存在，开始执行 Docker 复制步骤..."
    docker cp root-kuscia-master-secretpad:/app/scripts/update-sf-components.sh . && chmod +x "$UPDATE_SF_SCRIPT"
    log "$UPDATE_SF_SCRIPT 文件已复制并赋予执行权限。"

    # 修改文件中的容器名称
    sed -i 's/SECRETPAD_CONTAINER_NAME="${DEPLOY_USER}-kuscia-secretpad"/SECRETPAD_CONTAINER_NAME="${DEPLOY_USER}-kuscia-master-secretpad"/g' "$UPDATE_SF_SCRIPT"
    log "$UPDATE_SF_SCRIPT 文件中的容器名称已更新。"
else
    log "$UPDATE_SF_SCRIPT 文件已存在，跳过复制步骤。"
fi

# 执行 `update-sf-components.sh`
log "执行 $UPDATE_SF_SCRIPT 更新 SecretFlow 组件..."
sudo bash "$UPDATE_SF_SCRIPT" -u root -i "$REMOTE_IMAGE"

# Step 2: 拉取并执行 `register_app_image.sh`
REGISTER_SCRIPT="${SCRIPT_DIR}/register_app_image.sh"

if [ ! -f "$REGISTER_SCRIPT" ]; then
    log "$REGISTER_SCRIPT 文件不存在，开始执行下载步骤..."
    
    # 定义 Kuscia 镜像
    KUSCIA_IMAGE="secretflow-registry.cn-hangzhou.cr.aliyuncs.com/secretflow/kuscia"

    # 拉取 Kuscia 镜像并提取脚本
    docker pull "$KUSCIA_IMAGE"
    docker run --rm "$KUSCIA_IMAGE" cat /home/kuscia/scripts/deploy/register_app_image.sh > "$REGISTER_SCRIPT"
    chmod u+x "$REGISTER_SCRIPT"

    sed -i '84s/.*/  if false; then/' $REGISTER_SCRIPT

    log "$REGISTER_SCRIPT 文件已下载并赋予执行权限。"
else
    log "$REGISTER_SCRIPT 文件已存在，跳过下载步骤。"
fi

# 注册镜像到不同容器
log "执行 $REGISTER_SCRIPT 注册镜像..."
sudo bash "$REGISTER_SCRIPT" -c root-kuscia-master -i "$REMOTE_IMAGE" -f app_image.secretflow.yaml
sudo bash "$REGISTER_SCRIPT" -c root-kuscia-lite-alice -i "$REMOTE_IMAGE" --import
sudo bash "$REGISTER_SCRIPT" -c root-kuscia-lite-bob -i "$REMOTE_IMAGE" --import

# 打印部署完成信息
log "部署完成！版本号：$VERSION"
