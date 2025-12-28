--[[
    Rime AI 纠错 Filter (v1 基础版)
    
    功能：检测触发，发送纠错请求，显示结果
    
    工作流程：
    1. 按 6 触发，发送请求给 Python 服务
    2. 再按 6，显示 AI 返回的纠正结果
--]]

local M = {}

-- 获取 Rime 目录
local function get_rime_dir()
    local sep = package.config:sub(1, 1)
    local info = debug.getinfo(1, "S")
    local script_path = info.source:match("@(.*)") or ""
    local lua_dir = script_path:match("(.*)" .. sep) or "."
    local rime_dir = lua_dir:match("(.*)" .. sep) or "."
    return rime_dir, sep
end

local RIME_DIR, SEP = get_rime_dir()
local TEMP_DIR = RIME_DIR .. SEP .. "ai_temp"

-- 确保临时目录存在
os.execute("mkdir \"" .. TEMP_DIR .. "\" 2>/dev/null")
os.execute("mkdir \"" .. TEMP_DIR .. "\" 2>nul")

-- 文件路径
local REQ_FILE = TEMP_DIR .. SEP .. "rime_ai_request.txt"
local RESP_FILE = TEMP_DIR .. SEP .. "rime_ai_response.txt"
local STATUS_FILE = TEMP_DIR .. SEP .. "rime_ai_status.txt"
local REQID_FILE = TEMP_DIR .. SEP .. "rime_ai_reqid.txt"
local PINYIN_FILE = TEMP_DIR .. SEP .. "rime_ai_pinyin.txt"
local TRIGGER_FLAG = TEMP_DIR .. SEP .. "rime_ai_trigger"

-- 读取文件
local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content and content:gsub("^%s*(.-)%s*$", "%1") or nil
end

-- 写入文件
local function write_file(path, content)
    local f = io.open(path, "w")
    if not f then return false end
    f:write(content)
    f:close()
    return true
end

-- 删除文件
local function delete_file(path)
    os.remove(path)
end

-- 生成请求ID
local function generate_request_id()
    return tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
end

-- 全局状态
local current_request_id = nil
local pending_result = nil
local original_preedit = nil
local waiting = false
local last_trigger = nil

-- 清除任务
local function clear_task()
    waiting = false
    current_request_id = nil
    pending_result = nil
    original_preedit = nil
    write_file(STATUS_FILE, "idle")
end

function M.init(env)
    math.randomseed(os.time())
    clear_task()
    delete_file(TRIGGER_FLAG)
end

-- 检查是否有结果
local function check_for_result()
    if not waiting or not current_request_id then
        return nil
    end
    
    local status = read_file(STATUS_FILE) or "idle"
    
    if status == "done" then
        local resp_reqid = read_file(REQID_FILE)
        if resp_reqid == current_request_id then
            local result = read_file(RESP_FILE)
            write_file(STATUS_FILE, "idle")
            waiting = false
            return result
        end
    end
    
    return nil
end

-- 检查是否有新的触发
local function check_trigger()
    local trigger = read_file(TRIGGER_FLAG)
    if trigger and trigger ~= last_trigger then
        last_trigger = trigger
        delete_file(TRIGGER_FLAG)
        return true
    end
    return false
end

function M.func(input, env)
    local context = env.engine.context
    local preedit = context.input or ""
    
    -- 检查触发
    local is_triggered = check_trigger()
    
    -- preedit 变化时清除任务
    if original_preedit and preedit ~= original_preedit then
        clear_task()
    end
    
    -- 检查结果
    local new_result = check_for_result()
    if new_result then
        pending_result = new_result
    end
    
    -- 收集候选词
    local candidates = {}
    local selected_cand = nil
    
    local composition = context.composition
    local selected_index = 0
    if composition and not composition:empty() then
        local seg = composition:back()
        if seg then
            selected_index = seg.selected_index or 0
        end
    end
    
    local index = 0
    for cand in input:iter() do
        table.insert(candidates, cand)
        if index == selected_index then
            selected_cand = cand
        end
        index = index + 1
    end
    
    if #candidates == 0 then
        return
    end
    
    if not selected_cand then
        selected_cand = candidates[1]
    end
    
    -- 触发处理
    if is_triggered and selected_cand then
        if pending_result and #pending_result > 0 then
            -- 已有结果，显示它
            local seg_start = candidates[1].start
            local seg_end = candidates[1]._end
            
            local result_cand = Candidate("ai", seg_start, seg_end, pending_result, "「AI」")
            result_cand.quality = 10000
            yield(result_cand)
            
            pending_result = nil
        elseif not waiting then
            -- 发送新请求
            original_preedit = preedit
            current_request_id = generate_request_id()
            waiting = true
            
            local full_pinyin = selected_cand.preedit or selected_cand.comment or preedit
            
            write_file(REQID_FILE, current_request_id)
            write_file(REQ_FILE, selected_cand.text)
            write_file(PINYIN_FILE, full_pinyin)
            write_file(STATUS_FILE, "req")
            
            -- 显示加载提示
            local seg_start = candidates[1].start
            local seg_end = candidates[1]._end
            local loading_cand = Candidate("ai", seg_start, seg_end, "AI纠正中...", "")
            loading_cand.quality = 10000
            yield(loading_cand)
        else
            -- 继续等待
            local seg_start = candidates[1].start
            local seg_end = candidates[1]._end
            local loading_cand = Candidate("ai", seg_start, seg_end, "AI纠正中...", "")
            loading_cand.quality = 10000
            yield(loading_cand)
        end
    end
    
    -- 输出原始候选词
    for _, cand in ipairs(candidates) do
        yield(cand)
    end
end

function M.fini(env)
    clear_task()
end

return M
