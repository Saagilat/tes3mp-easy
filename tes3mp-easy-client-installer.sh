#!/usr/bin/env bash
#
# tes3mp-easy-client-installer.sh — install the latest TES3MP Easy client for
# the current user. Everything stays inside the user's home, no root needed:
#   - find the newest client release on GitHub;
#   - verify the archive checksum;
#   - unpack the binary into ~/.local/bin;
#   - install the icon and the menu entry from the same release tag.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/tes3mp-easy-client-installer.sh | bash
#
# The pipe works in bash, zsh and fish; `bash <(curl …)` is bash process
# substitution and fish rejects it.
#
# TES3MP_EASY_CLIENT_VERSION pins a client release (for example 0.3.0).
set -Eeuo pipefail
export LC_ALL=C

readonly REPO="Saagilat/tes3mp-easy"
# Releases are split into server-v<version> and client-v<version> channels and
# the <channel>-latest aliases carry archives without a version in the name, so
# the newest GitHub release is not necessarily a client release: scan the list
# and take the newest versioned client archive.
readonly RELEASES_API="https://api.github.com/repos/${REPO}/releases?per_page=30"
readonly TAGS_API="https://api.github.com/repos/${REPO}/releases/tags"
readonly TAGS_RAW="https://raw.githubusercontent.com/${REPO}/refs/tags"
readonly CLIENT_ASSET='https://[^"]+/tes3mp-easy-client-[0-9][^"]*-linux-amd64\.tar\.gz"'
readonly BINARY=tes3mp-easy-client
readonly DESKTOP=tes3mp-easy.desktop
readonly ICON=tes3mp-easy.png

fail() {
    printf 'client-install: %s\n' "$*" >&2
    exit 1
}

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    fail "run as your own user, not root or sudo"
fi

for tool in curl tar sha256sum mktemp grep sed sort install; do
    command -v "$tool" >/dev/null 2>&1 || fail "$tool is required"
done

fetch() {
    curl -fsSL --retry 2 --connect-timeout 10 "$@"
}

fetch_json() {
    fetch "$1"
}

# The client pattern cannot match the server archive (tes3mp-easy-<v>-…) or the
# versionless client-latest alias (a digit must follow "tes3mp-easy-client-").
client_asset() {
    local urls
    urls=$(printf '%s\n' "$1" | grep -oE "$CLIENT_ASSET" | sed 's/"$//' || true)
    [[ -n $urls ]] || return 0
    # The release list order is not guaranteed, so pick the highest version.
    printf '%s\n' "$urls" |
        sed -E 's#.*/tes3mp-easy-client-(.*)-linux-amd64\.tar\.gz#\1 &#' |
        sort -V -k1,1 |
        tail -n 1 |
        cut -d' ' -f2-
}

asset_url=""
if [[ -n ${TES3MP_EASY_RELEASES_API:-} ]]; then
    release_json=$(fetch_json "$TES3MP_EASY_RELEASES_API") ||
        fail "cannot read release metadata from $TES3MP_EASY_RELEASES_API"
    asset_url=$(client_asset "$release_json")
    [[ -n $asset_url ]] || fail "no client release found in $TES3MP_EASY_RELEASES_API"
elif [[ -n ${TES3MP_EASY_CLIENT_VERSION:-} ]]; then
    version=${TES3MP_EASY_CLIENT_VERSION#v}
    if ! [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
        fail "TES3MP_EASY_CLIENT_VERSION must look like 0.3.0, got $TES3MP_EASY_CLIENT_VERSION"
    fi
    printf 'TES3MP Easy: looking up the client release %s...\n' "$version"
    release_json=$(fetch_json "$TAGS_API/client-v${version}") ||
        fail "cannot read release metadata for client-v${version}"
    asset_url=$(client_asset "$release_json")
    [[ -n $asset_url ]] ||
        fail "client release $version has no tes3mp-easy-client-${version}-linux-amd64.tar.gz asset"
else
    printf 'TES3MP Easy: looking up the latest client release...\n'
    release_json=$(fetch_json "$RELEASES_API") ||
        fail "cannot read release metadata from $RELEASES_API"
    asset_url=$(client_asset "$release_json")
    [[ -n $asset_url ]] || fail "no client release found in $RELEASES_API"
fi

archive_name=${asset_url##*/}
release_name=${archive_name%.tar.gz}
if [[ -z $archive_name || $release_name == "$archive_name" ]]; then
    fail "unexpected release asset name: $archive_name"
fi

# The icon and the menu entry are taken from the tag the archive comes from, so
# one installed client always belongs to one release.
release_ref=client-latest
case $asset_url in
    */releases/download/*)
        release_ref=${asset_url#*/releases/download/}
        release_ref=${release_ref%%/*}
        ;;
esac

# Executables live in ~/.local/bin, the rest follows XDG_DATA_HOME.
bin_dir="$HOME/.local/bin"
data_home=${XDG_DATA_HOME:-$HOME/.local/share}
applications_dir="$data_home/applications"
icon_dir="$data_home/icons/hicolor/256x256/apps"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/tes3mp-easy-client-install.XXXXXX")
staged=""
trap 'rm -rf -- "$tmp"; if [[ -n ${staged:-} ]]; then rm -f -- "$staged"; fi' EXIT
archive="$tmp/$archive_name"

printf 'TES3MP Easy: downloading %s...\n' "$archive_name"
fetch "$asset_url" -o "$archive" ||
    fail "cannot download $asset_url"
fetch "$asset_url.sha256" -o "$archive.sha256" ||
    fail "cannot download $asset_url.sha256"
mkdir -p "$tmp/assets"
for file in "$ICON" "$DESKTOP"; do
    fetch "$TAGS_RAW/$release_ref/assets/$file" -o "$tmp/assets/$file" ||
        fail "release $release_ref has no assets/$file; releases before the installer have none"
done

(
    cd "$tmp"
    sha256sum -c "$archive_name.sha256"
) || fail "release checksum verification failed"

tar -xzf "$archive" -C "$tmp" || fail "cannot extract $archive_name"

# The archive holds the binary at its root today; accept a versioned top-level
# directory as well so the script keeps working if the layout ever changes.
binary=""
for candidate in "$tmp/$BINARY" "$tmp"/*/"$BINARY"; do
    if [[ -f $candidate ]]; then
        binary=$candidate
        break
    fi
done
[[ -n $binary ]] || fail "$archive_name has no $BINARY binary"

mkdir -p "$bin_dir" "$applications_dir" "$icon_dir"
desktop_new=0
[[ -e $applications_dir/$DESKTOP ]] || desktop_new=1
staged="$bin_dir/.${BINARY}.new.$$"
install -m 0755 "$binary" "$staged"
mv -f -- "$staged" "$bin_dir/$BINARY"   # atomic replace, no ETXTBSY
staged=""
install -m 0644 "$tmp/assets/$ICON" "$icon_dir/$ICON"

# Panels and launchers spawn Exec without a login shell, so the PATH they see is
# the session one: on Xfce it has no ~/.local/bin. Write the absolute path of the
# binary that was just installed instead of relying on PATH.
installed_bin=$bin_dir/$BINARY
escaped_bin=${installed_bin//\\/\\\\}
escaped_bin=${escaped_bin//&/\\&}
entry="$tmp/assets/$DESKTOP.installed"
sed -e "s|^Exec=${BINARY}|Exec=${escaped_bin}|" "$tmp/assets/$DESKTOP" >"$entry" ||
    fail "cannot rewrite Exec in $DESKTOP"
grep -qF "Exec=$installed_bin" "$entry" ||
    fail "assets/$DESKTOP has no Exec=$BINARY line"
install -m 0644 "$entry" "$applications_dir/$DESKTOP"

# Both helpers come from xdg-utils and are optional: a missing tool only means
# the desktop and icon caches are refreshed later, on the next login.
if command -v xdg-icon-resource >/dev/null 2>&1; then
    xdg-icon-resource forceupdate >/dev/null 2>&1 || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$applications_dir" >/dev/null 2>&1 || true
fi

printf '\nTES3MP Easy: client installed\n'
printf '  binary: %s\n' "$bin_dir/$BINARY"
printf '  menu:   %s\n' "$applications_dir/$DESKTOP"
if installed=$("$bin_dir/$BINARY" --version 2>/dev/null); then
    printf '  version: %s\n' "$installed"
fi
if [[ $desktop_new -eq 1 ]]; then
    printf '  note: restart the panel to pick up the menu entry'
    case ${XDG_CURRENT_DESKTOP:-} in
        *XFCE*) printf ' (Xfce: xfce4-panel -r)' ;;
    esac
    printf '\n'
fi
case ":$PATH:" in
    *":$bin_dir:"*) ;;
    *) printf '  note: add %s to PATH to run %s from a shell: export PATH="%s:$PATH"\n' "$bin_dir" "$BINARY" "$bin_dir" ;;
esac
