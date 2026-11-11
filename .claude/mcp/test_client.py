#!/usr/bin/env python3
"""
mcp/test_client.py - XClientLab 本地 MCP Server 自测客户端
用于快速自测与验证 mcp/server.py 的 JSON-RPC 2.0 通信与 tools 响应。
运行方式: python3 mcp/test_client.py
"""

import subprocess
import json
import os
import sys

def run_test():
    server_path = os.path.join(os.path.dirname(__file__), "server.py")
    proc = subprocess.Popen(
        [sys.executable, server_path],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    def send_rpc(msg):
        proc.stdin.write(json.dumps(msg) + "\n")
        proc.stdin.flush()
        line = proc.stdout.readline()
        return json.loads(line) if line else None

    print("🚀 [1/3] Testing 'initialize'...")
    init_res = send_rpc({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {}
    })
    assert init_res and "result" in init_res, f"Init failed: {init_res}"
    print(f"✅ Server initialized: {init_res['result']['serverInfo']['name']} v{init_res['result']['serverInfo']['version']}")

    print("🚀 [2/3] Testing 'tools/list'...")
    list_res = send_rpc({
        "jsonrpc": "2.0",
        "id": 2,
        "method": "tools/list",
        "params": {}
    })
    tools = list_res["result"]["tools"]
    tool_names = [t["name"] for t in tools]
    print(f"✅ Tools registered ({len(tools)}): {', '.join(tool_names)}")

    print("🚀 [3/3] Testing 'lldb_disciplined_batch' tool execution...")
    call_res = send_rpc({
        "jsonrpc": "2.0",
        "id": 3,
        "method": "tools/call",
        "params": {
            "name": "lldb_disciplined_batch",
            "arguments": {}
        }
    })
    assert not call_res["result"]["isError"], f"Tool call error: {call_res}"
    print("✅ LLDB Disciplined Batch output successfully received!")

    proc.terminate()
    print("\n🎉 ALL MCP SERVER SELF-TESTS PASSED!")

if __name__ == "__main__":
    run_test()
