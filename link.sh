#!/usr/bin/env bash
# link.sh
# Tao symlink tu vi tri config that (WSL/Linux) tro vao file trong repo dotfiles.
# Idempotent: chay lai nhieu lan khong loi, tu backup file cu neu no khong phai la symlink.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link_dotfile() {
    local link_path="$1"
    local target_path="$2"

    if [ ! -e "$target_path" ]; then
        echo "WARN: target khong ton tai, bo qua: $target_path" >&2
        return
    fi

    mkdir -p "$(dirname "$link_path")"

    if [ -L "$link_path" ]; then
        # Da la symlink - kiem tra dung target chua
        if [ "$(readlink -f "$link_path")" = "$(readlink -f "$target_path")" ]; then
            echo "OK (da dung san): $link_path -> $target_path"
            return
        fi
        rm "$link_path"
    elif [ -e "$link_path" ]; then
        local backup="${link_path}.bak-$(date +%Y%m%d-%H%M%S)"
        mv "$link_path" "$backup"
        echo "Da backup file cu: $backup"
    fi

    ln -s "$target_path" "$link_path"
    echo "Linked: $link_path -> $target_path"
}

echo "== Git / bash / cargo =="
link_dotfile "$HOME/.gitconfig"        "$REPO_ROOT/git/.gitconfig-linux"
link_dotfile "$HOME/.bashrc"           "$REPO_ROOT/bash/.bashrc"
# link_dotfile "$HOME/.cargo/config.toml" "$REPO_ROOT/cargo/config.toml"   # bat khi can

# VSCodium native trong WSL (chi bat neu chuyen sang WSLg, khong can khi dung open-remote-wsl)
# link_dotfile "$HOME/.config/VSCodium/User/settings.json"    "$REPO_ROOT/vscodium/settings.json"
# link_dotfile "$HOME/.config/VSCodium/User/keybindings.json" "$REPO_ROOT/vscodium/keybindings.json"

echo ""
echo "== Xac nhan lai =="
for f in "$HOME/.gitconfig" "$HOME/.bashrc"; do
    [ -e "$f" ] && ls -la "$f"
done

echo ""
echo "== Xong. Tiep tuc: tao SSH key rieng cho WSL (xem huong dan) =="
