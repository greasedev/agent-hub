#!/bin/bash

# 发布 Agent 包到 GitHub Release
# 用法: ./publish_agents.sh [version]

set -e

REPO="greasedev/agent-hub"
VERSION=${1:-"v$(date +%Y%m%d%H%M)"}

echo "📦 发布 Agent 包到 GitHub Release..."
echo "版本: $VERSION"

# 检查 gh CLI 是否安装
if ! command -v gh &> /dev/null; then
    echo "❌ 请先安装 GitHub CLI (gh)"
    exit 1
fi

# 检查是否已登录
if ! gh auth status &> /dev/null; then
    echo "❌ 请先登录 GitHub CLI: gh auth login"
    exit 1
fi

# 创建 Release
echo "🚀 创建 Release $VERSION..."
gh release create "$VERSION" \
    --repo "$REPO" \
    --title "Agent Packages $VERSION" \
    --notes "Automated release of agent packages" \
    --generate-notes

# 上传 agents 目录中的所有 zip 文件
echo "📤 上传 Agent 包..."
for zip_file in agents/*.zip; do
    if [ -f "$zip_file" ]; then
        filename=$(basename "$zip_file")
        echo "  上传: $filename"
        gh release upload "$VERSION" "$zip_file" \
            --repo "$REPO" \
            --clobber
    fi
done

echo "✅ 发布完成!"
echo ""
echo "下载地址格式:"
echo "https://github.com/$REPO/releases/download/$VERSION/<filename>"

# 输出每个 agent 的下载链接
echo ""
echo "📋 各 Agent 包下载地址:"
for zip_file in agents/*.zip; do
    if [ -f "$zip_file" ]; then
        filename=$(basename "$zip_file")
        echo "https://github.com/$REPO/releases/download/$VERSION/$filename"
    fi
done