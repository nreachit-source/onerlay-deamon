from __future__ import annotations
import gzip
import hashlib
import pathlib
import shutil

HERE = pathlib.Path(__file__).resolve().parent
DEB_NAME = "com.local.onerlaydaemon_1.0.0_iphoneos-arm64.deb"
SOURCE = HERE / DEB_NAME
POOL = HERE / "debs"
DEB = POOL / DEB_NAME

def digest(path: pathlib.Path, algorithm: str) -> str:
    hasher = hashlib.new(algorithm)
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()

def checksum_lines(path: pathlib.Path) -> tuple[str, str, str]:
    size = path.stat().st_size
    return (
        f" {digest(path, 'md5')} {size:16d} {path.name}",
        f" {digest(path, 'sha1')} {size:16d} {path.name}",
        f" {digest(path, 'sha256')} {size:16d} {path.name}",
    )

def main() -> None:
    POOL.mkdir(exist_ok=True)
    if SOURCE.exists():
        shutil.copy2(SOURCE, DEB)
    elif not DEB.exists():
        print(f"Error: Neither {SOURCE} nor {DEB} exists!")
        return

    package = f"""Package: com.local.onerlaydaemon
Name: Onerlay Daemon & System Overlay
Version: 1.0.0
Architecture: iphoneos-arm64
Description: System-wide floating overlay button and background daemon for iOS. Shows floating draggable button that expands into confirmation card.
Maintainer: nreachit-source <nreachit-source@users.noreply.github.com>
Author: nreachit-source
Section: Tweaks
Depends: mobilesubstrate
Filename: debs/{DEB.name}
Size: {DEB.stat().st_size}
MD5sum: {digest(DEB, 'md5')}
SHA1: {digest(DEB, 'sha1')}
SHA256: {digest(DEB, 'sha256')}

"""
    packages = HERE / "Packages"
    packages.write_text(package, encoding="utf-8", newline="\n")
    packages_gz = HERE / "Packages.gz"
    with packages.open("rb") as source, packages_gz.open("wb") as compressed:
        with gzip.GzipFile(filename="", mode="wb", fileobj=compressed, mtime=0) as output:
            shutil.copyfileobj(source, output)

    md5_packages, sha1_packages, sha256_packages = checksum_lines(packages)
    md5_gz, sha1_gz, sha256_gz = checksum_lines(packages_gz)
    release = f"""Origin: Onerlay Daemon
Label: Onerlay Daemon
Suite: stable
Codename: ios
Architectures: iphoneos-arm64
Components: main
Description: Official Sileo repository for Onerlay Daemon & System-wide iOS Overlay
MD5Sum:
{md5_packages}
{md5_gz}
SHA1:
{sha1_packages}
{sha1_gz}
SHA256:
{sha256_packages}
{sha256_gz}
"""
    (HERE / "Release").write_text(release, encoding="utf-8", newline="\n")
    print("Sileo repository metadata generated successfully:")
    print(f"  - Packages: {packages.stat().st_size} bytes")
    print(f"  - Packages.gz: {packages_gz.stat().st_size} bytes")
    print(f"  - Release: {(HERE / 'Release').stat().st_size} bytes")

if __name__ == "__main__":
    main()
