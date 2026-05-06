#!/bin/bash

# 发布 Agent 包到 GitHub Release
# 只上传尚未发布的文件
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

# 获取已发布的文件列表
echo "🔍 检查已发布的文件..."
EXISTING_FILES=""
LATEST_RELEASE=$(gh release list --repo "$REPO" --limit 1 --json tagName -q '.[0].tagName' 2>/dev/null || echo "")

if [ -n "$LATEST_RELEASE" ]; then
    echo "最新 Release: $LATEST_RELEASE"
    EXISTING_FILES=$(gh release view "$LATEST_RELEASE" --repo "$REPO" --json assets -q '.assets[].name' 2>/dev/null || echo "")
fi

# 检查是否有需要上传的新文件
NEW_FILES=()
for zip_file in agents/*.zip; do
    if [ -f "$zip_file" ]; then
        filename=$(basename "$zip_file")
        if ! echo "$EXISTING_FILES" | grep -q "^${filename}$"; then
            NEW_FILES+=("$zip_file")
            echo "  新文件: $filename"
        else
            echo "  已存在: $filename (跳过)"
        fi
    fi
done

if [ ${#NEW_FILES[@]} -eq 0 ]; then
    echo "✅ 所有文件已发布，无需更新"
    exit 0
fi

# 创建 Release
echo "🚀 创建 Release $VERSION..."
gh release create "$VERSION" \
    --repo "$REPO" \
    --title "Agent Packages $VERSION" \
    --notes "Automated release of agent packages" \
    --generate-notes

# 上传新文件
echo "📤 上传 Agent 包..."
for zip_file in "${NEW_FILES[@]}"; do
    filename=$(basename "$zip_file")
    echo "  上传: $filename"
    gh release upload "$VERSION" "$zip_file" \
        --repo "$REPO" \
        --clobber
done

echo "✅ 发布完成!"
echo ""
echo "下载地址格式:"
echo "https://github.com/$REPO/releases/download/$VERSION/<filename>"

# 输出每个新 agent 的下载链接
echo ""
echo "📋 新上传的 Agent 包下载地址:"
for zip_file in "${NEW_FILES[@]}"; do
    filename=$(basename "$zip_file")
    echo "https://github.com/$REPO/releases/download/$VERSION/$filename"
done