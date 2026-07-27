#!/usr/bin/env bash

# Stop script jika ada perintah yang gagal (error)
set -e

echo "🚀 Starting Fedora Dotfiles Restoration..."

# Beralih ke direktori tempat script ini berada
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# -----------------------------------------------------------------------------
# 1. OPTIMASI DNF & REPOSITORY (Harus Paling Pertama)
# -----------------------------------------------------------------------------
echo "⚡ Optimizing DNF configuration..."
if ! grep -q "max_parallel_downloads" /etc/dnf/dnf.conf; then
    echo "max_parallel_downloads=10" | sudo tee -a /etc/dnf/dnf.conf
fi

if ! grep -q "fastestmirror" /etc/dnf/dnf.conf; then
    echo "fastestmirror=True" | sudo tee -a /etc/dnf/dnf.conf
fi

echo "🔓 Enabling RPM Fusion repositories..."
sudo dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm || true

echo "🔄 Upgrading system packages to latest version..."
sudo dnf upgrade -y

# -----------------------------------------------------------------------------
# 2. INSTALL BASE PACKAGES (DNF, Stow, Git, Zsh)
# -----------------------------------------------------------------------------
# Pastikan git, zsh, dan stow terpasang dulu sebelum langkah berikutnya
echo "🛠️ Installing essential tools (git, zsh, stow)..."
sudo dnf install -y git zsh stow curl

echo "📦 Installing user DNF packages from list..."
if [ -f ./packages/dnf-apps.txt ]; then
    sudo dnf install -y $(cat ./packages/dnf-apps.txt)
fi

echo "📦 Installing Flatpak apps from list..."
if [ -f ./packages/flatpak-apps.txt ]; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    xargs flatpak install -y flathub < ./packages/flatpak-apps.txt
fi

# Set Zsh sebagai default shell kalau belum
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "🐚 Changing default shell to Zsh..."
    sudo chsh -s $(which zsh) $USER || true
fi

# -----------------------------------------------------------------------------
# 3. ZSH ENVIRONMENT SETUP (Oh My Zsh, Theme, Plugins)
# -----------------------------------------------------------------------------
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "✨ Installing Oh My Zsh..."
    RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Powerlevel10k Theme
if [ ! -d "$P10K_DIR" ]; then
    echo "🎨 Installing Powerlevel10k theme..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
fi

# Zsh Plugins
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    echo "🔌 Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    echo "🔌 Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# -----------------------------------------------------------------------------
# 4. RUNTIME INSTALLERS (NVM & Bun)
# -----------------------------------------------------------------------------
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
    echo "⚡ Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

if [ ! -d "$HOME/.bun" ]; then
    echo "🍞 Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
fi

# -----------------------------------------------------------------------------
# 5. SYMLINK CONFIGURATIONS VIA GNU STOW
# -----------------------------------------------------------------------------
echo "🔗 Symlinking configuration files with Stow..."

# Hapus bawaan .zshrc dari Oh My Zsh jika ada biar tidak conflict
rm -f "$HOME/.zshrc"

# Targetkan symlink secara eksplisit ke $HOME
stow -t "$HOME" zsh

echo "----------------------------------------------------"
echo "✅ All done! Restart your terminal or logout/login to take effect."
echo "----------------------------------------------------"