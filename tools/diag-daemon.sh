#!/data/data/com.termux/files/usr/bin/sh
PKG=cn.classfun.droidvm
echo "===== DroidVM daemon 诊断 ====="
echo "[1/4] 当前安装信息(确认是不是新版)"
su -c "/system/bin/dumpsys package $PKG" 2>/dev/null | grep -iE "versionName|lastUpdateTime" | head -4
echo "  APK路径:"
su -c "/system/bin/pm path $PKG" 2>/dev/null | head -2
echo "[2/4] 强制重启App并清日志"
su -c "/system/bin/am force-stop $PKG" 2>/dev/null
su -c "/system/bin/logcat -c" 2>/dev/null
su -c "/system/bin/monkey -p $PKG 1" 2>&1 | tail -2
sleep 10
echo "[3/4] daemon启动日志(关键)"
su -c "/system/bin/logcat -d -v brief" 2>/dev/null | grep -iE "droidvmd|DaemonHelper|Not connected|app_process|Exception|denied|avc:|daemon" | tail -70
echo "[4/4] 相关进程"
su -c "ps -A" 2>/dev/null | grep -iE "droidvm|app_process" | head -10
echo "===== 结束：把以上全部截图发我 ====="
