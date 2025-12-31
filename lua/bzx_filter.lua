--[[
    bzx_filter.lua - Rime AI 多功能 Filter (重构版)
    
    职责：
    - 读取全局状态 (_G.bzx_state)
    - 显示加载提示或 AI 结果
    
    注意：所有通信和状态管理由 Processor 负责
--]]

local M = {}

-- 加载提示文本（备用，正常从状态读取）
local LOADING_TEXTS = {
    correct = "AI纠正中...",
    translate = "AI翻译中...",
    chat = "AI生成中...",
}

function M.init(env)
    -- 无需初始化
end

function M.func(input, env)
    -- 收集原始候选词
    local candidates = {}
    for cand in input:iter() do
        table.insert(candidates, cand)
    end
    
    if #candidates == 0 then
        return
    end
    
    local seg_start = candidates[1].start
    local seg_end = candidates[1]._end
    
    -- 检查全局状态
    local state = _G.bzx_state
    if state and state.timestamp and state.timestamp > (state.last_processed or 0) then
        
        if state.trigger_type == "show_result" and state.result then
            -- 显示 AI 结果
            local result_cand = Candidate("ai", seg_start, seg_end, state.result, "「AI」")
            result_cand.quality = 10000
            yield(result_cand)
            state.last_processed = state.timestamp
            -- 清除状态
            state.trigger_type = nil
            state.result = nil
            
        elseif state.trigger_type == "loading" and state.loading_text then
            -- 显示加载提示
            local loading_cand = Candidate("ai", seg_start, seg_end, state.loading_text, "")
            loading_cand.quality = 10000
            yield(loading_cand)
            state.last_processed = state.timestamp
        end
    end
    
    -- 输出原始候选词
    for _, cand in ipairs(candidates) do
        yield(cand)
    end
end

function M.fini(env)
    -- 无需清理
end

return M
