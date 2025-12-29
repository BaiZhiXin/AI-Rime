--[[
    Rime AI 纠错 Processor (v2 可配置版)
    
    功能：监听功能键触发纠错
    - 按 6 触发纠错
    - 按 0 显示结果（或 Python 自动发送）
--]]

local M = {}

-- ============================================================
-- 【用户配置区】可修改以下设置
-- ============================================================

-- 功能键配置
local KEY_CORRECT = "6"      -- 触发纠错
local KEY_SHOW_RESULT = "0"  -- 显示结果

-- ============================================================
-- 以下为核心代码，一般无需修改
-- ============================================================

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
local TRIGGER_FLAG = TEMP_DIR .. SEP .. "rime_ai_trigger"
local TYPE_FILE = TEMP_DIR .. SEP .. "rime_ai_type.txt"
local LOADING_FILE = TEMP_DIR .. SEP .. "rime_ai_loading.txt"

-- 写入文件
local function write_file(path, content)
    local f = io.open(path, "w")
    if not f then return false end
    f:write(content)
    f:close()
    return true
end

function M.init(env)
    -- 初始化
end

function M.func(key, env)
    local engine = env.engine
    local context = engine.context
    
    -- 只处理按下事件
    if key:release() then
        return 2  -- kNoop
    end
    
    local key_repr = key:repr()
    
    if not context:has_menu() then
        return 2  -- kNoop
    end
    
    -- 纠错触发
    if key_repr == KEY_CORRECT then
        write_file(TYPE_FILE, "correct")
        write_file(LOADING_FILE, "AI纠正中...")
        write_file(TRIGGER_FLAG, tostring(os.time()) .. "_correct")
        context:refresh_non_confirmed_composition()
        return 1  -- kAccepted
    end
    
    -- 显示结果
    if key_repr == KEY_SHOW_RESULT then
        write_file(TYPE_FILE, "show_result")
        write_file(TRIGGER_FLAG, tostring(os.time()) .. "_show")
        context:refresh_non_confirmed_composition()
        return 1  -- kAccepted
    end
    
    return 2  -- kNoop
end

function M.fini(env)
    -- 清理
end

return M
