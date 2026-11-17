#!/system/bin/sh
# 永久修复 Apple crosvm：
#  1) 磁盘放 Apple 版 crosvm（支持 --mbi-spis）
#  2) 写回一份完整 hash.json：crosvm 项记内置 hash（App 校验只读这个记录，不读实时文件，故不还原），
#     其余 91 项 + asset 项保持 APK 内置清单原值，使 needsExtractPrebuilt()=false 永不重新解压。
set -e
BASE="https://github.com/QQ127/macOS-DroidVM/releases/download/crosvm-apple-fix"
ZIPURL="$BASE/crosvm-apple-runtime.zip"
HASHURL="$BASE/droidvm-hash.json"
DATA="/data/data/cn.classfun.droidvm"
WORK="/data/local/tmp/crosvm-apple"
BAK="$DATA/usr/backup-pre-apple3"
STAMP="$(date +%Y%m%d-%H%M%S)"
FAKE="cd3693ba876720f7ab7c08e5d6358101336f3bbcdb3d7d4f324ac29274bf6a7b"
APPLE="c3310ae33402d8bd2c3b97d243d19506f6dac5df911b8304451a0c2f33ed5ac4"

echo "=== 0. 下载工具 ==="
FETCH=""
if command -v curl >/dev/null 2>&1; then FETCH="curl"
elif command -v wget >/dev/null 2>&1; then FETCH="wget"
elif [ -x /system/bin/toybox ]; then FETCH="toybox"
else echo "!! 无下载工具，先运行: pkg install curl -y"; exit 1; fi
echo "工具: $FETCH"
dl() { # url dest
  if [ "$FETCH" = "curl" ]; then curl -fsSL --retry 3 -o "$2" "$1"
  elif [ "$FETCH" = "wget" ]; then wget -q -O "$2" "$1"
  else /system/bin/toybox wget -q -O "$2" "$1"; fi
}

echo "=== 1. 找 crosvm zip（优先用本地已下载）==="
ZIP=""
for p in "$HOME/crosvm-apple-runtime.zip" "$HOME/storage/downloads/crosvm-apple-runtime.zip" \
  "$HOME/storage/shared/Download/crosvm-apple-runtime.zip" /sdcard/Download/crosvm-apple-runtime.zip \
  /storage/emulated/0/Download/crosvm-apple-runtime.zip /sdcard/crosvm-apple-runtime.zip ; do
  [ -f "$p" ] && { ZIP="$p"; echo "找到: $p"; break; }
done
rm -rf "$WORK"; mkdir -p "$WORK"
if [ -z "$ZIP" ]; then echo "下载 crosvm 14MB..."; ZIP="$WORK/runtime.zip"; dl "$ZIPURL" "$ZIP"; fi
ls -lh "$ZIP"

echo "=== 2. 解压 crosvm ==="
if command -v unzip >/dev/null 2>&1; then unzip -oq "$ZIP" -d "$WORK"
elif [ -x /system/bin/toybox ]; then /system/bin/toybox unzip -o "$ZIP" -d "$WORK"
else echo "!! 无 unzip，先运行: pkg install unzip -y"; exit 1; fi
[ -f "$WORK/usr/bin/crosvm" ] || { echo "!! 解压失败"; exit 1; }

echo "=== 3. 备份 ==="
mkdir -p "$BAK/$STAMP"
[ -f "$DATA/usr/bin/crosvm" ] && cp -a "$DATA/usr/bin/crosvm" "$BAK/$STAMP/crosvm"
[ -f "$DATA/hash.json" ] && cp -a "$DATA/hash.json" "$BAK/$STAMP/hash.json"
echo "还原点: $BAK/$STAMP"

echo "=== 4. 替换 crosvm + 库 ==="
mkdir -p "$DATA/usr/bin" "$DATA/usr/lib"
cp -f "$WORK/usr/bin/crosvm" "$DATA/usr/bin/crosvm"
cp -f "$WORK"/usr/lib/*.so "$DATA/usr/lib/" 2>/dev/null || true
chmod 755 "$DATA/usr/bin/crosvm"

echo "=== 5. 写入完整 hash.json（关键：根治冷启动还原）==="
HJ="$DATA/hash.json"
TMP="$WORK/hash.json"
dl "$HASHURL" "$TMP"
[ -s "$TMP" ] || { echo "!! hash.json 下载失败"; exit 1; }
# 确认里面 crosvm 记的是内置假 hash（App 校验读它 → 判无变化 → 不还原）
grep -q "\"usr/bin/crosvm\",\"sha256\":\"$FAKE\"" "$TMP" || { echo "!! hash.json 内容不符预期"; exit 1; }
cp -f "$TMP" "$HJ"
chmod 644 "$HJ"
echo "hash.json 已写入: $(wc -c < "$HJ") 字节, $(grep -o '\"file\"' "$HJ" | wc -l) 项"

echo "=== 6. 校验 ==="
echo -n "磁盘 crosvm 实际 hash : "; sha256sum "$DATA/usr/bin/crosvm" | cut -d' ' -f1
echo "预期(Apple 版)         : $APPLE"
echo -n "hash.json crosvm 记录  : "; grep -o '"file":"usr/bin/crosvm","sha256":"[0-9a-f]*"' "$HJ" | grep -o '[0-9a-f]\{64\}' | head -1
echo "应等于(内置假 hash)    : $FAKE"
echo ""
echo "完成。回 DroidVM 直接开机；App 冷启动也不会再还原。如需还原: $BAK/$STAMP"
