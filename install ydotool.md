## 安装ydotool并添加到service（wayland模拟按键）
安装：
```bash
sudo pacman -S ydotool
```
创建service文件：（注意将`/usr/local/bin/ydotoold`更改为实际的ydotoold的路径，使用`which ydotoold`）
```bash
cat > ~/.config/systemd/user/ydotoold.service <<EOF
[Unit]
Description=ydotool daemon (user service)
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/local/bin/ydotoold
Restart=on-failure
RestartSec=1

[Install]
WantedBy=default.target
EOF
```
启用并启动用户服务：
```bash
# 重载用户 systemd 配置
systemctl --user daemon-reload

# 启用开机自启（在用户登录后）
systemctl --user enable ydotoold.service

# 立即启动
systemctl --user start ydotoold.service
```
验证服务是否运行：
```bash
systemctl --user status ydotoold
```
### 将当前用户添加到input用户组
```bash
# 创建 input 用户组（如果不存在）
sudo groupadd -f input

# 将当前用户加入 input 组（这里如果不生效，将$USER替换为你当前实际用户名）
sudo usermod -aG input $USER

# 创建 udev 规则
echo 'KERNEL=="uinput", MODE="0660", GROUP="input"' | sudo tee /etc/udev/rules.d/99-ydotool.rules

# 重新加载 udev 规则
sudo udevadm control --reload-rules && sudo udevadm trigger

# 重要：重新登录或重启，使组生效！
```
### 测试是否安装成功
启动service后
```bash
ydotool type "Hello World"
```
应该在当前终端会出现`Hello World`字符串
