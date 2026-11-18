#!/data/data/com.termux/files/usr/bin/sh
PKG=cn.classfun.droidvm
echo "===== DroidVM VirGL 崩溃 / dlopen 诊断 ====="
echo "说明: 请先在 VirGL 模式下开机触发一次退出码139崩溃, 再运行本脚本"
echo ""

echo "[1/6] 找最新的崩溃 tombstone"
su -c "ls -lt /data/tombstones/tombstone_* 2>/dev/null" | head -8
echo ""

echo "[2/6] 最新 tombstone 关键内容 (崩溃栈 + 加载的GPU库)"
TS=$(su -c "ls -t /data/tombstones/tombstone_* 2>/dev/null" | head -1)
if [ -n "$TS" ]; then
  echo "文件: $TS"
  su -c "cat $TS" 2>/dev/null | grep -iE "Cmdline:|signal |fault addr|backtrace:|#0[0-9]|libvirgl|libgbm|libEGL|libGLES|libvulkan|freedreno|kgsl|crosvm|linker|NOTE:|memory map|dlopen|cannot locate|not found|stack:" | head -140
else
  echo "  没找到 tombstone (系统可能不生成, 看第3步logcat)"
fi
echo ""

echo "[3/6] logcat 里 linker/dlopen/GPU库 报错 (最关键)"
su -c "/system/bin/logcat -d -v brief" 2>/dev/null | grep -iE "dlopen|cannot locate|linker|virgl|gbm|freedreno|vulkan|libEGL|libGLES|crosvm|CROSVM|SIGSEGV|fault addr|not found" | tail -100
echo ""

echo "[4/6] DroidVM 日志文件清单"
su -c "find /data/data/$PKG -type f 2>/dev/null" | grep -iE "\.log$|stdio|console|crash|tombstone" | head -40
echo ""

echo "[5/6] VM stdio/console 日志尾部"
for f in $(su -c "find /data/data/$PKG -type f 2>/dev/null" | grep -iE "stdio|console|\.log$" | head -8); do
  echo "--- $f ---"
  su -c "tail -60 $f 2>/dev/null" | grep -iE "dlopen|virgl|gpu|linker|fault|crash|139|SIGSEGV|display|backend|failed|error" | tail -30
done
echo ""

echo "[6/6] daemon.log 尾部 GPU 相关"
su -c "cat /data/data/$PKG/cache/daemon.log 2>/dev/null" | grep -iE "dlopen|virgl|gpu|linker|fault|crash|139|SIGSEGV|display|backend|failed" | tail -50
echo ""
echo "===== 结束: 把以上全部截图发我 (可分多张, 第2/3步最重要) ====="
