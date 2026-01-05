#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
bzx_ipc.py - 跨平台 IPC 通信模块 (文件版)

所有平台都使用临时文件进行通信：
- Unix: /tmp 目录
- Windows: %TEMP% 目录

通信协议：
- 请求文件 (_req.txt): Lua 写入请求，Python 读取并清空
- 响应文件 (_resp.txt): Python 写入响应，Lua 读取
"""

import os
import sys
import time
import atexit
import platform
from typing import Callable, Optional

DEFAULT_IPC_NAME = "bzx_rime"


def get_temp_dir() -> str:
    """获取临时目录"""
    if platform.system() == "Windows":
        return os.environ.get("TEMP") or os.environ.get("TMP") or "C:\\Temp"
    else:
        return "/tmp"


class FileIPCServer:
    """文件 IPC 服务器（跨平台）"""
    
    def __init__(self, name: str = DEFAULT_IPC_NAME):
        self.name = name
        self.running = False
        
        temp_dir = get_temp_dir()
        self.req_file = os.path.join(temp_dir, f"{name}_req.txt")
        self.resp_file = os.path.join(temp_dir, f"{name}_resp.txt")
        self._last_mtime = 0
        
        # 注册退出时清理
        atexit.register(self.cleanup)
    
    def _ensure_files(self) -> None:
        """确保通信文件存在"""
        for file_path in (self.req_file, self.resp_file):
            # 先删除旧文件
            if os.path.exists(file_path):
                try:
                    os.remove(file_path)
                except:
                    pass
            # 创建空文件
            with open(file_path, 'w', encoding='utf-8') as f:
                pass
            print(f"[IPC] 创建文件: {file_path}")
    
    def _read_request(self) -> Optional[str]:
        """读取请求（非阻塞），有内容则返回并清空文件"""
        try:
            # 检查文件修改时间，避免频繁读取
            if not os.path.exists(self.req_file):
                return None
            mtime = os.path.getmtime(self.req_file)
            if mtime <= self._last_mtime:
                return None
            self._last_mtime = mtime
            
            with open(self.req_file, 'r', encoding='utf-8') as f:
                content = f.read().strip()
            
            if content:
                # 清空请求文件
                with open(self.req_file, 'w', encoding='utf-8') as f:
                    pass
                return content
        except Exception as e:
            pass
        return None
    
    def _write_response(self, response: str) -> None:
        """写入响应"""
        try:
            # 将换行符转义以便 Lua 解析
            data = response.replace('\n', '\\n')
            with open(self.resp_file, 'w', encoding='utf-8') as f:
                f.write(data)
            print(f"[IPC] 已写入响应: {response[:50]}...")
        except Exception as e:
            print(f"[IPC] 写入响应失败: {e}")
    
    def run(self, handler: Callable[[str], str]) -> None:
        """运行服务器（轮询模式）"""
        self._ensure_files()
        
        print(f"[IPC] 文件 IPC 服务器启动")
        print(f"[IPC]   请求文件: {self.req_file}")
        print(f"[IPC]   响应文件: {self.resp_file}")
        self.running = True
        
        while self.running:
            try:
                request = self._read_request()
                if request:
                    print(f"[IPC] 收到请求: {request[:80]}...")
                    response = handler(request)
                    self._write_response(response)
                    
                    # 模拟按键 0 通知 Rime
                    self._simulate_key_0()
                else:
                    # 无请求时短暂休眠，避免 CPU 空转
                    time.sleep(0.05)
            except KeyboardInterrupt:
                print("[IPC] 收到中断信号")
                break
            except Exception as e:
                print(f"[IPC] 错误: {e}")
                time.sleep(0.1)
    
    def _simulate_key_0(self):
        """模拟按键 0 通知 Rime"""
        if platform.system() == "Windows":
            try:
                import ctypes
                user32 = ctypes.windll.user32
                VK_0 = 0x30
                KEYEVENTF_KEYUP = 0x0002
                user32.keybd_event(VK_0, 0, 0, 0)
                user32.keybd_event(VK_0, 0, KEYEVENTF_KEYUP, 0)
                print("[IPC] 已发送模拟按键 0")
            except Exception as e:
                print(f"[IPC] 模拟按键失败: {e}")
        else:
            # macOS/Linux: 使用 osascript 或 xdotool
            try:
                if platform.system() == "Darwin":
                    os.system('osascript -e \'tell application "System Events" to keystroke "0"\'')
                else:
                    os.system('xdotool key 0')
                print("[IPC] 已发送模拟按键 0")
            except Exception as e:
                print(f"[IPC] 模拟按键失败: {e}")
    
    def stop(self) -> None:
        """停止服务器"""
        self.running = False
    
    def cleanup(self) -> None:
        """清理通信文件"""
        for file_path in (self.req_file, self.resp_file):
            if os.path.exists(file_path):
                try:
                    os.remove(file_path)
                    print(f"[IPC] 已删除: {file_path}")
                except Exception as e:
                    print(f"[IPC] 删除失败 {file_path}: {e}")


def create_ipc_server(name: str = DEFAULT_IPC_NAME) -> FileIPCServer:
    """创建 IPC 服务器"""
    return FileIPCServer(name)


# 兼容旧接口
IPCServer = create_ipc_server
create_pipe_server = create_ipc_server


if __name__ == "__main__":
    def demo_handler(text: str) -> str:
        return f"{text}（已处理）"
    
    print("=" * 50)
    print("IPC 通信测试服务器")
    print("=" * 50)
    
    server = create_ipc_server()
    server.run(demo_handler)
