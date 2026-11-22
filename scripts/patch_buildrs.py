#!/usr/bin/env python3
"""Make gpu_display build for Android without libvncserver: compile stub VNC symbols instead of the real C bridge."""
import os

SYMS = [
    "vnc_server_create", "vnc_server_start", "vnc_server_has_input_events", "vnc_server_resize",
    "vnc_server_update_framebuffer", "vnc_server_destroy", "vnc_server_has_clients",
    "vnc_server_set_cursor", "vnc_server_set_cursor_pos", "vnc_server_offer_frame",
    "vnc_server_set_input_event_fd", "vnc_server_poll_input_event", "vnc_server_set_h264_rfb",
    "vnc_server_h264_rfb_for_client", "vnc_server_attach_consumer",
    "vnc_h264_rfb_create", "vnc_h264_rfb_destroy", "vnc_h264_rfb_detach",
    "vnc_h264_rfb_client_count", "vnc_h264_rfb_join_generation", "vnc_h264_rfb_reset",
    "vnc_h264_rfb_submit", "vnc_h264_rfb_set_caps", "vnc_h264_rfb_tick",
    "vnc_h264_rfb_display_hook",
]

stub_src = "/* generated: VNC is unused on this build */\n#include <stdint.h>\n"
for name in SYMS:
    stub_src += "uint64_t %s(void) { return 0; }\n" % name
open("gpu_display/src/vnc_stubs.c", "w").write(stub_src)

p = "gpu_display/build.rs"
s = open(p).read()
if "build_android_extras" in s:
    print("build.rs already patched")
    raise SystemExit(0)
helper = '''
fn build_android_extras() {
    let out_dir = env::var("OUT_DIR").unwrap();
    let mut build = cc::Build::new();
    build.include(&out_dir);
    build.flag("-std=gnu11");
    build.file("src/vnc_stubs.c");
    build.flag("-Wno-error");
    build.compile("android_extras");
    println!("cargo:rustc-link-lib=dylib=android");
    println!("cargo:rustc-link-lib=dylib=log");
}
fn main() {'''
s = s.replace("fn main() {", helper, 1)
s = s.replace('        "linux" | "android" => {',
              '        "android" => {\n            build_wayland();\n            build_android_extras();\n        }\n        "linux" => {', 1)
open(p, "w").write(s)
print("patched build.rs + wrote vnc_stubs.c")
