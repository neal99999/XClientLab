# XClientLab —— 常用开发命令
#
# 依赖：Xcode 27.1+ / SwiftLint 0.65.x（构建期由 SPM 插件自带）/ SwiftFormat 0.64.x（CLI）

PROJECT      ?= XClientLab.xcodeproj
SCHEME       ?= XClientLab
DERIVED      ?= DerivedData
DESTINATION  ?= generic/platform=iOS Simulator
TEST_DESTINATION ?= platform=iOS Simulator,name=iPhone 18 Pro Max

XCODEBUILD   ?= xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
                -destination "$(DESTINATION)" -derivedDataPath "$(DERIVED)"
SWIFTLINT    ?= swiftlint
SWIFTFORMAT  ?= swiftformat

.PHONY: help resolve build test lint format format-check clean

help:
	@echo "make resolve       解析/更新 SPM 依赖（生成 Package.resolved）"
	@echo "make build         命令行构建（跳过插件信任提示）"
	@echo "make test          运行单元 + UI 测试"
	@echo "make lint          SwiftLint 静态检查（与构建期插件同配置）"
	@echo "make format        SwiftFormat 全量格式化 XClientLab/"
	@echo "make format-check  SwiftFormat 只检查不修改（CI 用）"
	@echo "make clean         清理 $(DERIVED)"

resolve:
	$(XCODEBUILD) -resolvePackageDependencies

build:
	$(XCODEBUILD) CODE_SIGNING_ALLOWED=NO -skipPackagePluginValidation build

test:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination "$(TEST_DESTINATION)" -derivedDataPath "$(DERIVED)" CODE_SIGNING_ALLOWED=NO -skipPackagePluginValidation -disableAutomaticPackageResolution test

lint:
	$(SWIFTLINT) lint --quiet --no-cache XClientLab

format:
	$(SWIFTFORMAT) XClientLab

format-check:
	$(SWIFTFORMAT) --lint XClientLab

clean:
	rm -rf "$(DERIVED)"
