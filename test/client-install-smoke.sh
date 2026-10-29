#!/usr/bin/env bash
#
# client-install-smoke.sh — verify that tes3mp-easy-client-installer.sh picks
# the newest client release, checks the archive checksum and installs the
# binary, the icon and the menu entry without network access or root.
set -Eeuo pipefail
export LC_ALL=C

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/tes3mp-easy-client-install-test.XXXXXX")
trap 'rm -rf -- "$work"' EXIT

# The installer refuses root on purpose, so there is nothing to check there.
if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    printf 'client-install-smoke: SKIP (run as a regular user)\n'
    exit 0
fi

latest=tes3mp-easy-client-9.9.10-linux-amd64
older=tes3mp-easy-client-9.9.9-linux-amd64
fixture="$work/fixture"
mkdir -p "$work/bin" "$fixture" "$work/payload"

# The archive holds a stand-in client answering --version, which the installer
# prints at the end of a successful run.
cat >"$work/payload/tes3mp-easy-client" <<'CLIENT'
#!/usr/bin/env bash
printf 'tes3mp-easy-client test\n'
CLIENT
chmod +x "$work/payload/tes3mp-easy-client"

pack() {
    local name=$1
    tar -czf "$fixture/$name.tar.gz" -C "$work/payload" tes3mp-easy-client
    (
        cd "$fixture"
        sha256sum "$name.tar.gz" >"$name.tar.gz.sha256"
    )
}
pack "$latest"
pack "$older"

# The release tag carries the icon and the menu entry next to the archive.
printf 'PNG\n' >"$fixture/tes3mp-easy.png"
printf '[Desktop Entry]\nType=Application\nName=TES3MP Easy\n' \
    >"$fixture/tes3mp-easy.desktop"

cat >"$fixture/release.json" <<JSON
{
  "tag_name": "client-v9.9.9",
  "assets": [
    {
      "browser_download_url": "https://example.test/$older.tar.gz"
    }
  ]
}
JSON

# A server release and the moving aliases are listed first, the older client
# release comes last: the installer must pick the highest versioned client
# archive and ignore everything else.
cat >"$fixture/releases.json" <<JSON
[
  {
    "tag_name": "client-latest",
    "assets": [
      {
        "name": "tes3mp-easy-client-linux-amd64.tar.gz",
        "browser_download_url": "https://example.test/tes3mp-easy-client-linux-amd64.tar.gz"
      }
    ]
  },
  {
    "tag_name": "server-v9.9.9",
    "assets": [
      {
        "name": "tes3mp-easy-9.9.9-linux-amd64.tar.gz",
        "browser_download_url": "https://example.test/tes3mp-easy-9.9.9-linux-amd64.tar.gz"
      }
    ]
  },
  {
    "tag_name": "client-v9.9.9",
    "assets": [
      {
        "name": "$older.tar.gz",
        "browser_download_url": "https://example.test/$older.tar.gz"
      }
    ]
  },
  {
    "tag_name": "client-v9.9.10",
    "assets": [
      {
        "name": "$latest.tar.gz",
        "browser_download_url": "https://example.test/$latest.tar.gz"
      }
    ]
  }
]
JSON

cat >"$work/bin/curl" <<'CURL'
#!/usr/bin/env bash
set -Eeuo pipefail

out=""
url=""
while (($# > 0)); do
    case "$1" in
        -o)
            out=$2
            shift 2
            ;;
        --retry | --connect-timeout)
            shift 2
            ;;
        -*)
            shift
            ;;
        *)
            url=$1
            shift
            ;;
    esac
done

case "$url" in
    https://api.test/releases)
        cat "$TES3MP_EASY_TEST_FIXTURE/releases.json"
        ;;
    *releases/tags/client-v9.9.9)
        cat "$TES3MP_EASY_TEST_FIXTURE/release.json"
        ;;
    https://raw.githubusercontent.com/* | https://example.test/*)
        cp "$TES3MP_EASY_TEST_FIXTURE/${url##*/}" "$out"
        ;;
    *)
        printf 'curl: unexpected URL %s\n' "$url" >&2
        exit 22
        ;;
esac
CURL
chmod +x "$work/bin/curl"

fail() {
    printf 'client-install-smoke: FAIL: %s\n' "$*" >&2
    exit 1
}

# run_install <home> [VAR=value ...] — run the installer with its own HOME, so
# the test never touches the real ~/.local.
run_install() {
    local home=$1
    shift
    env HOME="$home" \
        XDG_DATA_HOME="$home/.local/share" \
        PATH="$work/bin:$PATH" \
        TES3MP_EASY_TEST_FIXTURE="$fixture" \
        "$@" bash "$repo_root/tes3mp-easy-client-installer.sh" 2>&1
}

home="$work/home"
mkdir -p "$home"
binary="$home/.local/bin/tes3mp-easy-client"
desktop="$home/.local/share/applications/tes3mp-easy.desktop"
icon="$home/.local/share/icons/hicolor/256x256/apps/tes3mp-easy.png"

out=$(run_install "$home" TES3MP_EASY_RELEASES_API=https://api.test/releases) ||
    fail "latest release: installer failed: $out"
case $out in
    *"$latest.tar.gz"*) ;;
    *) fail "latest release: expected $latest.tar.gz, got: $out" ;;
esac
for path in "$binary" "$desktop" "$icon"; do
    [[ -f $path ]] || fail "latest release: missing $path"
done
[[ -x $binary ]] || fail "latest release: $binary is not executable"
grep -q '^Name=TES3MP Easy$' "$desktop" ||
    fail "latest release: $desktop is not the release menu entry"

# TES3MP_EASY_CLIENT_VERSION pins an older release through the tag endpoint.
out=$(run_install "$work/home-pinned" TES3MP_EASY_CLIENT_VERSION=9.9.9) ||
    fail "pinned release: installer failed: $out"
case $out in
    *"$older.tar.gz"*) ;;
    *) fail "pinned release: expected $older.tar.gz, got: $out" ;;
esac

# A checksum mismatch must stop the install and leave no binary behind.
broken="$work/broken"
cp -a "$fixture" "$broken"
printf '%s  %s\n' "$(printf 'broken' | sha256sum | cut -d' ' -f1)" \
    "$latest.tar.gz" >"$broken/$latest.tar.gz.sha256"
if out=$(run_install "$work/home-broken" \
    TES3MP_EASY_TEST_FIXTURE="$broken" \
    TES3MP_EASY_RELEASES_API=https://api.test/releases); then
    fail "broken checksum: installer must fail, got: $out"
fi
case $out in
    *"checksum verification failed"*) ;;
    *) fail "broken checksum: unexpected error: $out" ;;
esac
[[ ! -e "$work/home-broken/.local/bin/tes3mp-easy-client" ]] ||
    fail "broken checksum: the binary must not be installed"

# A second run replaces the installed client instead of failing on it.
out=$(run_install "$home" TES3MP_EASY_RELEASES_API=https://api.test/releases) ||
    fail "second run: installer failed: $out"
"$binary" --version >/dev/null || fail "second run: the installed client does not run"
[[ -f $desktop && -f $icon ]] || fail "second run: menu entry or icon is gone"

printf 'client-install-smoke: PASS\n'

