from __future__ import annotations
import io
import pathlib
import tarfile

ROOT = pathlib.Path(__file__).resolve().parent
PACKAGE = ROOT / "package"

def add_tree(archive: tarfile.TarFile, source: pathlib.Path, prefix: str) -> None:
    for path in sorted(source.rglob("*")):
        relative = path.relative_to(source).as_posix()
        name = f"./{prefix}/{relative}" if prefix else f"./{relative}"
        info = archive.gettarinfo(str(path), arcname=name)
        info.uid = 0
        info.gid = 0
        info.uname = "root"
        info.gname = "wheel"
        if path.is_dir():
            info.mode = 0o755
            archive.addfile(info)
            continue

        executable = (
            relative in {"postinst", "prerm"}
            or relative.endswith("/onerlaydaemon")
            or relative.endswith(".dylib")
        )
        info.mode = 0o755 if executable else 0o644
        with path.open("rb") as handle:
            archive.addfile(info, handle)

def create_tar(output: pathlib.Path, source: pathlib.Path, prefix: str = "") -> None:
    with tarfile.open(output, "w:gz", format=tarfile.GNU_FORMAT) as archive:
        add_tree(archive, source, prefix)

def write_ar(output: pathlib.Path, members: list[pathlib.Path]) -> None:
    with output.open("wb") as archive:
        archive.write(b"!<arch>\n")
        for member in members:
            data = member.read_bytes()
            name = (member.name + "/").encode("ascii")
            header = (
                name.ljust(16)
                + b"0".ljust(12)
                + b"0".ljust(6)
                + b"0".ljust(6)
                + b"100644".ljust(8)
                + str(len(data)).encode("ascii").ljust(10)
                + b"`\n"
            )
            archive.write(header)
            archive.write(data)
            if len(data) % 2:
                archive.write(b"\n")

def main() -> str:
    control_tar = ROOT / "control.tar.gz"
    data_tar = ROOT / "data.tar.gz"
    output = ROOT / "com.local.onerlaydaemon_1.0.0_iphoneos-arm64.deb"
    create_tar(control_tar, PACKAGE / "DEBIAN")
    create_tar(data_tar, PACKAGE / "var", "var")
    write_ar(output, [ROOT / "debian-binary", control_tar, data_tar])
    print(f"Created package: {output} ({output.stat().st_size} bytes)")
    return str(output)

if __name__ == "__main__":
    main()
