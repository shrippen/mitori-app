"""The APK can speak HTTPS: Qt's OpenSSL plugin is there, and so is OpenSSL itself.

Qt loads libssl_3.so and libcrypto_3.so at runtime (dlopen), so no build step misses them.
Without them every HTTPS request fails on the phone with "TLS initialization failed":
no manifest, no video bundles, no course calendar (0.1.0 shipped that way).
Run: python3 tests/check_apk_tls.py <apk>   (scripts/build-android.sh does)
"""

import sys
import zipfile

ABI_DIR = "lib/arm64-v8a/"
PLUGIN = "libplugins_tls_qopensslbackend_arm64-v8a.so"
OPENSSL = ("libssl_3.so", "libcrypto_3.so")


def main(apk):
    with zipfile.ZipFile(apk) as z:
        packed = {n[len(ABI_DIR):] for n in z.namelist() if n.startswith(ABI_DIR)}

    missing = [lib for lib in (PLUGIN, *OPENSSL) if lib not in packed]
    for lib in missing:
        print(f"{lib} not in the APK: no HTTPS on the phone", file=sys.stderr)
    return 1 if missing else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
