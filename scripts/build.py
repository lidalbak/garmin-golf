#!/usr/bin/env python3
"""Build using an existing Garmin SDK. Never installs software or changes SDK files."""
import argparse
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]

def sdk_path():
    override = os.environ.get("GARMIN_SDK")
    if override:
        return Path(override).expanduser()
    cfg = Path.home() / "Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg"
    return Path(cfg.read_text().strip())

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--tests", action="store_true")
    p.add_argument("--run", action="store_true")
    p.add_argument("--typecheck", choices=("0","1","2","3"), default="1")
    args = p.parse_args()
    sdk = sdk_path()
    out = ROOT / "build"
    out.mkdir(exist_ok=True)
    key = out / "local-developer.der"
    if not key.exists():
        pem = out / "local-developer.pem"
        subprocess.run(["openssl", "genrsa", "-out", str(pem), "4096"], check=True, capture_output=True)
        pem.chmod(0o600)
        subprocess.run(["openssl", "pkcs8", "-topk8", "-inform", "PEM", "-outform", "DER", "-in", str(pem), "-out", str(key), "-nocrypt"], check=True)
        key.chmod(0o600)
    prg = out / ("GolfApp-tests.prg" if args.tests else "GolfApp.prg")
    cmd = [str(sdk / "bin/monkeyc"), "-f", str(ROOT / ("monkey-tests.jungle" if args.tests else "monkey.jungle")), "-d", "venu2", "-y", str(key), "-o", str(prg), "-w", "-l", args.typecheck]
    if args.tests:
        cmd.append("-t")
    subprocess.run(cmd, cwd=ROOT, check=True)
    if args.run:
        cmd = [str(sdk / "bin/monkeydo"), str(prg), "venu2"]
        if args.tests:
            cmd.append("-t")
        subprocess.run(cmd, cwd=ROOT, check=True)

if __name__ == "__main__":
    main()
