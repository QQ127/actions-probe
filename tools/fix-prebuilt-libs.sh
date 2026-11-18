#!/system/bin/sh
# 修复 VirGL 崩溃：让 DroidVM 冷启动重新解压 APK 内置的完整配套 prebuilt
# 根因：usr/lib 被补成 157340d8(错版本) + 缺 6 个依赖，与 crosvm(c3310ae3) 不配套
# 官方 prebuilt 内配套版 = libvirglrenderer 40b5edaa + 全套 17 个库
# 用法：
#   修复：  ... | sh
#   验证：  ... | sh -s -- verify
DATA="/data/data/cn.classfun.droidvm"
PKG="cn.classfun.droidvm"
MODE="$1"

if ! su -c "id" >/dev/null 2>&1; then echo "[错误] 需要 root"; exit 1; fi

if [ "$MODE" = "verify" ]; then
  echo "===== 验证 usr/lib 是否为官方配套版 ====="
  N=$(su -c "ls $DATA/usr/lib/*.so 2>/dev/null | wc -l")
  V=$(su -c "sha256sum $DATA/usr/lib/libvirglrenderer.so 2>/dev/null | cut -c1-16")
  G=$(su -c "sha256sum $DATA/usr/lib/libgfxstream_backend.so 2>/dev/null | cut -c1-16")
  C=$(su -c "sha256sum $DATA/usr/bin/crosvm 2>/dev/null | cut -c1-16")
  echo "  库总数        = $N      (期望 17)"
  echo "  libvirglrenderer = $V  (期望 40b5edaa)"
  echo "  libgfxstream     = $G  (期望 ed5395e4)"
  echo "  crosvm           = $C  (期望 c3310ae3)"
  su -c "test -f $DATA/usr/lib/libvulkan_freedreno.so" && echo "  libvulkan_freedreno = [有]" || echo "  libvulkan_freedreno = [缺!]"
  su -c "test -f $DATA/usr/lib/librutabaga_gfx_ffi.so" && echo "  librutabaga_gfx_ffi = [有]" || echo "  librutabaga_gfx_ffi = [缺!]"
  su -c "test -f $DATA/usr/lib/libepoxy.so" && echo "  libepoxy            = [有]" || echo "  libepoxy            = [缺!]"
  exit 0
fi

echo "===== 修复：让 App 冷启动重装官方配套 GPU 库 ====="
echo "[1/3] 当前状态:"
su -c "ls $DATA/usr/lib/*.so 2>/dev/null | wc -l" | sed 's/^/     库数: /'
su -c "sha256sum $DATA/usr/lib/libvirglrenderer.so 2>/dev/null | cut -c1-16" | sed 's/^/     virgl: /'

echo "[2/3] 删除 hash.json 并强制停止 App（触发冷启动完整重解压）"
su -c "cp -f $DATA/hash.json $DATA/hash.json.bak 2>/dev/null"
su -c "rm -f $DATA/hash.json"
su -c "am force-stop $PKG" 2>/dev/null
echo "     完成"

echo "[3/3] 接下来请按顺序操作："
echo ""
echo "   1) 从桌面图标重新打开 DroidVM（务必全新打开，别从后台切回）"
echo "   2) 等 30~90 秒：App 自动解压官方配套库（68MB 压缩包）"
echo "   3) 直接点 macOS 27.2 开机（图形配置不用改，保持 VirGL）"
echo ""
echo "   开完机后可验证：  ... | sh -s -- verify"
echo "   期望：库数 17，virgl=40b5edaa，crosvm=c3310ae3"
