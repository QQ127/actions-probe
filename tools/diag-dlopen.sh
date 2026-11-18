#!/data/data/com.termux/files/usr/bin/sh
echo "===== 精准抓 dlopen 报错 ====="
echo "[1] logcat 里的库加载报错(最关键)"
su -c "/system/bin/logcat -d -v brief" 2>/dev/null | grep -iE "dlopen failed|cannot locate|library .* not found|is not accessible|unexpected e_machine|needed by|dlopen" | grep -viE "media.codecs|apexcodecs|HWUI|Skia|adreno" | tail -60
echo ""
echo "[2] linker tag 全部输出"
su -c "/system/bin/logcat -d -v brief -s linker" 2>/dev/null | tail -40
echo ""
echo "[3] 手机 usr/lib 里的 GPU 相关库"
su -c "ls -l /data/data/cn.classfun.droidvm/usr/lib/ 2>/dev/null" | grep -iE "virgl|gfxstream|vulkan|gbm|EGL|GLES|crosvm|drm"
echo ""
echo "[4] usr/lib 库总数"
su -c "ls /data/data/cn.classfun.droidvm/usr/lib/ 2>/dev/null | wc -l"
echo ""
echo "[5] 崩溃进程最后 logcat 行"
su -c "/system/bin/logcat -d -v brief" 2>/dev/null | grep -iE "crosvm|crash fault|fatal signal" | tail -20
echo "===== 结束: 把 [1][2][3] 截图发我 ====="
