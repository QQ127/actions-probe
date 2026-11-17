#!/system/bin/sh
# 永久修复 Apple crosvm：磁盘放 Apple 版 + 把 hash.json 的 crosvm 记录写回内置假 hash
# 原理：DroidVM 冷启动只读 hash.json 的缓存值判断要不要重新解压，不读实时文件 hash。
#       只要 hash.json 里 crosvm 的记录 == APK 内置清单值，App 就认为"没变化"，不会还原。
#       于是磁盘上放 Apple 版 crosvm 就能被直接加载。
set -e
URL="https://github.com/QQ127/macOS-DroidVM/releases/download/crosvm-apple-fix/crosvm-apple-runtime.zip"
DATA="/data/data/cn.classfun.droidvm"
WORK="/data/local/tmp/crosvm-apple"
BAK="$DATA/usr/backup-pre-apple2"
STAMP="$(date +%Y%m%d-%H%M%S)"
FAKE="cd3693ba876720f7ab7c08e5d6358101336f3bbcdb3d7d4f324ac29274bf6a7b"  # APK 内置清单里的 crosvm 期望值
APPLE="c3310ae33402d8bd2c3b97d243d19506f6dac5df911b8304451a0c2f33ed5ac4"  # Apple 版实际值

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
echo "还原点: $BAK/$STAMP"

echo "=== 4. 替换 crosvm + 全部库 ==="
mkdir -p "$DATA/usr/bin" "$DATA/usr/lib"
cp -f "$WORK/usr/bin/crosvm" "$DATA/usr/bin/crosvm"
cp -f "$WORK"/usr/lib/*.so "$DATA/usr/lib/" 2>/dev/null || true
chmod 755 "$DATA/usr/bin/crosvm"

echo "=== 5. 关键：把 hash.json 里 crosvm 记录写回内置假 hash（防冷启动还原）==="
HJ="$DATA/hash.json"
if [ -f "$HJ" ]; then
  # 条目形如 {"file":"usr/bin/crosvm","sha256":"....","source":"prebuilt"}
  # Android org.json 保持字段顺序 file→sha256→source，故此模式稳定命中
  sed -i "s#\(\"file\":\"usr/bin/crosvm\",\"sha256\":\"\)[0-9a-f]*#\1$FAKE#" "$HJ"
else
  echo "!! 找不到 hash.json，跳过（App 首次启动会自动重建）"
fi

echo "=== 6. 校验 ==="
echo -n "磁盘 crosvm 实际 hash : "; sha256sum "$DATA/usr/bin/crosvm" | cut -d' ' -f1
echo "预期(Apple 版)         : $APPLE"
echo -n "hash.json 里 crosvm 记录: "; grep -o '"file":"usr/bin/crosvm","sha256":"[0-9a-f]*"' "$HJ" 2>/dev/null | grep -o '[0-9a-f]\{64\}' | head -1
echo "应等于(内置假 hash)    : $FAKE"
echo ""
echo "完成。回 DroidVM 直接开机即可；即使 App 被冷启动也不会再还原。"
echo "（如需还原：see $BAK/$STAMP）"
