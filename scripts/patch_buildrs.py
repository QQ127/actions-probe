#!/usr/bin/env python3
"""Patch gpu_display/build.rs so an Android cargo build compiles the C helpers that soong normally builds."""
import os
p = 'gpu_display/build.rs'
s = open(p).read()
if 'build_android_extras' in s:
    print('already patched')
    raise SystemExit(0)
helper = '''
fn build_android_extras() {
    let out_dir = env::var("OUT_DIR").unwrap();
    let mut build = cc::Build::new();
    build.include(&out_dir);
    build.flag("-std=gnu11");
    build.file("src/vnc_h264_rfb.c");
    build.file("src/vnc_server_bridge.c");
    build.compile("android_extras");
    println!("cargo:rustc-link-lib=dylib=android");
    println!("cargo:rustc-link-lib=dylib=log");
    println!("cargo:rustc-link-lib=dylib=nativewindow");
    println!("cargo:rustc-link-lib=dylib=mediandk");
}
fn main() {'''
s = s.replace('fn main() {', helper, 1)
s = s.replace('        "linux" | "android" => {',
              '        "android" => {\n            build_wayland();\n            build_android_extras();\n        }\n        "linux" => {', 1)
open(p, 'w').write(s)
print('patched build.rs')
