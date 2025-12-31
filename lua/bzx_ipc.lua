--[[
    bzx_ipc.lua - 跨平台 IPC 通信模块 (文件版)

    所有平台都使用临时文件进行通信：
    - Unix: /tmp 目录
    - Windows: %TEMP% 目录
    
    通信协议：
    - 请求文件 (_req.txt): Lua 写入请求
    - 响应文件 (_resp.txt): Python 写入响应，Lua 读取
--]]

local IPCManager = {}
IPCManager.__index = IPCManager

-- 判断操作系统
local function is_windows()
    return package.config:sub(1, 1) == "\\"
end

-- 获取临时目录
local function get_temp_dir()
    if is_windows() then
        return os.getenv("TEMP") or os.getenv("TMP") or "C:\\Temp"
    else
        return "/tmp"
    end
end

-- ============================================================
-- 构造函数
-- ============================================================

function IPCManager.new(name)
    local self = setmetatable({}, IPCManager)
    self.name = name or "bzx_rime"
    self.is_win = is_windows()
    
    local temp_dir = get_temp_dir()
    local sep = self.is_win and "\\" or "/"
    
    -- 请求文件和响应文件
    self.req_file = temp_dir .. sep .. self.name .. "_req.txt"
    self.resp_file = temp_dir .. sep .. self.name .. "_resp.txt"
    
    return self
end

-- ============================================================
-- 检测服务是否运行（检查响应文件是否存在）
-- ============================================================

function IPCManager:exists()
    local f = io.open(self.resp_file, "r")
    if f then
        f:close()
        return true
    end
    return false
end

-- ============================================================
-- 发送请求 (写入请求文件)
-- ============================================================

function IPCManager:send(text)
    local f = io.open(self.req_file, "w")
    if not f then
        return false
    end

    local ok = pcall(function()
        f:write(text .. "\n")
        f:flush()
        f:close()
    end)

    if not ok then
        pcall(function() f:close() end)
        return false
    end

    return true
end

-- ============================================================
-- 读取响应 (从响应文件读取)
-- ============================================================

function IPCManager:read()
    local f = io.open(self.resp_file, "r")
    if not f then
        return nil
    end

    local content = nil
    local ok = pcall(function()
        content = f:read("*a")
        f:close()
    end)

    if not ok then
        pcall(function() f:close() end)
        return nil
    end

    -- 去除首尾空白
    if content then
        content = content:gsub("^%s*(.-)%s*$", "%1")
    end

    -- 空字符串返回 nil
    if content and content ~= "" then
        return content
    end

    return nil
end

-- ============================================================
-- 解析消息类型
-- ============================================================

function IPCManager:parse_type(text)
    if not text then return nil end
    local msg_type = text:match('"type"%s*:%s*"([^"]*)"')
    return msg_type
end

-- ============================================================
-- 检查是否为空消息
-- ============================================================

function IPCManager:is_idle(text)
    local msg_type = self:parse_type(text)
    return msg_type == "__IDLE__"
end

-- ============================================================
-- 发送 ACK 确认消息
-- ============================================================

function IPCManager:send_ack()
    return self:send('{"type":"__ACK__"}')
end

-- ============================================================
-- 发送 EMPTY 通知
-- ============================================================

function IPCManager:send_empty()
    return self:send('{"type":"__EMPTY__"}')
end

-- ============================================================
-- 非阻塞读取 (与 read 相同)
-- ============================================================

function IPCManager:read_non_blocking()
    return self:read()
end

-- ============================================================
-- 关闭（无操作）
-- ============================================================

function IPCManager:close()
end

return IPCManager
