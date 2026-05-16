#!/bin/bash

# 发布 Agent 包到 GitHub Release
# 只上传 index.json 中 packageUrl 引用的包，且跳过已存在的
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

# 从 index.json 提取 packageUrl
echo "📋 解析 index.json 中的 packageUrl..."
PACKAGE_URLS=()
while IFS= read -r url; do
    if [ -n "$url" ]; then
        PACKAGE_URLS+=("$url")
        echo "  引用: $url"
    fi
done < <(jq -r '.[].packageUrl' index.json)

if [ ${#PACKAGE_URLS[@]} -eq 0 ]; then
    echo "❌ index.json 中没有找到 packageUrl"
    exit 1
fi

# 检查 packageUrl 是否可访问
echo "🔍 检查 packageUrl 是否可访问..."
NEW_FILES=()
for url in "${PACKAGE_URLS[@]}"; do
    filename=$(basename "$url")
    zip_file="agents/$filename"

    if [ ! -f "$zip_file" ]; then
        echo "  ⚠️ 文件不存在: $filename (跳过)"
        continue
    fi

    # 用 curl 跟随重定向检查 URL 是否可下载（HTTP 200）
    if curl -sfLI "$url" > /dev/null 2>&1; then
        echo "  已存在: $url (跳过)"
    else
        NEW_FILES+=("$zip_file")
        echo "  新文件: $filename"
    fi
done

if [ ${#NEW_FILES[@]} -eq 0 ]; then
    echo "✅ 所有文件已发布，无需更新"
    exit 0
fi

# 提交 index.json（如果有改动）
echo "📝 检查 index.json 状态..."
if git diff --quiet index.json && git diff --cached --quiet index.json; then
    echo "  index.json 无改动"
else
    echo "  提交 index.json..."
    git add index.json
    git commit -m "chore: update index.json for release $VERSION"
    git push
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