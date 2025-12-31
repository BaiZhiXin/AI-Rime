--[[
    bzx_state.lua - 全局状态共享模块
    
    供 Processor 和 Filter 共享状态，避免通过文件通信
    Processor 负责更新状态，Filter 只读取状态
--]]

-- 初始化全局状态（如果尚未初始化）
if not _G.bzx_state then
    _G.bzx_state = {
        -- 触发类型: "loading" | "show_result" | nil
        trigger_type = nil,
        
        -- 功能类型: "correct" | "translate" | "chat"
        func_type = nil,
        
        -- 加载提示文本
        loading_text = nil,
        
        -- AI 返回结果
        result = nil,
        
        -- 状态更新时间戳（用于避免重复处理）
        timestamp = 0,
        
        -- 最后处理的时间戳（Filter 记录）
        last_processed = 0,
    }
end

local M = {}

-- 加载提示文本
M.LOADING_TEXTS = {
    correct = "AI纠正中...",
    translate = "AI翻译中...",
    chat = "AI生成中...",
}

-- 设置加载状态
function M.set_loading(func_type)
    _G.bzx_state.trigger_type = "loading"
    _G.bzx_state.func_type = func_type
    _G.bzx_state.loading_text = M.LOADING_TEXTS[func_type] or "处理中..."
    _G.bzx_state.result = nil
    _G.bzx_state.timestamp = os.time() * 1000 + math.random(1000)
end

-- 设置结果状态
function M.set_result(result)
    _G.bzx_state.trigger_type = "show_result"
    _G.bzx_state.result = result
    _G.bzx_state.timestamp = os.time() * 1000 + math.random(1000)
end

-- 清除状态
function M.clear()
    _G.bzx_state.trigger_type = nil
    _G.bzx_state.func_type = nil
    _G.bzx_state.loading_text = nil
    _G.bzx_state.result = nil
end

-- 获取当前状态（Filter 使用）
function M.get_state()
    return _G.bzx_state
end

-- 检查是否有新的状态需要处理
function M.has_new_state()
    return _G.bzx_state.timestamp > _G.bzx_state.last_processed
end

-- 标记状态已处理
function M.mark_processed()
    _G.bzx_state.last_processed = _G.bzx_state.timestamp
end

return M
