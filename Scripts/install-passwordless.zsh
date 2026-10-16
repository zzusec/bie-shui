#!/bin/zsh
# 一次性配置「别睡」的免密码模式：
# 仅允许当前用户免密执行以下两条命令（sudoers 按字面量匹配参数，无法借此执行其他命令）：
#   /usr/bin/pmset -a disablesleep 1
#   /usr/bin/pmset -a disablesleep 0
#
# 用法：
#   ./Scripts/install-passwordless.zsh             安装（需要输入一次管理员密码）
#   ./Scripts/install-passwordless.zsh --uninstall 移除

set -euo pipefail

target_file="/etc/sudoers.d/lidawake"

if [[ "${1:-}" == "--uninstall" ]]; then
    sudo /bin/rm -f "$target_file"
    print "✅ 已移除免密配置：$target_file（应用将恢复为需要密码的模式）"
    exit 0
fi

rule="${USER} ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0"
tmp_file="$(/usr/bin/mktemp /tmp/lidawake-sudoers.XXXXXX)"
trap 'rm -f "$tmp_file"' EXIT

printf '%s\n' "$rule" > "$tmp_file"
/usr/sbin/visudo -cf "$tmp_file"
sudo /usr/bin/install -o root -g wheel -m 0440 "$tmp_file" "$target_file"

# 用与当前电源状态一致的命令做验证，避免意外改变合盖睡眠设置
probe_value=0
if [[ "$(/usr/bin/pmset -g | /usr/bin/awk '/SleepDisabled/{print $2}')" == "1" ]]; then
    probe_value=1
fi

if sudo -n /usr/bin/pmset -a disablesleep "$probe_value"; then
    print "✅ 免密码模式已启用并验证通过。"
else
    print "⚠️ 配置已写入 $target_file，但验证失败。请检查 /etc/sudoers 是否包含 #includedir /etc/sudoers.d"
    exit 1
fi
