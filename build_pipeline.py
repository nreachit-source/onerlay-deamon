import subprocess
import struct
import re
import sys
import os
import shutil
import time

ZIG = r"C:\Users\GAME\Desktop\BUILD\iPhone_RE_Toolchain\zig\zig.exe"
PY3 = r"C:\Users\GAME\Desktop\BUILD\iPhone_RE_Toolchain\.venv\Scripts\python.exe"
BASE_DIR = r"C:\Users\GAME\Desktop\BUILD\onerlay-deamon"
SYS_PY = sys.executable

def run_remote_sh(script_text, timeout=25):
    import socket
    script_text = script_text.replace("\r\n", "\n")
    if not script_text.startswith("#!"):
        script_text = "#!/var/jb/bin/sh\nexport PATH=/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin\n" + script_text
    
    tmp_sh = os.path.join(BASE_DIR, "tmp_exec.sh")
    with open(tmp_sh, "w", newline="\n", encoding="utf-8") as f:
        f.write(script_text)
        
    res = subprocess.run([PY3, "-m", "pymobiledevice3", "afc", "push", tmp_sh, "/exec.sh"],
                         capture_output=True, text=True)
    if res.returncode != 0:
        return f"AFC push failed: {res.stderr}"
    
    s = socket.create_connection(('127.0.0.1', 1337), timeout=timeout)
    time.sleep(0.2)
    try:
        s.recv(4096)
    except Exception:
        pass
    
    cmd = "/var/jb/bin/sh /var/mobile/Media/exec.sh\n"
    s.sendall(cmd.encode('utf-8'))
    time.sleep(0.5)
    s.sendall(b"exit\n")
    s.settimeout(timeout)
    out = b""
    while True:
        try:
            b = s.recv(4096)
            if not b:
                break
            out += b
        except Exception:
            break
    s.close()
    return out.decode('utf-8', errors='replace')

def patch_macho_platform(path_in, path_out):
    with open(path_in, 'rb') as f:
        data = bytearray(f.read())
    ncmds = struct.unpack('<I', data[16:20])[0]
    offset = 32
    for _ in range(ncmds):
        cmd_type, cmdsize = struct.unpack('<II', data[offset:offset+8])
        if cmd_type == 0x32: # LC_BUILD_VERSION
            struct.pack_into('<III', data, offset + 8, 2, 0xc0000, 0xc0000)
            break
        offset += cmdsize
    with open(path_out, 'wb') as f:
        f.write(data)

def step1_compile():
    print("[1] Compiling SpringBoard overlay tweak with Zig...")
    tweak_src = os.path.join(BASE_DIR, "source", "tweak", "overlay_tweak.m")
    tweak_raw = os.path.join(BASE_DIR, "onerlay_tweak.raw")
    cmd_tweak = [ZIG, "cc", "-target", "aarch64-macos", "-shared", "-O2", "-Wl,-undefined,dynamic_lookup", tweak_src, "-o", tweak_raw]
    res = subprocess.run(cmd_tweak, capture_output=True, text=True)
    if res.returncode != 0:
        print("Tweak compilation failed:\n", res.stderr)
        return False
    print("    Tweak compiled successfully to", tweak_raw)

    print("[2] Compiling background daemon with Zig...")
    daemon_src = os.path.join(BASE_DIR, "source", "daemon", "main.c")
    daemon_raw = os.path.join(BASE_DIR, "onerlaydaemon.raw")
    cmd_daemon = [ZIG, "cc", "-target", "aarch64-macos", "-std=c11", "-O2", daemon_src, "-o", daemon_raw]
    res = subprocess.run(cmd_daemon, capture_output=True, text=True)
    if res.returncode != 0:
        print("Daemon compilation failed:\n", res.stderr)
        return False
    print("    Daemon compiled successfully to", daemon_raw)

    print("[3] Patching LC_BUILD_VERSION platform to 2 (iOS)...")
    tweak_patched = os.path.join(BASE_DIR, "onerlay_tweak.dylib")
    daemon_patched = os.path.join(BASE_DIR, "onerlaydaemon")
    patch_macho_platform(tweak_raw, tweak_patched)
    patch_macho_platform(daemon_raw, daemon_patched)
    print("    Patched binaries successfully.")
    return True

def step2_sign_and_package():
    print("[4] Pushing binaries to device for ad-hoc signing & trustcache...")
    tweak_patched = os.path.join(BASE_DIR, "onerlay_tweak.dylib")
    daemon_patched = os.path.join(BASE_DIR, "onerlaydaemon")
    
    subprocess.run([PY3, "-m", "pymobiledevice3", "afc", "push", tweak_patched, "/onerlay_tweak_raw.dylib"], check=True)
    subprocess.run([PY3, "-m", "pymobiledevice3", "afc", "push", daemon_patched, "/onerlaydaemon_raw"], check=True)
    
    sign_script = """
ldid -S /var/mobile/Media/onerlay_tweak_raw.dylib
ldid -h /var/mobile/Media/onerlay_tweak_raw.dylib
ldid -S /var/mobile/Media/onerlaydaemon_raw
ldid -h /var/mobile/Media/onerlaydaemon_raw
"""
    out = run_remote_sh(sign_script)
    print("    Signing output:\n", out)
    
    cdhashes = re.findall(r"CDHash=([0-9a-fA-F]{40})", out)
    for cdh in cdhashes:
        cdh_low = cdh.lower()
        res_tc = run_remote_sh(f"/var/jb/basebin/jbctl trustcache add {cdh_low}")
        print(f"    Added trustcache for {cdh_low}: {res_tc.strip()}")
        
    print("[5] Pulling signed binaries back for deb packaging...")
    pkg_tweak = os.path.join(BASE_DIR, "package", "var", "jb", "usr", "lib", "TweakInject", "onerlay_tweak.dylib")
    pkg_daemon = os.path.join(BASE_DIR, "package", "var", "jb", "usr", "local", "libexec", "onerlaydaemon")
    os.makedirs(os.path.dirname(pkg_tweak), exist_ok=True)
    os.makedirs(os.path.dirname(pkg_daemon), exist_ok=True)
    
    subprocess.run([PY3, "-m", "pymobiledevice3", "afc", "pull", "/onerlay_tweak_raw.dylib", pkg_tweak], check=True)
    subprocess.run([PY3, "-m", "pymobiledevice3", "afc", "pull", "/onerlaydaemon_raw", pkg_daemon], check=True)
    
    # Copy plist filter
    shutil.copy2(os.path.join(BASE_DIR, "source", "tweak", "onerlay_tweak.plist"),
                 os.path.join(BASE_DIR, "package", "var", "jb", "usr", "lib", "TweakInject", "onerlay_tweak.plist"))
    
    print("[6] Building Debian package...")
    import build_deb
    deb_path = build_deb.main()
    return deb_path

def step3_deploy_and_verify(deb_path):
    print("[7] Pushing .deb package to iPhone...")
    deb_name = os.path.basename(deb_path)
    subprocess.run([PY3, "-m", "pymobiledevice3", "afc", "push", deb_path, f"/{deb_name}"], check=True)
    
    print("[8] Installing package via dpkg on iPhone...")
    install_script = f"""
dpkg -i /var/mobile/Media/{deb_name}
"""
    out_install = run_remote_sh(install_script)
    print("    Install output:\n", out_install)
    
    print("[9] Triggering SpringBoard reload (sbreload)...")
    reload_script = """
launchctl kickstart -k system/com.local.onerlaydaemon
sbreload
"""
    out_reload = run_remote_sh(reload_script)
    print("    Reload output:\n", out_reload)
    
    print("[10] Waiting 5 seconds for SpringBoard to restart with overlay...")
    time.sleep(5)
    
    print("[11] Capturing on-device screenshot to verify floating overlay...")
    screenshot_path = os.path.join(BASE_DIR, "overlay_screen.png")
    subprocess.run([PY3, "-m", "pymobiledevice3", "developer", "screenshot", screenshot_path], check=True)
    print("    Screenshot saved to:", screenshot_path)
    
    print("[12] Checking syslog for [ONERLAY] messages...")
    log_check = run_remote_sh("tail -n 25 /var/mobile/Downloads/onerlay_daemon.log; ps -ef | grep SpringBoard | grep -v grep")
    print("    Status check:\n", log_check)
    return True

if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    if step1_compile():
        deb = step2_sign_and_package()
        if deb:
            step3_deploy_and_verify(deb)
