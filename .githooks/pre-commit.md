#!/bin/bash
# .githooks/pre-commit

echo "🔍 检查暂存区 Swift 文件..."

# 获取本次提交暂存的 .swift 文件
STAGED_SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.swift$' || true)

if [ -z "$STAGED_SWIFT_FILES" ]; then
    echo "✨ 无 Swift 文件改动，跳过检查。"
    exit 0
fi

# 1. 自动执行格式化
if command -v swiftformat >/dev/null 2>&1; then
    echo "🎨 正在执行 SwiftFormat..."
    echo "$STAGED_SWIFT_FILES" | xargs swiftformat
    echo "$STAGED_SWIFT_FILES" | xargs git add
else
    echo "⚠️ 未安装 swiftformat，跳过格式化。"
fi

# 2. 静态检查
if command -v swiftlint >/dev/null 2>&1; then
    echo "🔎 正在执行 SwiftLint..."
    echo "$STAGED_SWIFT_FILES" | xargs swiftlint lint --quiet --no-cache
    if [ $? -ne 0 ]; then
        echo "❌ SwiftLint 校验失败，提交已中止！请修复以上警告/错误后再提交。"
        exit 1
    fi
else
    echo "⚠️ 未安装 swiftlint，跳过静态检查。"
fi

echo "✅ 预提交检查通过！"