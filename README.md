# AI-Rime

**基于Rime打造的AI增强输入法方案**

AI-Rime是一个基于Rime开源输入法框架打造的AI增强解决方案。目前主要功能有：

1. AI纠错：可以将输入的错句发送至AI，将得到AI辅助纠错的结果。该功能能够一定程度解决Rime输入法本身较弱的句意感知能力，帮用户省去频繁翻页的动作。
2. AI翻译：实现中英互译，可用于快速翻译，不用打开翻译软件。
3. AI对话：可用于一次性的对话，例如命令生成、知识询问等。

项目主要利用Rime内置的lua脚本实现，lua脚本本身不支持网络操作，用户必须启动服务程序用于请求AI响应。

![](https://ulln.top:8890/s/xS2yYPWQAcSK9Pk/preview)



![](https://ulln.top:8890/s/ZoRRHHXLrgxe7ZA/preview)



![](https://ulln.top:8890/s/enZStLTsDzFyQ7H/preview)



## V3版本全面升级，指尖AI既是如此

**前言：**本次升级带来更便捷的部署体验，通信架构全面升级，大幅提升性能。本次重磅升级是带来了一键AI翻译和一键AI问答，同时升级实现了通过方向键处理非第一侯选词的功能。



## 试想

当你正在给你的好朋友讨论人生哲学，忽然之间想要引用一下诗人李白的一首诗词，但是恍惚间只想起来一半，此时就较为尴尬。这时候要去打开浏览器搜索吗？还是打开网页访问AI获取结果？又或者通过快捷键打开类似`Raycast`的软件求告知？——都不要！！！只要一款AI输入法即可实现，输入`天生我材必有用`，按下`8`触发键，之后你就是你好朋友严重的文人✌️



你正在完成一个百万级的编程项目，当你想要为突然迸发的思路创建一个新文件来实现的时候，突然之间你不知道用于实现某功能的文件该起什么名字。这时候该怎么办呢？直接通过AI-Rime输入法输入你功能的汉语按下`7`触发键，一键得到翻译✌️



**总：**即使现在AI已经非常发达，但是能够让AI彻底融入生活，让生活便利还是需要一定努力。相较于打开网页的操作，打开搜索引擎的操作，打开终端访问agent的操作而言，`AI-Rime`输入法`v3`版本就是你指尖的`AI`，帮助你提升效率，成为核动力牛马。



> [!WARNING]
>
> 当前版本的Windows版本已经过win10系统测试可以正常工作，但是无法保证其他Windows电脑环境是否均能稳定运行。
>
> Linux版本暂未测试，Linux设置自动触发时需要安装额外工具，具体操作请参考[Linux 模拟按键配置指南](# Linux 模拟按键配置指南).
>
> Mac版本已经过M系列芯片测试正常可用，仍建议用户备份重要资料再尝试。
>
> 资料宝贵，谨慎试用！



## 升级改动点：

相较于上一个版本：

1. 将原本的命名进行改动，由原来`ai_corrector_`更正为`bzx_`，预示着当前版本从单一纠正升级为全能输入法方案。
2. 将原本代码逻辑进行升级解耦，拆分成四个lua脚本：`bzx_filter.lua`, `bzx_ipc.lua`, `bzx_processor.lua`, `bzx_state.lua`。

   - `bzx_state.lua`是新增功能，提供一组高可用全局状态变量。
   - `bzx_filter.lua`文件进行极度简化，从原本轮询文件通信改成通过全局变量判断刷新显示。
   - `bzx_processor.lua`文件改动较小，主要从其中剥离了通信逻辑，使其专注于中间信息传导和按键监听。
   - `bzx_ipc.lua`文件是从`bzx_processor.lua`文件中剥离而出，并且从原本的Rime配置目录下临时文件通信升级为Unix系统`/tmp`路径通信，Windows系统`%TEMP%`目录通信。相较于原本普通文件通信，`/tmp`路径下文件通信速度可提升约数十倍。
3. 新增`翻译`功能，默认设置触发按键`7`，通过调用大模型能力实现中英互译。
4. 新增`对话`功能，默认设置触发按键`8`，同样通过大模型处理输入内容。
5. 当前Windows版本服务程序改用单exe形式发布，名称为`bzx_service.exe`，方便部署移动。exe程序双击可直接运行，不局限于终端启动。**另**exe可执行程序可移动至任意位置启动，可不使用配置文件，也可通过`--config`参数指定配置文件路径，默认查找当前目录。

❗本次版本将作者的`DeepSeek key`集成在程序内部，能较大程度上避免因为没有`apikey`或者不熟悉配置配置文件而造成放弃的同志（作者含泪给`DeepSeek`充值，希望得到大家的`star`🌟）。



**关于输入发与服务程序间通信要说的**

优于`rime`输入法的`lua`脚本环境限制太严格，尝试了数十种通信方案均未果。有的方法十分复杂且容易引起不稳定，有的方法容易导致输入法卡顿，所以最终选择继续沿用上版本的临时文件通信，但是从`Unix`系统的普通文件转变成`/tmp`下的文件。

相较于上一个版本设计了严格的通信流程及细节，能做到极少的文件信息交换，基本实现察觉不到通信延迟的存在。

相较于给`rime`的`lua`编译`socket`工具或者强制添加`ffi`功能而言，该方法能在做到不侵入`rime`架构，保持其稳定性的前提下大幅提升性能，能够消除崩溃和卡顿的问题。



## 安装方法

将下载文件中lua内的`bzx_*.lua`全部放置在rime输入法的lua目录下，给自己使用的输入方案新建`custom`配置文件，并写入：

```yaml
patch:
  engine/processors/@after 0: lua_processor@*bzx_processor
  
  engine/filters/@before last: lua_filter@*bzx_filter
```

**Windows系统下**把下载的可执行程序和配置文件（建议用上配置文件，填入自己的apikey）扔在电脑的任意角落启动即可。若用配置文件可直接放在可执行程序同级目录。

**Mac及Linux系统下**建议通过终端添加`--config 配置文件地址`的形式启动：

```shell
# Mac
./bzx_service.app/Contents/MacOS/bzx_service --config ./bzx_config.json

# Linux
./bzx_service.bin --config ./bzx_config.json
```





> [!NOTE]
>
> 本次将上传基于雾凇拼音的懒人整合包，下载解压缩覆盖原有配置重新部署即可使用。



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

### 见文档`install ydotool.md`

---

**结语：**以上是针对Linux用户需要特殊配置的说明，若有其他问题请即时反馈。



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



![](https://ulln.top:8890/s/wr2Y5Ma2MBNNmJC/preview)

![](https://ulln.top:8890/s/YKeG2dETmss23Hq/preview)

# Rime AI 纠错 v1 智能纠错

## 功能说明

极简版 AI 纠错功能：

- 按 **6** 触发纠错，显示"AI纠正中..."
- 再按 **6** 显示纠正结果

## 文件清单

| 文件                         | 说明                           |
| ---------------------------- | ------------------------------ |
| `ai_corrector_processor.lua` | 按键监听（放入 `lua/` 目录）   |
| `ai_corrector.lua`           | 候选词处理（放入 `lua/` 目录） |
| `ai_corrector_service*`      | 后台服务                       |

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