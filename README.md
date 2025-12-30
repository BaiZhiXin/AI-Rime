# 当前Windows版本存在问题，不要尝试部署

# AI-Rime
基于Rime的lua脚本系统打造AI增强输入法


![](https://ulln.top:8890/s/N2WAw6rcs7LsMEr/preview)

![](https://ulln.top:8890/s/YKeG2dETmss23Hq/preview)

# Rime AI 纠错 v1 智能纠错

## 功能说明

极简版 AI 纠错功能：
- 按 **6** 触发纠错，显示"AI纠正中..."
- 再按 **6** 显示纠正结果

## 文件清单

| 文件 | 说明 |
|------|------|
| `ai_corrector_processor.lua` | 按键监听（放入 `lua/` 目录） |
| `ai_corrector.lua` | 候选词处理（放入 `lua/` 目录） |
| `ai_corrector_service*` | 后台服务 |

# 前言

Lua 是一种轻量小巧的脚本语言，用标准C语言编写并以源代码形式开放， 其设计目的是为了嵌入应用程序中，从而为应用程序提供灵活的扩展和定制功能。

Rime输入法支持内置简单的Lua脚本，基于此得以设计AI输入法。

Rime的配置文件夹结构大致如下：

**Rime**

- Lua——存放lua脚本
- build——存放构建后的信息
- *.userdb——存放用户输入习惯的记录
- *_dicts——存放引入的词典
- 其他配置文件

## 安装步骤

### 1. 程序文件部署

当前版本总共需要部署三个程序，分别是两个lua程序以及一个可执行程序。

Rime输入法配置文件可通过Rime输入法菜单打开，Mac端叫作`用户设定`，Windows端叫作`用户文件夹`。Mac下Rime用户资料默认在`Users/用户名/Library/Rime`下，可直接在`README.md`所在目录打开终端执行下面命令进行复制。

```bash
cp ai_corrector_processor.lua ~/Library/Rime/lua/
cp ai_corrector.lua ~/Library/Rime/lua/
```

Windows端Rime用户文件夹默认路径是`C:\Users\用户名\AppData\Roaming\Rime`，Linux平台输入框架和版本不同则具体的也会目录不同，需要根据系统是fictx4、fictx5或iBus来定。

将不同平台对应的可执行程序复制到Rime配置文件的根目录下。

### 2. 配置 Rime Schema

在你的输入方案的schema（例如雾凇拼音rime_ice.schema.yaml文件）中添加：
```yaml
engine:
  processors:
    - lua_processor@*ai_corrector_processor	# 尽量放在processors前面，以免被其他processor抢先捕获
  filters:
    - lua_filter@*ai_corrector	# 这一条必须放在filters的第一个位置，用于修改AI纠正结果显示
```

或者在输入方案的custom文件中添加：

```yaml
patch:	# 更推荐这种添加方案，不影响原有配置文件
  engine/processors/@after 0: lua_processor@*ai_corrector_processor
  engine/filters/@before last: lua_filter@*ai_corrector
```

例如对雾凇拼音的`rime_ice.shcema.yaml`配置文件创建一个`rime_ice.custom.yaml`文件，然后添加上面的`patch内容`。

### 3. 启动服务

- Windows平台在Rime根目录下打开PowerShell，执行命令开启服务，终端会显示纠错请求信息。Windows平台可以利用nssm制作后台服务（注意工作目录设置成Rime配置文件根目录）。
  ```shell
  ./ai_corrector_service_Windows/ai_corrector_service.exe
  ```

- Linux平台同样在Rime配置根目录打开终端，执行命令启动服务。
  ````shell
  ./ai_corrector_service_Linux/ai_corrector_service.bin
  ````

  如果启动失败的话检查权限是否正确，通过命令赋予运行权限。
  ```shell
  chmod +x ./ai_corrector_service_Linux/ai_corrector_service.bin
  ```

  Linux可用systemd设置成服务后台运行，直接执行bin文件即可，建议设置工作目录是Rime配置文件根目录。

- Mac平台将`ai_corrector_service_Mac.app`放置在Rime配置文件根目录后**不可以**直接双击运行，因为服务程序没有UI，因此同样需要在Rime配置文件根目录打开终端执行命令：
  ```shell
  ./ai_corrector_service_Mac.app/Contents/MacOS/ai_corrector_service
  ```

​	Mac电脑可用launched设置成服务后台运行。

### 4. 重新部署 Rime

## 使用方法

本方案是基于雾凇拼音输入方案而设计的，其他拼音方案同样可用。雾凇拼音默认设置5个候选词，因此我将数字键6作为了触发纠错功能的触发按键。

上面部署阶段成功后，具体的操作流程如下：

1. 输入拼音，看到候选词
2. 按 **6** 触发纠错
3. 再按 **6** 显示结果
4. 按 **空格** 选择结果

**结束语：**

因为Rime本身的设计，lua脚本只能在输入发生变动时触发，因此该版本需要先按数字键6触发AI纠错请求，等1-2s后再按6触发AI返回结果显示。等待按第二次键很是恼人，目前已经在设计第二版本，期望可以解决避免需要二次按键触发的问题。

当前版本prompt提示词经过数百次尝试优化，已经达到较好的效果。如果关注较多的话考虑下一版本公开提示词，到时候可以自定义做更多花样。

博主自费购买了123盘的直链流量，将资源放在123盘以供下载，不需要登录，也不会限速。喜欢的可以点个赞关注一波。

https://1815368419.v.123pan.cn/1815368419/26934630





# Rime AI 纠错 v2 可配置版

## 功能说明

支持外部配置文件和自动触发的 AI 纠错功能：

- 按 **6** 触发纠错
- 按 **0** 显示结果（或开启自动触发后自动显示）

## 文件清单

| 文件                         | 说明                           |
| ---------------------------- | ------------------------------ |
| `ai_corrector_processor.lua` | 按键监听（放入 `lua/` 目录）   |
| `ai_corrector.lua`           | 候选词处理（放入 `lua/` 目录） |
| `ai_corrector_service.*`     | 后台服务                       |
| `ai_corrector_config.json`   | 配置文件                       |

## 安装步骤

### 1. 复制文件

**见版本1说明**

### 2. 修改配置

编辑 `ai_corrector_config.json`：

```json
{
    "api_key": "你的API密钥",
    "auto_trigger": true
}
```

配置文件记录着请求AI的信息，请把他放置在Rime配置目录下。

### 3. 配置 Rime Schema

**见版本1说明**

### 4. 启动服务

**见版本1说明**

### 5. 重新部署 Rime

## 配置选项

| 选项           | 说明                               | 默认值        |
| -------------- | ---------------------------------- | ------------- |
| `provider`     | AI 提供商 (deepseek/openai/ollama) | deepseek      |
| `api_key`      | API 密钥                           | 空            |
| `api_url`      | API 地址                           | DeepSeek      |
| `model`        | 模型名称                           | deepseek-chat |
| `auto_trigger` | 自动显示结果                       | true          |
| `prompt`       | 纠错提示词                         | 内置          |

## 自动触发

开启 `auto_trigger` 后：

1. 按 6 触发纠错
2. AI 返回结果后自动模拟按键 0
3. 结果自动显示

需要权限：

- **macOS**: 系统设置 → 隐私与安全性 → 辅助功能 → 添加 服务程序

资源链接：

https://1815368419.v.123pan.cn/1815368419/26963692



# V2-Linux修复版本

**前言：**

- 由于Linux系统输入法框架的设计，首发v2版本出现配置文件找错目录的问题，现已经经过修改和测试，在作者Ubuntu24 x11系统上已经可以正常运行，如若在其他发行版上出现问题请及时反馈。

- v2版本是基于python的pynput模块实现发送模拟按键0来代替用户第二次按键触发直接修改输入法第一个候选词显示为AI返回结果的，但是优于Linux下x11和Wayland对pynput支持较差，因此此次修复版本针对这一问题做出了深度修复与测试。作者Ubuntu24 x11环境下可以实现正常纠错及自动触发，优于作者设备有限，没能测试Wayland，因此下面给出x11的实际可行配置策略及Wayland理论可行配置策略。



# Linux 模拟按键配置指南

本文档说明在 Linux 环境下配置 AI 纠错服务自动触发功能所需的依赖和设置。

## 问题背景

Python 的 `pynput` 库在 Linux 下存在以下问题：

- **X11**：需要额外权限配置，且不够稳定
- **Wayland**：静默失败，无法正常工作

因此，在 Linux 下程序**跳过 pynput**，改用系统工具。

---

## 环境检测

程序通过环境变量 `XDG_SESSION_TYPE` 自动检测当前桌面环境：

```bash
echo $XDG_SESSION_TYPE
# 输出 "x11" 或 "wayland"
```

---

## X11 环境

### 使用工具：xdotool

### 安装

```bash
# Ubuntu/Debian
sudo apt install xdotool

# Fedora
sudo dnf install xdotool

# Arch
sudo pacman -S xdotool
```

### 测试

```bash
xdotool key 0
```

### 无需额外配置

X11 下 xdotool 开箱即用，无需守护进程或特殊权限。

---

## Wayland 环境

### 使用工具：ydotool

### 安装

```bash
# Ubuntu/Debian
sudo apt install ydotool

# Fedora
sudo dnf install ydotool

# Arch
sudo pacman -S ydotool
```

### 启动守护进程

ydotool 需要后台运行 `ydotoold` 守护进程：

```bash
# 手动启动
sudo ydotoold &

# 或使用 systemd（推荐）
sudo systemctl enable ydotool
sudo systemctl start ydotool
```

### 用户权限

将用户添加到 `input` 组：

```bash
sudo usermod -aG input $USER
# 注销并重新登录生效
```

### 测试

```bash
# 数字 0 的 Linux 内核键码是 11
# 格式：keycode:1 (按下) keycode:0 (释放)
ydotool key 11:1 11:0
```

---

**结语：**以上是针对Linux用户需要特殊配置的说明，若有其他问题请即时反馈。

资源链接：https://1815368419.v.123pan.cn/1815368419/26969029
