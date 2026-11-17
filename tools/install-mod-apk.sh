#!/data/data/com.termux/files/usr/bin/sh
# 一键安装改版 DroidVM（内置 Apple crosvm + virglrenderer）
APK_URL="https://github.com/QQ127/macOS-DroidVM/releases/download/droidvm-apple-apk/DroidVM-macOS27-AppleCrosvm.apk"
PKG="cn.classfun.droidvm"
DEST="/sdcard/Download/DroidVM-macOS27-AppleCrosvm.apk"
EXPECT="c43d81def3527af75b84ff2eba0443158dd1475761c9536fd436ef9bf826341f"

echo "=== 改版 DroidVM 一键安装 ==="
echo "[1/5] 检查 root"
su -c 'id' >/dev/null 2>&1 || { echo "无 root，请用 MT管理器 手动安装 APK"; exit 1; }
echo "  root OK"

echo "[2/5] 备份旧版 APK"
OLD=$(su -c '/system/bin/pm path '"$PKG"' 2>/dev/null' | sed 's/package://' | head -1)
if [ -n "$OLD" ]; then
  su -c 'cp '"$OLD"' /sdcard/Download/DroidVM-original-backup.apk' 2>/dev/null && echo "  已备份到 /sdcard/Download/DroidVM-original-backup.apk" || echo "  备份跳过（不影响安装）"
else
  echo "  未找到旧版（可能首次安装）"
fi

echo "[3/5] 下载改版 APK（114MB，请耐心）"
curl -fSL --retry 3 -o "$DEST" "$APK_URL" || { echo "下载失败，检查网络"; exit 1; }
ls -lh "$DEST"

echo "[4/5] 校验文件"
GOT=$(sha256sum "$DEST" 2>/dev/null | cut -d' ' -f1)
if [ "$GOT" = "$EXPECT" ]; then echo "  校验通过"; else echo "  ⚠ 校验不符: $GOT（可能下载不完整）"; fi

echo "[5/5] 安装（会先卸载旧版，配置会清空，镜像文件不动）"
su -c '/system/bin/pm uninstall '"$PKG"' 2>/dev/null'
su -c "/system/bin/pm install -r $DEST" 2>&1 | tail -3
if su -c '/system/bin/pm path '"$PKG"'' >/dev/null 2>&1; then
  echo "=== 安装成功！打开 DroidVM 即可 ==="
else
  echo "=== 安装失败，请用 MT管理器 手动安装 $DEST ==="
fi
