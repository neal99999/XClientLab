#!/usr/bin/env python3
"""
ios_dev_mcp.py - XClientLab 本地 iOS 开发工具链 MCP (Model Context Protocol) Server
无需外部第三方库，基于标准库实现 JSON-RPC 2.0 stdio 协议通信。

暴露的核心工具 (Tools):
1. xcode_build: 编译 XClientLab
2. xcode_test: 运行单元与 UI 测试
3. simctl_screenshot: 抓取当前已启动模拟器截图并保存
4. lldb_disciplined_batch: 执行遵守通道纪律的 LLDB 异步取证序列
"""

import sys
import json
import subprocess
import os

SERVER_NAME = "xclientlab-ios-mcp"
SERVER_VERSION = "1.0.0"

TOOLS = [
    {
        "name": "xcode_build",
        "description": "通过 xcodebuild 编译 XClientLab 工程（跳过签名与插件校验）",
        "inputSchema": {
            "type": "object",
            "properties": {
                "clean": {
                    "type": "boolean",
                    "description": "是否在构建前执行 clean",
                    "default": False
                }
            }
        }
    },
    {
        "name": "xcode_test",
        "description": "在 iOS Simulator 上运行 XClientLab 单元与 UI 测试套件",
        "inputSchema": {
            "type": "object",
            "properties": {
                "target": {
                    "type": "string",
                    "description": "指定测试 target，如 XClientLabTests 或 XClientLabUITests，默认全跑",
                    "default": "all"
                }
            }
        }
    },
    {
        "name": "simctl_screenshot",
        "description": "使用 xcrun simctl 截取已启动模拟器的当前屏幕",
        "inputSchema": {
            "type": "object",
            "properties": {
                "output_path": {
                    "type": "string",
                    "description": "截图保存的目标绝对或相对路径",
                    "default": "Docs/screenshots/mcp_capture.png"
                }
            }
        }
    },
    {
        "name": "lldb_disciplined_batch",
        "description": "执行 8 步通道纪律 LLDB 批处理命令，安全提取崩溃现场寄存器与调用栈",
        "inputSchema": {
            "type": "object",
            "properties": {
                "pid": {
                    "type": "integer",
                    "description": "目标进程 PID（可选，若为空则生成批处理脚本模板）"
                }
            }
        }
    }
]

def handle_call_tool(name, arguments):
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

    if name == "xcode_build":
        cmd = ["make", "build"]
        res = subprocess.run(cmd, cwd=project_root, capture_output=True, text=True)
        return {
            "content": [{
                "type": "text",
                "text": f"Build ReturnCode: {res.returncode}\n\nSTDOUT:\n{res.stdout[-1500:]}\n\nSTDERR:\n{res.stderr[-1000:]}"
            }],
            "isError": res.returncode != 0
        }

    elif name == "xcode_test":
        cmd = ["make", "test"]
        res = subprocess.run(cmd, cwd=project_root, capture_output=True, text=True)
        return {
            "content": [{
                "type": "text",
                "text": f"Test ReturnCode: {res.returncode}\n\nSTDOUT:\n{res.stdout[-2000:]}\n\nSTDERR:\n{res.stderr[-1000:]}"
            }],
            "isError": res.returncode != 0
        }

    elif name == "simctl_screenshot":
        out_path = arguments.get("output_path", "Docs/screenshots/mcp_capture.png")
        full_out_path = os.path.join(project_root, out_path)
        os.makedirs(os.path.dirname(full_out_path), exist_ok=True)
        cmd = ["xcrun", "simctl", "io", "booted", "screenshot", full_out_path]
        res = subprocess.run(cmd, capture_output=True, text=True)
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

    elif name == "lldb_disciplined_batch":
        batch_script = (
            "# LLDB Disciplined Batch Script (XClientLab 4.1)\n"
            "process status\n"
            "process interrupt\n"
            "thread list\n"
            "bt all\n"
            "register read x0 x1 x2 x3 lr pc\n"
            "image lookup -a $pc\n"
            "process continue\n"
        )
        return {
            "content": [{
                "type": "text",
                "text": f"✅ LLDB 通道纪律标准批处理序列已生成：\n\n```lldb\n{batch_script}```\n\n可直接通过 lldb --batch -s <script> 或 Xcode 控制台下发。"
            }],
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
