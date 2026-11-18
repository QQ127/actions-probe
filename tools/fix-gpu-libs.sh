#!/data/data/com.termux/files/usr/bin/sh
set -e
DATA="/data/data/cn.classfun.droidvm"
WORK="$HOME/crosvm-libfix"

echo "===== 补装 GPU 库到 usr/lib ====="
echo "[1/5] 当前 usr/lib 库数量(应该接近0)"
su -c "ls $DATA/usr/lib/ 2>/dev/null | wc -l"

echo "[2/5] 找本地 zip"
ZIP=""
for p in "$HOME/crosvm-apple-runtime.zip" "$HOME/storage/downloads/crosvm-apple-runtime.zip" \
  "$HOME/storage/shared/Download/crosvm-apple-runtime.zip" /sdcard/Download/crosvm-apple-runtime.zip \
  /storage/emulated/0/Download/crosvm-apple-runtime.zip /sdcard/crosvm-apple-runtime.zip ; do
  [ -f "$p" ] && { ZIP="$p"; echo "找到本地: $p"; break; }
done
if [ -z "$ZIP" ]; then
  echo "本地没找到, 下载 14MB..."
  mkdir -p "$WORK"
  ZURL="https://github.com/QQ127/macOS-DroidVM/releases/download/crosvm-apple-fix/crosvm-apple-runtime.zip"
  curl -fsSL --retry 3 -o "$WORK/runtime.zip" "$ZURL"
  ZIP="$WORK/runtime.zip"
fi
ls -lh "$ZIP"

echo "[3/5] 解压库到 Termux 家目录(有权限)"
rm -rf "$WORK/unpack"; mkdir -p "$WORK/unpack"
if command -v unzip >/dev/null 2>&1; then
  unzip -oq "$ZIP" 'usr/lib/*' -d "$WORK/unpack"
else
  su -c "toybox unzip -o '$ZIP' 'usr/lib/*' -d '$WORK/unpack'" 2>/dev/null || unzip -o "$ZIP" 'usr/lib/*' -d "$WORK/unpack"
fi
echo "zip里的库:"
ls -lh "$WORK/unpack/usr/lib/" 2>/dev/null | head -30

echo "[4/5] 复制到手机 usr/lib(root)"
su -c "mkdir -p $DATA/usr/lib"
su -c "cp -f $WORK/unpack/usr/lib/*.so $DATA/usr/lib/"
su -c "chmod 644 $DATA/usr/lib/*.so"
echo "复制后 usr/lib 库数量:"
su -c "ls $DATA/usr/lib/ 2>/dev/null | wc -l"

echo "[5/5] 校验关键库是否到位"
for lib in libvirglrenderer.so libgfxstream_backend.so; do
  if su -c "test -f $DATA/usr/lib/$lib"; then echo "  [OK] $lib"; else echo "  [缺] $lib"; fi
done
echo "===== 完成: 回 DroidVM 开机(VirGL配置不变), 把结果发我 ====="
