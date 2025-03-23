#!/bin/bash

# Docker registry URL
REGISTRY_URL="crpi-84gohwg2zpoyckdg.cn-hangzhou.personal.cr.aliyuncs.com"

# # Docker credentials
# USERNAME="beng003"
# PASSWORD="qiepprqteot1"  # 从环境变量获取密码

# 获取镜像版本号，默认为 "test_compare"
VERSION=${1:-latest}

# 函数：打印日志信息
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# # 函数：Docker 登录
# docker_login() {
#     if [[ -z "$PASSWORD" ]]; then
#         log "请设置 DOCKER_PASSWORD 环境变量，或通过安全方式传递密码。"
#         exit 1
#     fi

#     # 登录 Docker 仓库
#     echo "$PASSWORD" | docker login --username "$USERNAME" --password-stdin "$REGISTRY_URL"
    
#     # 检查登录是否成功
#     if [ $? -ne 0 ]; then
#         log "Docker 登录失败！请检查用户名或密码。"
#         exit 1
#     else
#         log "Docker 登录成功！"
#     fi
# }

# 函数：标记和推送 Docker 镜像
docker_tag_and_push() {
    # 镜像名称
    LOCAL_IMAGE="secretflow/sf-dev-anolis8:$VERSION"
    REMOTE_IMAGE="$REGISTRY_URL/test-secretflow/sf-dev-anolis8:$VERSION"

    # 标记镜像
    log "正在标记镜像：$LOCAL_IMAGE 为 $REMOTE_IMAGE"
    docker tag "$LOCAL_IMAGE" "$REMOTE_IMAGE"
    
    if [ $? -ne 0 ]; then
        log "标记镜像失败，请检查镜像是否存在。"
        exit 1
    fi

    # 推送镜像
    log "正在推送镜像到仓库：$REMOTE_IMAGE"
    docker push "$REMOTE_IMAGE"
    
    if [ $? -ne 0 ]; then
        log "镜像推送失败，请检查网络连接和仓库权限。"
        exit 1
    else
        log "镜像推送成功：$REMOTE_IMAGE"
    fi
}

# 主逻辑
log "脚本开始执行..."
# docker_login
docker_tag_and_push
log "脚本执行完毕。"

