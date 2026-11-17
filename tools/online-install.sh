#!/system/bin/sh
# 在 DroidVM 已打开的情况下运行：替换 crosvm，全程不要关闭 App
set -e
URL="https://github.com/QQ127/macOS-DroidVM/releases/download/crosvm-apple-fix/crosvm-apple-runtime.zip"
DATA="/data/data/cn.classfun.droidvm"
WORK="/data/local/tmp/crosvm-apple"
BAK="$DATA/usr/backup-before-apple"
STAMP="$(date +%Y%m%d-%H%M%S)"

echo "=== 0. 下载工具 ==="
FETCH=""
if command -v curl >/dev/null 2>&1; then FETCH="curl"
elif command -v wget >/dev/null 2>&1; then FETCH="wget"
elif [ -x /system/bin/toybox ]; then FETCH="toybox"
else echo "!! 无下载工具，先运行: pkg install curl -y"; exit 1; fi
echo "工具: $FETCH"

echo "=== 1. 找 zip（优先用已下载的）==="
ZIP=""
for p in "$HOME/crosvm-apple-runtime.zip" "$HOME/storage/downloads/crosvm-apple-runtime.zip" \
  "$HOME/storage/shared/Download/crosvm-apple-runtime.zip" /sdcard/Download/crosvm-apple-runtime.zip \
  /storage/emulated/0/Download/crosvm-apple-runtime.zip /sdcard/crosvm-apple-runtime.zip ; do
  [ -f "$p" ] && { ZIP="$p"; echo "找到: $p"; break; }
done
rm -rf "$WORK"; mkdir -p "$WORK"
if [ -z "$ZIP" ]; then
  echo "从 GitHub 下载 14MB..."
  ZIP="$WORK/runtime.zip"
  if [ "$FETCH" = "curl" ]; then curl -fsSL --retry 3 -o "$ZIP" "$URL"
  elif [ "$FETCH" = "wget" ]; then wget -q -O "$ZIP" "$URL"
  else /system/bin/toybox wget -q -O "$ZIP" "$URL"; fi
fi
ls -lh "$ZIP"

echo "=== 2. 解压 ==="
if command -v unzip >/dev/null 2>&1; then unzip -oq "$ZIP" -d "$WORK"
elif [ -x /system/bin/toybox ]; then /system/bin/toybox unzip -o "$ZIP" -d "$WORK"
else echo "!! 无 unzip，先运行: pkg install unzip -y"; exit 1; fi
[ -f "$WORK/usr/bin/crosvm" ] || { echo "!! 解压失败"; exit 1; }

echo "=== 3. 备份 ==="
mkdir -p "$BAK/$STAMP"
[ -f "$DATA/usr/bin/crosvm" ] && cp -a "$DATA/usr/bin/crosvm" "$BAK/$STAMP/crosvm"
[ -f "$DATA/hash.json" ] && cp -a "$DATA/hash.json" "$BAK/$STAMP/hash.json"
echo "$STAMP" > "$BAK/LAST_BACKUP"
echo "还原点: $BAK/$STAMP"

echo "=== 4. 替换 crosvm + 全部库 ==="
mkdir -p "$DATA/usr/bin" "$DATA/usr/lib"
cp -f "$WORK/usr/bin/crosvm" "$DATA/usr/bin/crosvm"
cp -f "$WORK"/usr/lib/*.so "$DATA/usr/lib/"
chmod 755 "$DATA/usr/bin/crosvm"
chmod 644 "$DATA"/usr/lib/*.so

echo "=== 5. 校验 ==="
sha256sum "$DATA/usr/bin/crosvm"
echo "预期: c3310ae33402d8bd2c3b97d243d19506f6dac5df911b8304451a0c2f33ed5ac4"
echo ""
echo "完成！现在立刻回 DroidVM，【不要关闭 App】，直接编辑参数并开机。"
