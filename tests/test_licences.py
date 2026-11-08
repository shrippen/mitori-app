"""The README names everything the app ships under a licence of its own (app/third_party)."""
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent


def test_readme_names_what_ships():
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    licence = readme[readme.index("## Lizenz"):]
    missing = [n for n in ("QtKeychain", "ZXing-C++", "libzueci", "librscpp", "Monocypher", "OpenSSL", "libomp") if n not in licence]
    assert missing == []


def test_licence_texts_ship():
    """Every text the README promises lies in app/third_party and is a resource of the app."""
    cmake = (ROOT / "app" / "CMakeLists.txt").read_text(encoding="utf-8")
    for text in ("openssl/ATTRIBUTION.txt", "openssl/LICENSE.txt", "libomp/ATTRIBUTION.txt", "libomp/LICENSE.TXT"):
        assert (ROOT / "app" / "third_party" / text).is_file(), text
        assert f"third_party/{text}" in cmake, text
