#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
bzx_ai.py - AI 请求模块

统一使用 OpenAI 兼容接口调用各类 AI 服务。
支持 DeepSeek、OpenAI、Ollama 等任何 OpenAI 兼容的 API。

使用示例:
    from bzx_ai import AIClient
    
    client = AIClient(
        api_url="https://api.deepseek.com/v1/chat/completions",
        api_key="sk-xxx",
        model="deepseek-chat"
    )
    
    result = client.chat("你是翻译专家", "翻译：Hello World")
"""

from typing import Optional, Dict, Any, List
import requests


class AIClient:
    """OpenAI 兼容接口客户端"""
    
    def __init__(
        self,
        api_url: str,
        api_key: str = "",
        model: str = "gpt-3.5-turbo",
        temperature: float = 0.1,
        max_tokens: int = 512,
        top_p: float = 1.0,
        timeout: int = 30
    ):
        """
        初始化 AI 客户端
        
        Args:
            api_url: API 端点 URL
            api_key: API 密钥（Ollama 等本地服务可为空）
            model: 模型名称
            temperature: 温度参数
            max_tokens: 最大 token 数
            top_p: top_p 参数
            timeout: 请求超时时间（秒）
        """
        self.api_url = api_url
        self.api_key = api_key
        self.model = model
        self.temperature = temperature
        self.max_tokens = max_tokens
        self.top_p = top_p
        self.timeout = timeout
    
    def chat(
        self,
        system_prompt: str,
        user_message: str,
        messages: Optional[List[Dict[str, str]]] = None
    ) -> Optional[str]:
        """
        发送聊天请求
        
        Args:
            system_prompt: 系统提示词
            user_message: 用户消息
            messages: 可选的额外消息列表（用于上下文）
        
        Returns:
            AI 响应文本，失败返回 None
        """
        # 构建消息列表
        all_messages = [{"role": "system", "content": system_prompt}]
        
        if messages:
            all_messages.extend(messages)
        
        all_messages.append({"role": "user", "content": user_message})
        
        # 构建请求头
        headers = {"Content-Type": "application/json"}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
        
        # 构建请求体
        payload = {
            "model": self.model,
            "messages": all_messages,
            "temperature": self.temperature,
            "max_tokens": self.max_tokens,
            "top_p": self.top_p
        }
        
        try:
            response = requests.post(
                self.api_url,
                headers=headers,
                json=payload,
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                data = response.json()
                # 兼容 OpenAI 和 Ollama 格式
                if "choices" in data:
                    return data["choices"][0]["message"]["content"].strip()
                elif "message" in data:
                    return data["message"]["content"].strip()
            else:
                print(f"[AIClient] API 错误: {response.status_code} - {response.text[:200]}")
                
        except requests.exceptions.Timeout:
            print(f"[AIClient] 请求超时 ({self.timeout}s)")
        except requests.exceptions.RequestException as e:
            print(f"[AIClient] 请求失败: {e}")
        except (KeyError, IndexError, ValueError) as e:
            print(f"[AIClient] 响应解析失败: {e}")
        
        return None
    
    @classmethod
    def from_config(cls, config: Dict[str, Any]) -> "AIClient":
        """
        从配置字典创建客户端
        
        Args:
            config: 配置字典，包含 api_url, api_key, model, model_params 等
        
        Returns:
            AIClient 实例
        """
        model_params = config.get("model_params", {})
        
        return cls(
            api_url=config.get("api_url", ""),
            api_key=config.get("api_key", ""),
            model=config.get("model", "gpt-3.5-turbo"),
            temperature=model_params.get("temperature", 0.1),
            max_tokens=model_params.get("max_tokens", 512),
            top_p=model_params.get("top_p", 1.0),
            timeout=model_params.get("timeout", 30)
        )


# =============================================================================
# 测试代码
# =============================================================================
if __name__ == "__main__":
    import os
    import json
    
    # 从配置文件加载
    script_dir = os.path.dirname(os.path.abspath(__file__))
    config_path = os.path.join(script_dir, "bzx_config.json")
    
    if os.path.exists(config_path):
        with open(config_path, "r", encoding="utf-8") as f:
            config = json.load(f)
        client = AIClient.from_config(config)
        print(f"已加载配置: {config_path}")
    else:
        print(f"配置文件不存在: {config_path}")
        print("请创建 bzx_config.json 并设置 api_key")
        exit(1)
    
    result = client.chat(
        system_prompt="你是翻译专家，只返回翻译结果",
        user_message="翻译成英文：你好世界"
    )
    
    print(f"结果: {result}")
