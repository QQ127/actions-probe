#!/system/bin/sh
# DroidVM macOS VM —— 库完整性 + 环境自检（只读，不改任何东西）
# 用法（Termux）：
#   su -c "sh /data/data/com.termux/files/home/v.sh"
D=/data/data/cn.classfun.droidvm
BAD=0
MISS=0

echo "================ DroidVM 自检 $(date '+%m-%d %H:%M') ================"
echo "系统: Android $(getprop ro.build.version.release) (API $(getprop ro.build.version.sdk)) $(getprop ro.product.cpu.abi)"
echo "内核: $(uname -r)"
echo "页大小: $(getconf PAGE_SIZE)"
echo "data剩余: $(df -h /data 2>/dev/null | tail -1 | awk '{print $4}')"
echo "内存可用: $(grep MemAvailable /proc/meminfo | awk '{printf "%.0fMB", $2/1024}')"

echo "---- 内核模块 ----"
for m in gunyah_host_share udmabuf gh_unmovable nproc_guard; do
  if grep -q "^$m " /proc/modules 2>/dev/null; then echo "已加载  $m"; else echo "未加载  $m"; fi
done

echo "---- usr/bin/crosvm ----"
if [ -f $D/usr/bin/crosvm ]; then
  H=$(sha256sum $D/usr/bin/crosvm | cut -c1-16)
  if [ "$H" = "c3310ae33402d8bd" ]; then echo "OK    crosvm $H"; else echo "脏    crosvm $H 应为 c3310ae33402d8bd"; BAD=$((BAD+1)); fi
else
  echo "缺失  usr/bin/crosvm"; MISS=$((MISS+1))
fi

echo "---- usr/lib（应 17 个 .so）----"
N=$(ls $D/usr/lib/*.so 2>/dev/null | wc -l)
echo "实际: $N"
check() {
  f=$D/usr/lib/$2
  if [ ! -f "$f" ]; then echo "缺失  $2"; MISS=$((MISS+1)); return; fi
  h=$(sha256sum "$f" | cut -c1-16)
  if [ "$h" = "$1" ]; then echo "OK    $2"; else echo "脏    $2  $h 应为 $1"; BAD=$((BAD+1)); fi
}
check 86694d140d27aa94 android.hardware.graphics.common-V7-ndk.so
check 87b31a3584d500c3 libepoxy.so
check 7996e9aa46f11cb5 libffi.so
check ed5395e443fb2b3f libgfxstream_backend.so
check cc5eabe2ab7ac2d1 libgio-2.0.so
check bbce0a767e85eaed libglib-2.0.so
check f7ca8c378832709c libgmodule-2.0.so
check 76eaf9ce0fa0c742 libgobject-2.0.so
check 634c477bb82b6b05 libintl.so
check 1f971450584ed981 libpcre2-8.so
check 63f9c470fe9a786a libpixman-1.so
check aed0424b7c26f02d librutabaga_gfx_ffi.so
check 0225a0b988cf3e82 libslirp.so
check 28f17d8d7d82155c libusb-1.0.so
check 40b5edaa7c722b80 libvirglrenderer.so
check eaf7d95c7f4fe0ca libvncserver.so
check 829655e69d4620c2 libvulkan_freedreno.so

echo "---- 结论 ----"
if [ $BAD -eq 0 ] && [ $MISS -eq 0 ] && [ "$N" = "17" ]; then
  echo "CLEAN  库与官方 prebuilt 完全一致，崩溃不在库上"
else
  echo "DIRTY  脏=$BAD 缺=$MISS 实际文件数=$N"
  echo "修复命令："
  echo "  su -c \"rm -rf $D/usr/lib/*.so; rm -f $D/hash.json; am force-stop cn.classfun.droidvm\""
  echo "  然后冷启动 App，停在启动页等 90 秒不要切走，再跑本脚本复查"
fi
echo "================ 结束 ================"
