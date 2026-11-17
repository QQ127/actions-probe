#!/data/data/com.termux/files/usr/bin/sh
PKG=cn.classfun.droidvm
echo "===== 修复 daemon 连接（清理旧配对状态）====="
echo "[1] 停掉 App 和残留 daemon"
su -c "/system/bin/am force-stop $PKG" 2>/dev/null
su -c "pkill -9 droidvmd" 2>/dev/null
su -c "pkill -9 -f app_process64.*$PKG" 2>/dev/null
sleep 1
echo "[2] 删除旧配对文件(pid/token/port)"
su -c "rm -f /data/data/$PKG/run/droidvmd.pid /data/data/$PKG/run/droidvmd-token.txt /data/data/$PKG/run/droidvmd-port.txt" 2>/dev/null
su -c "ls -la /data/data/$PKG/run/ 2>/dev/null" | head -10
echo "[3] 重新打开 App(让 daemon 用新身份启动)"
su -c "/system/bin/monkey -p $PKG 1" 2>&1 | tail -1
sleep 8
echo "[4] 检查 daemon 是否重新起来"
su -c "ps -A" 2>/dev/null | grep -iE "droidvmd" | head -5
echo "[5] 抓连接日志"
su -c "/system/bin/logcat -d -v brief" 2>/dev/null | grep -iE "daemon started|DaemonHelper|droidvmd|Not connected" | tail -15
echo "===== 完成：回 App 看导入页是否还报 Not connected，截图发我 ====="
