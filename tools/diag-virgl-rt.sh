#!/data/data/com.termux/files/usr/bin/sh
MODE="$1"
LOG=/sdcard/vmcrash.log
URL='https://raw.githubusercontent.com/QQ127/macOS-DroidVM/main/tools/diag-virgl-rt.sh?x=$(date +%s)'

if [ "$MODE" = "setup" ]; then
  echo "===== [准备] 开始实时抓取 ====="
  su -c "/system/bin/logcat -c" 2>/dev/null
  su -c "rm -f $LOG" 2>/dev/null
  nohup su -c "/system/bin/logcat -v threadtime" > "$LOG" 2>&1 &
  sleep 2
  if [ -s "$LOG" ]; then
    echo "OK: 后台记录已启动 -> $LOG"
  else
    echo "备用方式启动..."
    su -c "nohup /system/bin/logcat -v threadtime -f $LOG >/dev/null 2>&1 &" 2>/dev/null
    sleep 2
  fi
  echo ""
  echo ">>> 现在切到 DroidVM, 确认图形页=VirGL, 开机, 等它崩溃(退出码139)"
  echo ">>> 崩溃后回到 Termux, 运行第二条命令(collect)"
  exit 0
fi

if [ "$MODE" = "collect" ]; then
  echo "===== [收集] 停止记录并分析 ====="
  su -c "pkill -f logcat" 2>/dev/null
  sleep 1
  echo ""
  echo "[A] 崩溃相关 dlopen/linker/virgl 报错(最关键)"
  su -c "cat $LOG 2>/dev/null" | grep -iE "dlopen|cannot locate|linker|virgl|gbm|freedreno|vulkan|libEGL|crosvm|virtio-mmio gpu|vm crash|SIGSEGV|fault addr|signal 11" | tail -150
  echo ""
  echo "[B] 崩溃行号定位(看前后文)"
  su -c "cat $LOG 2>/dev/null" | grep -n -iE "vm crash|SIGSEGV|fault addr|abort|virtio-mmio gpu" | tail -25
  echo ""
  echo "[C] 崩溃前 30 行原始上下文"
  LN=$(su -c "cat $LOG 2>/dev/null" | grep -n -iE "vm crash|SIGSEGV|fault addr" | tail -1 | cut -d: -f1)
  if [ -n "$LN" ]; then
    S=$((LN-30)); [ $S -lt 1 ] && S=1
    su -c "cat $LOG 2>/dev/null" | sed -n "${S},${LN}p"
  else
    echo "  未找到崩溃行(可能没触发崩溃, 或logcat记录为空)"
  fi
  echo ""
  echo "===== 结束: 把 [A][B][C] 全部截图发我 ====="
  exit 0
fi

echo "用法(两条命令, 中间去触发崩溃):"
echo "  1) 准备: curl -fsSL \"$URL\" | sh -s -- setup"
echo "  2) 收集: curl -fsSL \"$URL\" | sh -s -- collect"
