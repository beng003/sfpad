#!/bin/bash

# 设置错误处理：遇到任何错误时立即退出脚本执行
set -e

# 获取当前脚本的完整目录路径
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# Step 1: 进入 docker 目录
# 切换到 SecretFlow 项目的 docker 目录
cd ../secretflow/docker/

# Step 2: 安装 Python 项目依赖
# 安装 docker 目录下的 requirements.txt 中指定的依赖
pip install -r requirements.txt

# Step 3: 更新 meta 数据
# 设置 PYTHONPATH 环境变量，并运行 update_meta.py 脚本更新 meta 数据
env PYTHONPATH=$PYTHONPATH:$PWD/.. python update_meta.py

# Step 4: 进入 dev 目录
# 切换到 dev 子目录
cd dev/

# Step 5: 构建 Docker 镜像
# 通过第一个脚本参数指定镜像版本号（如未提供，默认为 latest）
IMAGE_NAME=${1:-latest}
echo "Building Docker image with name: $IMAGE_NAME"

# 调用 build.sh 脚本构建 Docker 镜像
sudo bash build.sh -v $IMAGE_NAME

# 打印完成提示信息
echo "Docker image $IMAGE_NAME build completed."

# Step 6: 更新 SecretFlow 组件
# 切换回脚本所在的原始目录
cd "$SCRIPT_DIR" || exit

# 定义要检查的文件名
FILE="update-sf-components.sh"

# 检查 update-sf-components.sh 是否存在
if [ ! -f "$FILE" ]; then
    echo "$FILE 文件不存在，开始执行 Docker 复制步骤..."

    # 从运行中的容器中复制脚本文件到本地，并赋予执行权限
    docker cp root-kuscia-master-secretpad:/app/scripts/update-sf-components.sh . && \
    chmod +x $FILE

    echo "$FILE 文件已复制并赋予执行权限。"

    # 修改文件中的容器名称
    sed -i 's/SECRETPAD_CONTAINER_NAME="${DEPLOY_USER}-kuscia-secretpad"/SECRETPAD_CONTAINER_NAME="${DEPLOY_USER}-kuscia-master-secretpad"/g' $FILE

    echo "$FILE 文件中的容器名称已更新。"
else
    echo "$FILE 文件已存在，跳过复制步骤。"
fi

# 执行 update-sf-components.sh 脚本更新 SecretFlow 组件
sudo bash update-sf-components.sh -u root -i secretflow/sf-dev-anolis8:$IMAGE_NAME

# Step 7: 拉取并执行 register_app_image.sh 脚本
# 定义要检查的文件名
FILE="register_app_image.sh"

# 检查 register_app_image.sh 是否存在
if [ ! -f "$FILE" ]; then
    echo "$FILE 文件不存在，开始执行下载步骤..."

    # 定义使用的 Kuscia 镜像
    export KUSCIA_IMAGE=secretflow-registry.cn-hangzhou.cr.aliyuncs.com/secretflow/kuscia

    # 拉取 Kuscia 镜像并提取 register_app_image.sh 脚本
    docker pull $KUSCIA_IMAGE && \
    docker run --rm $KUSCIA_IMAGE cat /home/kuscia/scripts/deploy/register_app_image.sh > $FILE

    # 赋予脚本执行权限
    chmod u+x $FILE

    sed -i '84s/.*/  if false; then/' $REGISTER_SCRIPT

    echo "$FILE 文件已下载并赋予执行权限。"
else
    echo "$FILE 文件已存在，跳过下载步骤。"
fi

# 执行 register_app_image.sh 脚本注册镜像
sudo bash register_app_image.sh -c root-kuscia-master -i secretflow/sf-dev-anolis8:$IMAGE_NAME -f app_image.secretflow.yaml
sudo bash register_app_image.sh -c root-kuscia-lite-alice -i secretflow/sf-dev-anolis8:$IMAGE_NAME --import
sudo bash register_app_image.sh -c root-kuscia-lite-bob -i secretflow/sf-dev-anolis8:$IMAGE_NAME --import

# 打印部署完成信息
echo "部署完成！版本号：$IMAGE_NAME"
