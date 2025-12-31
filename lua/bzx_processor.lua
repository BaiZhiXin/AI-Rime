--[[
    bzx_processor.lua - Rime AI 多功能 Processor (重构版)
    
    功能：
    - 监听功能键触发不同 AI 功能 (6=纠错, 7=翻译, 8=对话, 0=显示结果)
    - 通过管道与 Python 服务通信
    - 更新全局状态供 Filter 读取
    - 记录上屏文字作为上下文
--]]

local M = {}


-- ============================================================
-- 【用户配置区】可修改以下设置
-- ============================================================

-- 功能键配置（按键 -> 功能类型）
local KEY_BINDINGS = {
    ["6"] = "correct",    -- 按 6 触发纠错
    ["7"] = "translate",  -- 按 7 触发翻译
    ["8"] = "chat",       -- 按 8 触发对话
    ["0"] = "show_result", -- 按 0 显示结果
}

-- 加载提示文本
local LOADING_TEXTS = {
    correct = "AI纠正中...",
    translate = "AI翻译中...",
    chat = "AI生成中...",
}

-- 管道名称（与 Python 服务保持一致）
local PIPE_NAME = "bzx_rime"

-- ============================================================
-- 以下为核心代码
-- ============================================================

-- Rime 目录（在 init 中从 env.user_data_dir 获取）
local RIME_DIR = nil
local SEP = package.config:sub(1, 1)

-- 使用系统临时目录
local function get_temp_dir()
    local sep = package.config:sub(1, 1)
    if sep == "\\" then
        -- Windows: 使用 %TEMP%
        return os.getenv("TEMP") or os.getenv("TMP") or "C:\\Temp"
    else
        -- Unix: 使用 /tmp
        return "/tmp"
    end
end

local TEMP_DIR = get_temp_dir()

-- 调试日志
local DEBUG = true  -- 临时开启调试
local log_file = TEMP_DIR .. SEP .. "bzx_processor_debug.log"
local MAX_LOG_SIZE = 1024 * 1024

local function log(msg)
    if not DEBUG then return end
    
    local f = io.open(log_file, "r")
    if f then
        local size = f:seek("end")
        f:close()
        if size and size > MAX_LOG_SIZE then
            os.remove(log_file)
        end
    end
    
    f = io.open(log_file, "a")
    if f then
        f:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. tostring(msg) .. "\n")
        f:close()
    end
end

-- ============================================================
-- 全局状态（包含上下文队列）
-- ============================================================

-- 上下文队列配置
local CONTEXT_QUEUE_SIZE = 10  -- 最多保留 10 个词

if not _G.bzx_state then
    _G.bzx_state = {
        trigger_type = nil,
        func_type = nil,
        loading_text = nil,
        result = nil,
        timestamp = 0,
        last_processed = 0,
        -- 上下文队列 (FIFO)
        context_queue = {},
    }
end

-- 添加词到上下文队列
local function push_context(text)
    if not text or text == "" then return end
    
    local queue = _G.bzx_state.context_queue
    table.insert(queue, text)
    
    -- 保持队列不超过最大大小 (FIFO)
    while #queue > CONTEXT_QUEUE_SIZE do
        table.remove(queue, 1)
    end
    
    log("上下文队列更新: " .. table.concat(queue, " | "))
end

-- 获取上下文字符串（直接连接，Python 端分词）
local function get_context_string()
    local queue = _G.bzx_state.context_queue
    if #queue == 0 then return "" end
    return table.concat(queue, "")  -- 不加空格，Python 用 jieba 分词
end

local function state_set_loading(func_type)
    _G.bzx_state.trigger_type = "loading"
    _G.bzx_state.func_type = func_type
    _G.bzx_state.loading_text = LOADING_TEXTS[func_type] or "处理中..."
    _G.bzx_state.result = nil
    _G.bzx_state.timestamp = os.time() * 1000 + math.random(1000)
end

local function state_set_result(result)
    _G.bzx_state.trigger_type = "show_result"
    _G.bzx_state.result = result
    _G.bzx_state.timestamp = os.time() * 1000 + math.random(1000)
end

-- ============================================================
-- 管道通信（安全加载）
-- ============================================================

local bzx_pipe = nil
local pipe_load_attempted = false

local function try_load_pipe()
    if pipe_load_attempted then return bzx_pipe end
    pipe_load_attempted = true
    
    local ok, mod = pcall(require, "bzx_ipc")
    if ok then
        bzx_pipe = mod
        log("成功加载 bzx_ipc 模块")
    else
        log("加载 bzx_ipc 失败: " .. tostring(mod))
    end
    return bzx_pipe
end

local pipe = nil

local function get_pipe()
    if not pipe then
        local mod = try_load_pipe()
        if mod then
            pipe = mod.new(PIPE_NAME)
        end
    end
    return pipe
end

-- UTF-8 安全截断
local function utf8_safe_sub_tail(str, max_bytes)
    if not str or #str <= max_bytes then
        return str
    end
    
    local start_pos = #str - max_bytes + 1
    local result = string.sub(str, start_pos)
    
    local i = 1
    while i <= #result do
        local byte = string.byte(result, i)
        if bit.band(byte, 0xC0) == 0x80 then
            i = i + 1
        else
            break
        end
    end
    
    if i > 1 then
        result = string.sub(result, i)
    end
    
    return result
end

-- 文件操作
local function write_file(path, content)
    local f = io.open(path, "w")
    if not f then return false end
    f:write(content)
    f:close()
    return true
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content and content:gsub("^%s*(.-)%s*$", "%1") or nil
end


-- 发送请求到 Python 服务
local function send_request(func_type, text, pinyin, context)
    local p = get_pipe()
    if not p then
        log("IPC 模块未初始化")
        return false
    end
    
    -- 检测服务是否运行
    if not p:exists() then
        log("Python 服务未启动，跳过请求")
        return false
    end
    
    -- 构建 JSON 请求
    local reqid = tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
    local request = string.format(
        '{"type":"%s","text":"%s","pinyin":"%s","context":"%s","reqid":"%s"}',
        func_type,
        (text or ""):gsub('"', '\\"'):gsub("\n", "\\n"),
        (pinyin or ""):gsub('"', '\\"'),
        (context or ""):gsub('"', '\\"'):gsub("\n", "\\n"),
        reqid
    )
    
    log("发送请求: " .. request)
    return p:send(request)
end

-- 读取响应
local function read_response()
    local p = get_pipe()
    if not p then return nil end
    
    -- 检测服务是否运行
    if not p:exists() then
        log("Python 服务未启动，跳过读取")
        return nil
    end
    
    local data = p:read()
    
    if data then
        log("收到响应: " .. data)
        
        -- 提取 result 字段
        local result = data:match('"result"%s*:%s*"([^"]*)"')
        if result then
            -- 处理转义字符
            result = result:gsub("\\n", "\n"):gsub('\\"', '"')
            return result
        end
    end
    
    return nil
end

function M.init(env)
    -- 从 env 获取 Rime 用户目录
    RIME_DIR = env.user_data_dir
    
    log("========== Processor init ==========") 
    log("RIME_DIR: " .. tostring(RIME_DIR))
    log("TEMP_DIR: " .. TEMP_DIR)

    -- 预加载 IPC 模块
    try_load_pipe()
end

function M.func(key, env)
    local engine = env.engine
    local context = engine.context
    
    -- 只处理按下事件
    if key:release() then
        return 2  -- kNoop
    end
    
    -- 只在有候选菜单时处理功能键
    if not context:has_menu() then
        return 2  -- kNoop
    end
    
    local key_repr = key:repr()
    log("按键: " .. key_repr)
    
    local func_type = KEY_BINDINGS[key_repr]
    
    if func_type then
        log("检测到功能键: " .. key_repr .. " -> " .. func_type)
        
        if func_type == "show_result" then
            -- 按 0：读取管道获取 AI 结果
            local response = read_response()
            if response then
                log("收到 AI 响应: " .. response)
                state_set_result(response)
            elseif _G.bzx_state.result then
                -- 如果管道无新数据，使用已有的结果
                state_set_result(_G.bzx_state.result)
            end
            context:refresh_non_confirmed_composition()
            return 1  -- kAccepted
        end
        
        -- 按 6/7/8：获取候选词并发送请求
        local selected_cand = nil
        local preedit = context.input or ""
        
        if context.get_selected_candidate then
            selected_cand = context:get_selected_candidate()
        end
        
        if selected_cand then
            local full_pinyin = selected_cand.preedit or selected_cand.comment or preedit
            local ctx = get_context_string()  -- 从内存队列获取上下文
            
            -- 设置加载状态
            state_set_loading(func_type)
            log("设置加载状态: " .. func_type)
            
            -- 发送请求
            local success = send_request(func_type, selected_cand.text, full_pinyin, ctx)
            
            if success then
                log("请求已发送: " .. selected_cand.text)
            else
                log("请求发送失败")
            end
            
            context:refresh_non_confirmed_composition()
            return 1  -- kAccepted
        else
            log("未能获取候选词")
        end
    end
    
    -- 监听候选词选择（记录上屏文字）
    local select_keys = {
        ["1"] = 0, ["2"] = 1, ["3"] = 2, ["4"] = 3, ["5"] = 4,
        ["space"] = -1, ["Return"] = -1,
    }
    
    local select_index = select_keys[key_repr]
    if select_index then
        local seg = context.composition:back()
        if seg and seg.menu then
            local cand = nil
            if select_index == -1 then
                cand = seg:get_selected_candidate()
            else
                cand = seg:get_candidate_at(select_index)
            end
            
            if cand then
                log("记录上屏文字: " .. cand.text)
                push_context(cand.text)  -- 使用内存队列
            end
        end
    end
    
    return 2  -- kNoop
end

function M.fini(env)
    log("========== Processor fini ==========")
    if pipe then
        pipe:close()
        pipe = nil
    end
end

return M
