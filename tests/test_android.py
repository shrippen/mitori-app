"""The Android manifest asks for what the app uses (androiddeployqt adds nothing without its
placeholder): the course calendar and the video bundles need the network. Auto Backup leaves out
the bundles (decrypted videos and their keys): hundreds of MB would stop the whole backup."""
import xml.etree.ElementTree as ET
from pathlib import Path

MANIFEST = Path(__file__).resolve().parent.parent / "app" / "android" / "AndroidManifest.xml"
ANDROID = "{http://schemas.android.com/apk/res/android}name"


def test_internet_permission():
    root = ET.parse(MANIFEST).getroot()
    rights = {p.get(ANDROID) for p in root.iter("uses-permission")}
    assert "android.permission.INTERNET" in rights
    assert "android.permission.ACCESS_NETWORK_STATE" in rights      # Wi-Fi only downloads
    assert {"android.permission.CAMERA", "android.permission.RECORD_AUDIO"} <= rights   # photos, voice notes
    # Not required: the app installs on devices without a camera or microphone.
    features = {f.get(ANDROID): f.get("{http://schemas.android.com/apk/res/android}required") for f in root.iter("uses-feature")}
    assert features.get("android.hardware.camera") == "false" and features.get("android.hardware.microphone") == "false"


RES = MANIFEST.parent / "res" / "xml"
TOOLS = "{http://schemas.android.com/apk/res/android}"


def test_backup_without_bundles():
    app = ET.parse(MANIFEST).getroot().find("application")
    # Android 12+ reads dataExtractionRules, older ones fullBackupContent.
    rules = app.get(TOOLS + "dataExtractionRules")
    content = app.get(TOOLS + "fullBackupContent")
    assert rules == "@xml/data_extraction_rules" and content == "@xml/backup_rules"
    for sections, name in ((["cloud-backup", "device-transfer"], "data_extraction_rules.xml"), ([None], "backup_rules.xml")):
        root = ET.parse(RES / name).getroot()
        for section in sections:
            scope = root if section is None else root.find(section)
            excluded = {(e.get("domain"), e.get("path")) for e in scope.iter("exclude")}
            assert ("file", "bundles/") in excluded, (name, section)


def test_backup_without_account():
    """konto.ini (the password if no key store took it) and the Keystore's encrypted copy lie in
    files/sync/: never in a backup or a device transfer."""
    rules = ET.parse(RES / "data_extraction_rules.xml").getroot()
    for section in ("cloud-backup", "device-transfer"):
        assert ("file", "sync/") in {(e.get("domain"), e.get("path")) for e in rules.find(section).iter("exclude")}
    old = ET.parse(RES / "backup_rules.xml").getroot()
    assert ("file", "sync/") in {(e.get("domain"), e.get("path")) for e in old.iter("exclude")}


def test_cloud_backup_without_media():
    """Photos and voice notes (files/medien/) stay out of the cloud backup: past 25 MB Android backs
    up nothing, the practice log and the notes neither. A device transfer takes them along."""
    rules = ET.parse(RES / "data_extraction_rules.xml").getroot()
    cloud = {(e.get("domain"), e.get("path")) for e in rules.find("cloud-backup").iter("exclude")}
    transfer = {(e.get("domain"), e.get("path")) for e in rules.find("device-transfer").iter("exclude")}
    assert ("file", "medien/") in cloud
    assert ("file", "medien/") not in transfer
    old = {(e.get("domain"), e.get("path")) for e in ET.parse(RES / "backup_rules.xml").getroot().iter("exclude")}
    assert ("file", "medien/") in old


def test_share_provider():
    """Sharing a notebook: the provider is private, serves the export folder only and has the
    authority and folder platform/sharefile.cpp asks for (a mismatch throws at runtime, on the phone)."""
    app = ET.parse(MANIFEST).getroot().find("application")
    provider = app.find("provider")
    assert provider.get(ANDROID) == "androidx.core.content.FileProvider"
    assert provider.get(TOOLS + "exported") == "false" and provider.get(TOOLS + "grantUriPermissions") == "true"
    assert provider.get(TOOLS + "authorities") == "${applicationId}.fileprovider"
    data = provider.find("meta-data")
    assert data.get(ANDROID) == "android.support.FILE_PROVIDER_PATHS" and data.get(TOOLS + "resource") == "@xml/share_paths"
    paths = list(ET.parse(RES / "share_paths.xml").getroot())
    assert [(p.tag, p.get("path")) for p in paths] == [("cache-path", "export/")]
    code = (MANIFEST.parent.parent / "platform" / "sharefile.cpp").read_text()
    assert 'kAuthority = ".fileprovider"' in code and 'kFolder = "/export"' in code


def test_apk_tls_check(tmp_path):
    """tests/check_apk_tls.py (run by scripts/build-android.sh) fails an APK without OpenSSL, as 0.1.0 was."""
    import importlib.util
    import zipfile

    spec = importlib.util.spec_from_file_location("check_apk_tls", Path(__file__).parent / "check_apk_tls.py")
    check = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(check)

    def apk(*libs):
        path = tmp_path / f"{len(libs)}.apk"
        with zipfile.ZipFile(path, "w") as z:
            for lib in libs:
                z.writestr(check.ABI_DIR + lib, b"")
        return str(path)

    assert check.main(apk(check.PLUGIN)) == 1
    assert check.main(apk(check.PLUGIN, "libssl_3.so")) == 1
    assert check.main(apk(check.PLUGIN, *check.OPENSSL)) == 0


# The launch shows a plain ground, not Android's default window background: the activity's theme
# paints it in Leinen's ground (the default style), Kante's `light.ground` (KantePalette.qml).
VALUES = MANIFEST.parent / "res" / "values"
PALETTE = MANIFEST.parents[1] / "qml" / "Kante" / "KantePalette.qml"


def test_launch_ground():
    activity = ET.parse(MANIFEST).getroot().find("application").find("activity")
    theme = activity.get(TOOLS + "theme")
    assert theme == "@style/Theme.Mitori.Launch"
    styles = ET.parse(VALUES / "styles.xml").getroot()
    style = next(s for s in styles.iter("style") if s.get("name") == "Theme.Mitori.Launch")
    items = {i.get("name"): i.text for i in style.iter("item")}
    assert items["android:windowBackground"] == "@color/launch_ground"
    colors = {c.get("name"): c.text for c in ET.parse(VALUES / "colors.xml").getroot().iter("color")}
    light = PALETTE.read_text().split("readonly property QtObject light")[1]
    ground = light.split("ground:")[1].split('"')[1]
    assert colors["launch_ground"].lower() == ground.lower()
