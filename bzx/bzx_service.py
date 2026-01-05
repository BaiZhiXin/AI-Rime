#!/usr/bin/env python3
"""
bzx_service.py - Rime AI 多功能后台服务

通过临时文件与 Rime Lua 通信，处理纠错、翻译、对话请求。

使用方法：
    python bzx_service.py [--config PATH]
"""

import os
import sys
import json
import signal
import logging
from logging.handlers import RotatingFileHandler
from typing import Dict, Any
import argparse

# 获取脚本所在目录
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# 导入 IPC 模块
try:
    from bzx_ipc import create_ipc_server
except ImportError:
    sys.path.insert(0, SCRIPT_DIR)
    from bzx_ipc import create_ipc_server

# 导入 AI 模块
from bzx_ai import AIClient

# 尝试导入 jieba
try:
    import jieba
    jieba.setLogLevel(jieba.logging.WARNING)
    JIEBA_AVAILABLE = True
except ImportError:
    JIEBA_AVAILABLE = False


# ============ 日志配置 ============

def setup_logging(debug: bool = False) -> logging.Logger:
    """配置日志（带轮转）"""
    logger = logging.getLogger("bzx_service")
    logger.setLevel(logging.DEBUG if debug else logging.INFO)
    
    # 日志文件在脚本目录
    log_file = os.path.join(SCRIPT_DIR, "bzx_service.log")
    
    # 轮转：最大 1MB，保留 3 个备份
    handler = RotatingFileHandler(
        log_file, 
        maxBytes=1024 * 1024,  # 1MB
        backupCount=3,
        encoding="utf-8"
    )
    handler.setFormatter(logging.Formatter(
        "%(asctime)s - %(levelname)s - %(message)s"
    ))
    logger.addHandler(handler)
    
    # 同时输出到控制台
    console = logging.StreamHandler()
    console.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(console)
    
    return logger


# ============ 默认配置 ============

DEFAULT_CONFIG = {
    "api_url": "https://api.deepseek.com/v1/chat/completions",
    "api_key": "sk-",
    "model": "deepseek-chat",
    "context_aware": False,
    "debug": False,
    "model_params": {
        "temperature": 0.1,
        "max_tokens": 512,
        "top_p": 1.0,
        "timeout": 30
    },
    "system_prompts": {
        "correct": "{\"role\":\"逆向拼音纠错专家\",\"protocol\":\"仅输出修正后汉字,严禁解释多言,长度严格守恒\",\"logic\":\"1.声学还原:兼容平翘舌、前后鼻音、fh模糊音;2.意境采样:文学语境(含山/巅/长风/明月/负/至)史诗感优先,即便原句通顺,若同音字张力更强(如负变扶)则强制替换；如果有上下文内容的话**必须**参考上下文内容的名词进行纠正，例如女性->她，男性->他。\",\"output\":\"直接输出修正后的文本\"}",
        "translate": "你是翻译专家。用户会给你一段文本，中文翻译成英文，英文翻译成中文。\n\n【输出要求】\n- 只输出翻译结果\n- 禁止任何解释或说明",
        "chat": "你是内容生成助手。根据用户的需求生成内容。\n\n【输出要求】\n- 只输出生成的内容\n- 禁止任何解释或前缀\n- 严禁附带markdown语法的符号表示\n- 所有回答应当尽可能简洁高效\n- 对于命令的询问应当给出一条命令"
    }
}

IPC_NAME = "bzx_rime"


# ============ 配置加载 ============

def load_config(config_path: str = None) -> Dict[str, Any]:
    """加载配置文件"""
    # 搜索路径：命令行指定 > 当前目录
    search_paths = []
    if config_path:
        search_paths.append(config_path)
    search_paths.append(os.path.join(SCRIPT_DIR, "bzx_config.json"))
    
    for path in search_paths:
        if os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8") as f:
                    config = json.load(f)
                    print(f"已加载配置: {path}")
                    merged = DEFAULT_CONFIG.copy()
                    merged.update(config)
                    if "system_prompts" in config:
                        merged["system_prompts"] = {**DEFAULT_CONFIG["system_prompts"], **config["system_prompts"]}
                    return merged
            except Exception as e:
                print(f"配置文件读取失败 {path}: {e}")
    
    print("警告: 未找到配置文件，使用默认配置")
    return DEFAULT_CONFIG.copy()


# ============ 请求处理 ============

class RequestHandler:
    """处理来自 Lua 的请求"""
    
    def __init__(self, config: Dict[str, Any], logger: logging.Logger):
        self.config = config
        self.logger = logger
        self.system_prompts = config.get("system_prompts", {})
        self.context_enabled = config.get("context_aware", False)
        self.ai_client = AIClient.from_config(config)
    
    def handle(self, request_json: str) -> str:
        """处理请求并返回 JSON 响应"""
        try:
            req = json.loads(request_json)
        except json.JSONDecodeError as e:
            self.logger.error(f"JSON 解析失败: {e}")
            return json.dumps({"error": f"Invalid JSON: {e}", "result": None})
        
        req_type = req.get("type", "correct")
        text = req.get("text", "")
        pinyin = req.get("pinyin", "")
        context = req.get("context", "")
        reqid = req.get("reqid", "")
        
        func_name = {"correct": "纠错", "translate": "翻译", "chat": "对话"}.get(req_type, req_type)
        self.logger.info(f"[{func_name}] 收到请求: {text[:50]}{'...' if len(text) > 50 else ''}")
        
        # 获取系统提示词
        system_prompt = self.system_prompts.get(req_type, "")
        
        # 构建用户消息
        user_text = text
        context_messages = []  # 额外的消息列表
        
        if req_type == "correct":
            if pinyin:
                user_text = f"拼音：{pinyin}\n待纠正：{text}"
                self.logger.debug(f"  拼音: {pinyin}")
            
            if self.context_enabled and context:
                # 使用 jieba 分词
                if JIEBA_AVAILABLE:
                    tokens = list(jieba.cut(context))
                    tokens = [t.strip() for t in tokens if t.strip()]
                else:
                    tokens = list(context)
                
                context_tokens = " ".join(tokens)
                self.logger.info(f"  上下文: {context_tokens}")
                
                # 通过 assistant 消息传递上下文
                context_messages = [
                    {"role": "assistant", "content": f"用户历史输入：{context_tokens}"}
                ]
        
        # 调用 AI（传递上下文消息）
        result = self.ai_client.chat(system_prompt, user_text, context_messages if context_messages else None)
        
        if result:
            self.logger.info(f"[{func_name}] 结果: {result[:50]}{'...' if len(result) > 50 else ''}")
        else:
            self.logger.warning(f"[{func_name}] 处理失败，返回原文")
            result = text
        
        return json.dumps({
            "reqid": reqid,
            "result": result,
            "error": None
        }, ensure_ascii=False)


# ============ 主服务 ============

class BzxService:
    """IPC 通信服务"""
    
    def __init__(self, config: Dict[str, Any], logger: logging.Logger):
        self.config = config
        self.logger = logger
        self.handler = RequestHandler(config, logger)
        self.server = None
    
    def start(self):
        """启动服务"""
        self.logger.info("=" * 50)
        self.logger.info("Rime AI 服务已启动")
        self.logger.info("=" * 50)
        self.logger.info(f"  API: {self.config.get('api_url', 'N/A')}")
        self.logger.info(f"  模型: {self.config.get('model', 'N/A')}")
        self.logger.info(f"  IPC: {IPC_NAME}")
        self.logger.info(f"  上下文: {'开启' if self.config.get('context_aware') else '关闭'}")
        self.logger.info("=" * 50)
        self.logger.info("按 Ctrl+C 停止服务...")
        
        self.server = create_ipc_server(IPC_NAME)
        
        try:
            self.server.run(self.handler.handle)
        except KeyboardInterrupt:
            pass
        finally:
            self.stop()
    
    def stop(self):
        """停止服务"""
        if self.server:
            self.server.stop()
            self.server.cleanup()
        self.logger.info("服务已停止")


# ============ 主函数 ============

def main():
    parser = argparse.ArgumentParser(description="Rime AI 服务")
    parser.add_argument("--config", "-c", type=str, help="配置文件路径")
    parser.add_argument("--debug", "-d", action="store_true", help="开启调试模式")
    args = parser.parse_args()
    
    config = load_config(args.config)
    
    # 命令行 debug 优先
    if args.debug:
        config["debug"] = True
    
    logger = setup_logging(config.get("debug", False))
    
    if not config.get("api_key"):
        logger.warning("=" * 50)
        logger.warning("警告: 现已使用博主bzx的api_key")
        logger.warning("有能力者请编辑配置文件改用自己的api_key！")
        logger.warning("=" * 50)
    
    service = BzxService(config, logger)
    
    def signal_handler(sig, frame):
        service.stop()
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    service.start()


if __name__ == "__main__":
    main()
