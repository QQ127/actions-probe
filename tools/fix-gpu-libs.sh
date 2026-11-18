#!/data/data/com.termux/files/usr/bin/sh
set -e
BASE="https://github.com/QQ127/macOS-DroidVM/releases/download/crosvm-apple-fix"
ZIPURL="$BASE/crosvm-apple-runtime.zip"
DATA="/data/data/cn.classfun.droidvm"
WORK="/data/local/tmp/crosvm-libfix"

echo "===== 补装 GPU 库到 usr/lib ====="
echo "[1/5] 当前 usr/lib 库数量(应该接近0)"
su -c "ls $DATA/usr/lib/ 2>/dev/null | wc -l"

echo "[2/5] 找本地 zip 或下载"
ZIP=""
for p in "$HOME/crosvm-apple-runtime.zip" "$HOME/storage/downloads/crosvm-apple-runtime.zip" \
  "$HOME/storage/shared/Download/crosvm-apple-runtime.zip" /sdcard/Download/crosvm-apple-runtime.zip \
  /storage/emulated/0/Download/crosvm-apple-runtime.zip /sdcard/crosvm-apple-runtime.zip ; do
  [ -f "$p" ] && { ZIP="$p"; echo "找到本地: $p"; break; }
done
rm -rf "$WORK"; mkdir -p "$WORK"
if [ -z "$ZIP" ]; then echo "下载 runtime zip (14MB)..."; ZIP="$WORK/runtime.zip"; su -c "curl -fsSL --retry 3 -o $ZIP $ZIPURL"; fi
ls -lh "$ZIP"

echo "[3/5] 解压库"
cd "$WORK"
unzip -oq "$ZIP" 'usr/lib/*' 2>/dev/null || su -c "toybox unzip -o $ZIP 'usr/lib/*'" 2>/dev/null || { echo "!! 解压失败"; exit 1; }
echo "zip里的库:"
ls -lh "$WORK/usr/lib/" 2>/dev/null | head -30

echo "[4/5] 复制到手机 usr/lib 并设权限"
su -c "mkdir -p $DATA/usr/lib"
su -c "cp -f $WORK/usr/lib/*.so $DATA/usr/lib/"
su -c "chmod 644 $DATA/usr/lib/*.so"
echo "复制后 usr/lib 库数量:"
su -c "ls $DATA/usr/lib/ 2>/dev/null | wc -l"

echo "[5/5] 校验关键库是否到位"
for lib in libvirglrenderer.so libgfxstream_backend.so; do
  if su -c "test -f $DATA/usr/lib/$lib"; then echo "  [OK] $lib"; else echo "  [缺] $lib"; fi
done
echo "===== 完成: 回 DroidVM 开机(VirGL配置不变), 把结果发我 ====="
