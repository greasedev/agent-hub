#!/bin/bash

# 发布 Agent 包到 GitHub Release
# 只上传 index.json 中 packageUrl 引用的包，且跳过已存在的
# 用法: ./publish_agents.sh [--dryrun] [version]

set -e

REPO="greasedev/agent-hub"
DRYRUN=false
VERSION=""

# 解析参数
for arg in "$@"; do
    if [ "$arg" == "--dryrun" ]; then
        DRYRUN=true
    else
        VERSION="$arg"
    fi
done

if [ -z "$VERSION" ]; then
    VERSION="v$(date +%Y%m%d%H%M)"
fi

echo "📦 发布 Agent 包到 GitHub Release..."
echo "版本: $VERSION"
if [ "$DRYRUN" == true ]; then
    echo "模式: DRYRUN (仅预览，不执行)"
fi

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
    # 检查是否是本地路径（以 ./ 或非 URL 格式开头）
    if [[ "$url" == "./"* ]] || [[ "$url" != "http://"* ]] && [[ "$url" != "https://"* ]]; then
        filename=$(basename "$url")
        zip_file="agents/$filename"
        if [ -f "$zip_file" ]; then
            NEW_FILES+=("$zip_file")
            echo "  本地路径: $url -> 需上传: $filename"
        else
            echo "  ⚠️ 本地文件不存在: $filename (跳过)"
        fi
        continue
    fi

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
    echo "  需要提交 index.json..."
    if [ "$DRYRUN" == true ]; then
        echo "  [DRYRUN] 跳过提交: git add index.json && git commit && git push"
    else
        git add index.json
        git commit -m "chore: update index.json for release $VERSION"
        git push
    fi
fi

# 创建 Release
echo "🚀 创建 Release $VERSION..."
if [ "$DRYRUN" == true ]; then
    echo "  [DRYRUN] 跳过创建 Release"
else
    gh release create "$VERSION" \
        --repo "$REPO" \
        --title "Agent Packages $VERSION" \
        --notes "Automated release of agent packages" \
        --generate-notes
fi

# 上传新文件
echo "📤 上传 Agent 包..."
for zip_file in "${NEW_FILES[@]}"; do
    filename=$(basename "$zip_file")
    if [ "$DRYRUN" == true ]; then
        echo "  [DRYRUN] 跳过上传: $filename"
    else
        echo "  上传: $filename"
        gh release upload "$VERSION" "$zip_file" \
            --repo "$REPO" \
            --clobber
    fi
done

if [ "$DRYRUN" == true ]; then
    echo ""
    echo "✅ DRYRUN 完成 (未执行实际操作)"
else
    echo "✅ 发布完成!"

    # 更新 index.json 中新上传文件的 packageUrl 为具体版本链接
    echo "📝 更新 index.json 中的 packageUrl..."
    for zip_file in "${NEW_FILES[@]}"; do
        filename=$(basename "$zip_file")
        new_url="https://github.com/$REPO/releases/download/$VERSION/$filename"
        # 使用 jq 更新匹配的 packageUrl
        jq --arg filename "$filename" --arg new_url "$new_url" \
            'map(if (.packageUrl | endswith($filename)) then .packageUrl = $new_url else . end)' \
            index.json > index.json.tmp && mv index.json.tmp index.json
        echo "  更新: $filename -> $new_url"
    done

    # 提交更新后的 index.json
    if git diff --quiet index.json; then
        echo "  index.json 无改动"
    else
        git add index.json
        git commit -m "chore: update packageUrl to specific version $VERSION"
        git push
        echo "  已提交 index.json 更新"
    fi
fi
echo ""
echo "下载地址格式:"
echo "https://github.com/$REPO/releases/download/$VERSION/<filename>"