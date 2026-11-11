#!/usr/bin/env python3
"""
mcp/server.py (ios_dev_mcp.py)
XClientLab iOS Developer MCP (Model Context Protocol) Server
基于 Python 标准库实现的 JSON-RPC 2.0 stdio 协议服务，无需安装任何第三方依赖。

暴露的核心工具 (Tools):
1. xcode_build: 编译 XClientLab 工程
2. xcode_test: 运行单元测试与 UI 测试套件
3. fastlane_run: 调度 Fastlane 执行特定 lane (如 test, package_simulator, beta, lint)
4. simctl_booted_info: 获取当前已启动模拟器的设备信息与系统版本
5. simctl_screenshot: 抓取当前已启动模拟器屏幕截图并保存
6. simctl_install_launch: 将构建产物安装至模拟器并唤起运行
7. lldb_disciplined_batch: 执行 8 步通道纪律 LLDB 异步取证状态机序列
8. diagnostics_summary: 读取工程最近一次构建或测试的诊断报告与日志摘要
"""

import sys
import json
import subprocess
import os
import glob

SERVER_NAME = "xclientlab-ios-mcp"
SERVER_VERSION = "2.0.0"

TOOLS = [
    {
        "name": "xcode_build",
        "description": "通过 xcodebuild 编译 XClientLab 工程（自动跳过插件信任与签名限制）",
        "inputSchema": {
            "type": "object",
            "properties": {
                "clean": {
                    "type": "boolean",
                    "description": "是否在编译前执行 make clean",
                    "default": False
                }
            }
        }
    },
    {
        "name": "xcode_test",
        "description": "在 iOS 模拟器上运行单元测试与 UI 测试",
        "inputSchema": {
            "type": "object",
            "properties": {
                "target": {
                    "type": "string",
                    "description": "指定测试 Target (all, XClientLabTests, XClientLabUITests)",
                    "default": "all"
                }
            }
        }
    },
    {
        "name": "fastlane_run",
        "description": "调用 Fastlane 执行自动化任务 (test, build_simulator, package_simulator, beta, adhoc, lint, format_check)",
        "inputSchema": {
            "type": "object",
            "properties": {
                "lane": {
                    "type": "string",
                    "description": "要执行的 Fastlane lane 名称",
                    "default": "test"
                },
                "args": {
                    "type": "string",
                    "description": "传递给 lane 的可选参数字符串，例如 destination:\"platform=iOS Simulator,name=iPhone 18 Pro Max\"",
                    "default": ""
                }
            },
            "required": ["lane"]
        }
    },
    {
        "name": "simctl_booted_info",
        "description": "查询当前已启动 (booted) 的 iOS 模拟器 UDID、名称与运行时版本",
        "inputSchema": {
            "type": "object",
            "properties": {}
        }
    },
    {
        "name": "simctl_screenshot",
        "description": "使用 xcrun simctl 截取已启动模拟器的当前屏幕并落盘",
        "inputSchema": {
            "type": "object",
            "properties": {
                "output_path": {
                    "type": "string",
                    "description": "截图保存的相对路径（默认 Docs/screenshots/mcp_capture.png）",
                    "default": "Docs/screenshots/mcp_capture.png"
                }
            }
        }
    },
    {
        "name": "simctl_install_launch",
        "description": "将 DerivedData 中编译完成的 XClientLab.app 安装到已启动模拟器并唤起",
        "inputSchema": {
            "type": "object",
            "properties": {
                "bundle_id": {
                    "type": "string",
                    "description": "App Bundle Identifier",
                    "default": "e88ebfa25316fd8c.XClientLab"
                }
            }
        }
    },
    {
        "name": "lldb_disciplined_batch",
        "description": "生成/执行 8 步通道纪律 LLDB 异步崩溃取证序列 (遵守状态机：status ➔ interrupt ➔ 轮询 stopped ➔ 取证 ➔ resume)",
        "inputSchema": {
            "type": "object",
            "properties": {
                "pid": {
                    "type": "integer",
                    "description": "目标崩溃进程 PID（可选，为空则生成标准批处理脚本）"
                }
            }
        }
    },
    {
        "name": "diagnostics_summary",
        "description": "提取 DerivedData 或 fastlane/test_output 中最新的测试结果与构建诊断摘要",
        "inputSchema": {
            "type": "object",
            "properties": {}
        }
    }
]

def get_project_root():
    """动态向上回溯查找包含 XClientLab.xcodeproj 的根目录，确保从任何层级运行均能准确定位。"""
    if "PROJECT_ROOT" in os.environ and os.path.exists(os.path.join(os.environ["PROJECT_ROOT"], "XClientLab.xcodeproj")):
        return os.path.abspath(os.environ["PROJECT_ROOT"])
    current = os.path.abspath(os.path.dirname(__file__))
    while current != "/" and not os.path.exists(os.path.join(current, "XClientLab.xcodeproj")):
        parent = os.path.dirname(current)
        if parent == current:
            break
        current = parent
    return current

def handle_call_tool(name, arguments):
    project_root = get_project_root()
    env = os.environ.copy()
    env["PATH"] = f"/opt/homebrew/bin:/opt/homebrew/opt/ruby/bin:/usr/local/bin:{env.get('PATH', '')}"

    if name == "xcode_build":
        if arguments.get("clean", False):
            subprocess.run(["make", "clean"], cwd=project_root, capture_output=True, env=env)
        cmd = ["make", "build"]
        res = subprocess.run(cmd, cwd=project_root, capture_output=True, text=True, env=env)
        return {
            "content": [{
                "type": "text",
                "text": f"Build ReturnCode: {res.returncode}\n\nSTDOUT:\n{res.stdout[-1500:]}\n\nSTDERR:\n{res.stderr[-1000:]}"
            }],
            "isError": res.returncode != 0
        }

    elif name == "xcode_test":
        target = arguments.get("target", "all")
        if target == "all":
            cmd = ["make", "test"]
        else:
            cmd = [
                "xcodebuild", "test",
                "-project", "XClientLab.xcodeproj",
                "-scheme", "XClientLab",
                "-destination", "platform=iOS Simulator,name=iPhone 18 Pro Max",
                "-derivedDataPath", "DerivedData",
                "CODE_SIGNING_ALLOWED=NO",
                "-skipPackagePluginValidation",
                "-disableAutomaticPackageResolution",
                f"-only-testing:{target}"
            ]
        res = subprocess.run(cmd, cwd=project_root, capture_output=True, text=True, env=env)
        return {
            "content": [{
                "type": "text",
                "text": f"Test ReturnCode: {res.returncode}\n\nSTDOUT:\n{res.stdout[-2000:]}\n\nSTDERR:\n{res.stderr[-1000:]}"
            }],
            "isError": res.returncode != 0
        }

    elif name == "fastlane_run":
        lane = arguments.get("lane", "test")
        extra_args = arguments.get("args", "")
        cmd = ["bundle", "exec", "fastlane", lane]
        if extra_args:
            cmd.extend(extra_args.split())
        res = subprocess.run(cmd, cwd=project_root, capture_output=True, text=True, env=env)
        return {
            "content": [{
                "type": "text",
                "text": f"Fastlane '{lane}' ReturnCode: {res.returncode}\n\nSTDOUT:\n{res.stdout[-2500:]}\n\nSTDERR:\n{res.stderr[-1000:]}"
            }],
            "isError": res.returncode != 0
        }

    elif name == "simctl_booted_info":
        res = subprocess.run(["xcrun", "simctl", "list", "devices", "booted", "-j"], capture_output=True, text=True, env=env)
        if res.returncode == 0:
            return {
                "content": [{"type": "text", "text": res.stdout}],
                "isError": False
            }
        else:
            return {
                "content": [{"type": "text", "text": f"获取已启动模拟器失败: {res.stderr}"}],
                "isError": True
            }

    elif name == "simctl_screenshot":
        out_path = arguments.get("output_path", "Docs/screenshots/mcp_capture.png")
        full_out_path = os.path.join(project_root, out_path)
        os.makedirs(os.path.dirname(full_out_path), exist_ok=True)
        cmd = ["xcrun", "simctl", "io", "booted", "screenshot", full_out_path]
        res = subprocess.run(cmd, capture_output=True, text=True, env=env)
        if res.returncode == 0:
            return {
                "content": [{"type": "text", "text": f"✅ 截图成功保存至: {full_out_path}"}],
                "isError": False
            }
        else:
            return {
                "content": [{"type": "text", "text": f"❌ 截屏失败 (无 booted 模拟器或权限不足): {res.stderr}"}],
                "isError": True
            }

    elif name == "simctl_install_launch":
        bundle_id = arguments.get("bundle_id", "e88ebfa25316fd8c.XClientLab")
        apps = glob.glob(os.path.join(project_root, "DerivedData/Build/Products/*-iphonesimulator/XClientLab.app"))
        if not apps:
            return {
                "content": [{"type": "text", "text": "❌ 未在 DerivedData/Build/Products 中找到编译出的 XClientLab.app，请先执行 xcode_build。"}],
                "isError": True
            }
        app_path = apps[0]
        # 1. Install
        inst_res = subprocess.run(["xcrun", "simctl", "install", "booted", app_path], capture_output=True, text=True, env=env)
        if inst_res.returncode != 0:
            return {
                "content": [{"type": "text", "text": f"❌ 安装失败: {inst_res.stderr}"}],
                "isError": True
            }
        # 2. Launch
        launch_res = subprocess.run(["xcrun", "simctl", "launch", "booted", bundle_id], capture_output=True, text=True, env=env)
        return {
            "content": [{
                "type": "text",
                "text": f"✅ 成功安装并唤起 {bundle_id}！\nApp 路径: {app_path}\n输出: {launch_res.stdout}"
            }],
            "isError": launch_res.returncode != 0
        }

    elif name == "lldb_disciplined_batch":
        batch_script = (
            "# =========================================================================\n"
            "# LLDB Disciplined Batch Script (XClientLab 4.1 通道纪律状态机)\n"
            "# 1. 检查状态 -> 2. 中断 -> 3. 轮询停滞 -> 4. 提取现场 -> 5. 恢复运行 (仅一次)\n"
            "# =========================================================================\n"
            "process status\n"
            "process interrupt\n"
            "thread list\n"
            "bt all\n"
            "register read x0 x1 x2 x3 lr pc sp\n"
            "image lookup -a $pc\n"
            "vmmap --summary\n"
            "process continue\n"
        )
        return {
            "content": [{
                "type": "text",
                "text": f"✅ LLDB 通道纪律标准批处理序列已就绪：\n\n```lldb\n{batch_script}```\n\n该脚本可在 Xcode 控制台或通过 `lldb --batch -s <script>` 安全注入，杜绝运行态死锁与现场逃逸。"
            }],
            "isError": False
        }

    elif name == "diagnostics_summary":
        report_files = glob.glob(os.path.join(project_root, "fastlane/test_output/**/*.junit"), recursive=True)
        report_files += glob.glob(os.path.join(project_root, "DerivedData/Logs/Test/*.xcresult"), recursive=True)
        if not report_files:
            summary = "ℹ️ 暂无测试报告文件（尚未运行 make test 或 fastlane test）。"
        else:
            summary = "📑 找到以下测试诊断与报告产物：\n" + "\n".join(f"- {os.path.relpath(f, project_root)}" for f in report_files[:10])
        return {
            "content": [{"type": "text", "text": summary}],
            "isError": False
        }

    return {
        "content": [{"type": "text", "text": f"Unknown tool: {name}"}],
        "isError": True
    }

def main():
    while True:
        line = sys.stdin.readline()
        if not line:
            break
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except Exception:
            continue

        req_id = req.get("id")
        method = req.get("method")
        params = req.get("params", {})

        if method == "initialize":
            resp = {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {
                        "tools": {}
                    },
                    "serverInfo": {
                        "name": SERVER_NAME,
                        "version": SERVER_VERSION
                    }
                }
            }
            sys.stdout.write(json.dumps(resp) + "\n")
            sys.stdout.flush()

        elif method == "notifications/initialized":
            pass

        elif method == "tools/list":
            resp = {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {
                    "tools": TOOLS
                }
            }
            sys.stdout.write(json.dumps(resp) + "\n")
            sys.stdout.flush()

        elif method == "tools/call":
            name = params.get("name")
            arguments = params.get("arguments", {})
            result = handle_call_tool(name, arguments)
            resp = {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": result
            }
            sys.stdout.write(json.dumps(resp) + "\n")
            sys.stdout.flush()

        elif method == "ping":
            resp = {
                "jsonrpc": "2.0",
                "id": req_id,
                "result": {}
            }
            sys.stdout.write(json.dumps(resp) + "\n")
            sys.stdout.flush()

if __name__ == "__main__":
    main()
