#!/usr/bin/env bash

set -e          # exit on error
set -o pipefail # exit on fail in pipe

##
## Utility functions
##

echo_bold() {
  echo -e "\033[1m$1\033[0m"
}

echo_error() {
  echo -e "\033[31m❌ $1\033[0m" >&2
}

echo_success() {
  echo -e "\033[32m✅ ${1:-Done}\033[0m"
}

echo_title() {
  echo_bold "##"
  echo_bold "## $1"
  echo_bold "##"
}

wait_for_key_press() {
  echo "${1:-Press any key to continue or Ctrl+C to abort...}"
  read -r -n 1 -s
}

alias install_pacman_package="sudo pacman --noconfirm --sync" 
alias update_pacman_database="sudo pacman --noconfirm --sync --refresh"

################################################
##
## Andrei's Artix Linux installation script
##
################################################

################################################
echo_title "0. Confirm user"
################################################

USER=$(whoami)

echo "Install for user $(echo_bold "$USER"):"
echo " - UID: $(id -u)"
echo " - Home folder: $HOME"

wait_for_key_press

################################################
echo_title "0.1 Enable Arch Linux repositories"
################################################

# Note: Never enable `code` Arch Linux repository, it will break the system.
# See https://wiki.artixlinux.org/Main/Repositories

# Note: Arch Linux repositories must be after Artix Linux repositories 
# in pacman.conf

install_pacman_package artix-archlinux-support

if grep --quiet "^\[extra\]$" /etc/pacman.conf; then
  echo_bold "[extra] package repository already enabled, skipping..." 
else
  {
    echo ""
    echo "#"
    echo "# Arch Linux repositories"
    echo "#"
    echo ""
    echo "[extra]"
    echo "Include = /etc/pacman.d/mirrorlist-arch" 
    echo ""
  } | sudo tee --append /etc/pacman.conf > /dev/null
fi

if grep --quiet "^\[community\]$" /etc/pacman.conf; then
  echo_bold "[community] package repository already enabled, skipping..." 
else
  {
    echo "[community]"
    echo "Include = /etc/pacman.d/mirrorlist-arch" 
    echo ""
  } | sudo tee --append /etc/pacman.conf > /dev/null
fi

update_pacman_database

echo_success "Arch Linux repositories enabled"
wait_for_key_press

################################################
echo_title "0.2 Enable AUR repositories"
################################################

install_pacman_package aurutils

HOSTNAME=$(uname -n)
LOCAL_AUR_REPO_NAME="$HOSTNAME-aur"
LOCAL_AUR_REPO_PATH="/home/pacman-local"

if grep --quiet "^\[$LOCAL_AUR_REPO_NAME\]$" /etc/pacman.conf; then
  echo_bold "[$LOCAL_AUR_REPO_NAME] local repository already configured, skipping..."
else
  {
    echo "[$LOCAL_AUR_REPO_NAME]"
    echo "SigLevel = Optional TrustAll"
    echo "Server = file://$LOCAL_AUR_REPO_PATH"
  } | sudo tee --append /etc/pacman.conf > /dev/null
fi

# Create the directory for the local AUR repository if it doesn't exist
sudo install --directory "$LOCAL_AUR_REPO_PATH" \
  --owner "$USER" --group "$USER" --m 755

# Initialize the local AUR repository database
if [ -f "$LOCAL_AUR_REPO_PATH/$LOCAL_AUR_REPO_NAME.db.tar.gz" ]; then
  echo_bold "[$LOCAL_AUR_REPO_NAME] local repository already initialized, skipping..."
else
  repo-add "$LOCAL_AUR_REPO_PATH/$LOCAL_AUR_REPO_NAME.db.tar.gz"
fi

update_pacman_database

alias install_aur_package="aur sync --no-view"

echo_success "AUR repositories enabled via local repository $LOCAL_AUR_REPO_PATH. Use 'aur sync' to install AUR packages."
wait_for_key_press

################################################
echo_title "1. Install andreidmt/dotfiles repo"
################################################

DOTFILES_HOME="$HOME/Work/andreidmt/dotfiles"

if [ -d "$DOTFILES_HOME" ]; then
  echo_bold "Dotfiles already cloned in $DOTFILES_HOME, pulling insted..."
  cd "$DOTFILES_HOME" && git pull && cd -
else 
  git clone https://github.com/andreidmt/dotfiles.git "$DOTFILES_HOME"
fi

echo_success "andreidmt/dotfiles repo cloned in $DOTFILES_HOME"
wait_for_key_press

################################################
echo_title "2. Install core packages"
################################################

core_packages=(
  pacman-contrib    # Contributed scripts and tools for pacman systems
  neofetch          # System information tool
  cmake             # Cross-platform open-source make system
  mesa              # Open source graphics drivers
  git               # Version control system
  fzf               # Fuzzy finder
  jq                # JSON processor
  unzip             # Zip file decompressor
  zathura           # PDF viewer
  zathura-pdf-mupdf # MuPDF plugin for Zathura
  zathura-ps        # PS plugin for Zathura
  nnn               # File manager
  networkmanager    # Network connection manager
  openssh           # SSH server and client
  tree              # List contents of directories in a tree-like format
  # Faster cli tools re-written in Rust. 
  # See more: 
  # https://zaiste.net/posts/shell-commands-rust/
  # https://itsfoss.com/rust-cli-tools/
  bandwhich         # Network utilization
  tokei             # Code statistics
  exa               # Ls alternative
  fd                # Find alternative
  ripgrep           # Grep alternative
  bat               # Cat with syntax highlighting and Git integration
  tealdeer          # Client for tldr
  git-delta         # Git diff viewer
  bottom            # System monitor
)

install_pacman_package "${core_packages[@]}"

ln -v -f -s "$DOTFILES_HOME/home/.gitconfig" "$HOME/.gitconfig"
ln -v -f -s "$DOTFILES_HOME/home/doomguy.png" "$HOME/doomguy.png"
ln -v -f -s "$DOTFILES_HOME/home/doomguy-blood.png" "$HOME/doomguy-blood.png"

echo_success "Core packages installed"

################################################
echo_title "1.1 Add GitHub SSH key fingerprints"
################################################

# Public key fingerprints can be used to validate a connection to a 
# remote server. This makes sure that the server you are connecting to
# is the correct one and not a malicious server.
#
# Read more: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints

{
  echo "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl" 
  echo "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg="
  echo "github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk="
} > "$HOME/.ssh/known_hosts"

echo_success "GitHub SSH key fingerprints added to $HOME/.ssh/known_hosts"
wait_for_key_press

################################################
echo_title "1.2 Create SSH key pair for GitHub"
################################################

GITHUB_SSH_KEY_PATH="${HOME}/.ssh/${USER}@${HOSTNAME}_github"

if [ -f "$GITHUB_SSH_KEY_PATH" ]; then
  echo_bold "SSH key pair already exists at $GITHUB_SSH_KEY_PATH, skipping..."
else 
  ssh-keygen -t ed25519 -f "$GITHUB_SSH_KEY_PATH" -q -N ""
fi

if [ -z "$SSH_AGENT_PID" ]; then
  echo "Starting ssh-agent..."
  eval "$(ssh-agent -s)"
else
  echo "ssh-agent is already running"
fi

# Add the SSH private key to the ssh-agent
ssh-add "$GITHUB_SSH_KEY_PATH"

echo_bold "Add the following SSH key to your GitHub account (https://github.com/settings/keys):"
cat "$GITHUB_SSH_KEY_PATH.pub"

echo_success "SSH key pair created at $GITHUB_SSH_KEY_PATH"
wait_for_key_press

################################################
echo_title "3. Create core directories"
################################################

mkdir -v -p "$HOME/Downloads"
mkdir -v -p "$HOME/Backups"
mkdir -v -p "$HOME/Mounts"
mkdir -v -p "$HOME/Zettelkasten"
mkdir -v -p "$HOME/Music"
mkdir -v -p "$HOME/Work/asd14"
mkdir -v -p "$HOME/Work/andreidmt"
mkdir -v -p "$HOME/Pictures/Screenshots"
ln -v -f -s "$DOTFILES_HOME/wallpapers" "$HOME/Pictures/Wallpapers"

echo_success "Core directories created"
wait_for_key_press

################################################
echo_title "5. Install ZSH & set as default shell"
################################################

install_pacman_package zsh 

sudo chsh -s "$(which zsh)" "$USER"

echo "source \"$DOTFILES_HOME/.init\"" > "$HOME/.zshrc"

wait_for_key_press "Press any key to continue or Ctrl+C to abort and restart the system into ZSH. You dont need to do this for the install process to finish" 

################################################
echo_title "6. Link sh to dash"
################################################

install_pacman_package dash

CURRENT_SH=$(readlink -f /bin/sh)
DASH_PATH=$(command -v dash)

if [ "$CURRENT_SH" != "$DASH_PATH" ]; then
  sudo ln -sf "$DASH_PATH" /bin/sh
fi

echo_success "sh linked to dash"
wait_for_key_press

################################################
echo_title "7. Install and setup docker and docker-compose with runit"
################################################

install_pacman_package docker docker-compose docker-runit
sudo usermod -aG docker "$USER"
sudo ln -s /etc/runit/sv/docker /run/runit/service/

echo_success "Docker installed and configured with runit"
wait_for_key_press
