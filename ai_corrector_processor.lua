--[[
    Rime AI 纠错 Processor (v1 基础版)
    
    功能：监听按键 6 触发纠错和显示结果
    
    使用方法：
    1. 输入拼音，候选词出现
    2. 按 6 触发 AI 纠错
    3. 再按 6 显示纠错结果
--]]

local M = {}

-- ============================================================
-- 【核心配置】仅监听按键 6
-- ============================================================

local TRIGGER_KEY = "6"  -- 触发/显示结果按键

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
    
    -- 检查是否按下触发键
    if key_repr == TRIGGER_KEY and context:has_menu() then
        -- 写入加载文本
        write_file(LOADING_FILE, "AI纠正中...")
        
        -- 设置触发标志
        write_file(TRIGGER_FLAG, tostring(os.time()) .. "_correct")
        
        -- 刷新候选列表
        context:refresh_non_confirmed_composition()
        
        return 1  -- kAccepted
    end
    
    return 2  -- kNoop
end

function M.fini(env)
    -- 清理
end

return M
