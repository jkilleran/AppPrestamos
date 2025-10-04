#!/usr/bin/env bash
# Automated Flutter dev environment helper (Android SDK headless + CocoaPods + JDK)
# Idempotent: safe to re-run.
# NOTE: Still need manual installs for: Xcode (App Store) OR full .xip, Android Studio GUI (optional), first-run license accepts.

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

say() { echo -e "${GREEN}[setup]${NC} $*"; }
warn() { echo -e "${YELLOW}[warn]${NC} $*"; }
err() { echo -e "${RED}[error]${NC} $*" >&2; }

ARCH=$(uname -m)

# 1. Homebrew
if ! command -v brew >/dev/null 2>&1; then
  warn "Homebrew not found. Installing..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ $ARCH == 'arm64' ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  say "Homebrew present. Updating taps (light)."
  brew update --quiet || warn "brew update had a minor issue; continuing"
fi

# 2. JDK (Temurin 17 LTS)
if ! /usr/libexec/java_home -v 17 >/dev/null 2>&1; then
  say "Installing Temurin 17 JDK..."
  brew install --cask temurin17 || brew install --cask temurin
else
  say "JDK 17 already installed."
fi

###############################################
# 3. Android command-line tools & SDK layout  #
###############################################
ANDROID_BASE="$HOME/Library/Android/sdk"
CMDLINE_ROOT="$ANDROID_BASE/cmdline-tools"
CMDLINE_LATEST="$CMDLINE_ROOT/latest"

install_cmdline_tools() {
  say "Installing / ensuring Android command-line tools (brew cask)..."
  brew install --cask android-commandlinetools || true
  # Brew keeps the tools in share/android-commandlinetools
  local BREW_SHARE
  BREW_SHARE=$(brew --prefix 2>/dev/null)/share/android-commandlinetools
  if [[ -d "$BREW_SHARE/cmdline-tools" ]]; then
    mkdir -p "$CMDLINE_ROOT"
    # If latest not populated, copy
    if [[ ! -d "$CMDLINE_LATEST/bin" ]]; then
      rsync -a --delete "$BREW_SHARE/cmdline-tools/" "$CMDLINE_LATEST/" 2>/dev/null || cp -R "$BREW_SHARE/cmdline-tools" "$CMDLINE_LATEST" 2>/dev/null || true
    fi
  fi
}

if [[ ! -x "$CMDLINE_LATEST/bin/sdkmanager" ]]; then
  install_cmdline_tools
else
  say "Android cmdline-tools already present at $CMDLINE_LATEST"
fi

# 4. Environment exports (append if missing)
ZSHRC="$HOME/.zshrc"
add_if_missing() {
  local KEY="$1"; shift
  if ! grep -q "$KEY" "$ZSHRC" 2>/dev/null; then
    echo "$*" >> "$ZSHRC"
    say "Added $KEY to .zshrc"
  else
    say "$KEY already in .zshrc"
  fi
}

add_if_missing ANDROID_SDK_ROOT "export ANDROID_SDK_ROOT=\"$ANDROID_BASE\""
add_if_missing ANDROID_HOME "export ANDROID_HOME=\"$ANDROID_BASE\""
add_if_missing ANDROID_PATHS "export PATH=\"$ANDROID_BASE/platform-tools:$ANDROID_BASE/emulator:$ANDROID_BASE/cmdline-tools/latest/bin:$PATH\""

# shellcheck disable=SC1090
source "$ZSHRC" || true

###############################################
# 5. Install base Android packages into ANDROID_SDK_ROOT
###############################################
if command -v sdkmanager >/dev/null 2>&1; then
  # Some brew installs expose sdkmanager in PATH but not yet copied into our desired tree.
  mkdir -p "$ANDROID_BASE"
  say "Installing / updating Android SDK packages into $ANDROID_BASE ..."
  yes | sdkmanager --sdk_root="$ANDROID_BASE" --licenses >/dev/null 2>&1 || warn "License acceptance may be partial; rerun manually if needed"
  sdkmanager --sdk_root="$ANDROID_BASE" --install \
    "platform-tools" \
    "platforms;android-35" \
    "build-tools;35.0.0" \
    "emulator" \
    "system-images;android-35;google_apis;arm64-v8a" || warn "Some Android packages failed; you can retry manually"
else
  err "sdkmanager not found even after install; investigate cmdline-tools path."; exit 1
fi

# Validate installation
if [[ ! -d "$ANDROID_BASE/platform-tools" ]]; then
  warn "platform-tools directory still missing. You may need to rerun: sdkmanager --sdk_root=\"$ANDROID_BASE\" \"platform-tools\""
fi

# 6. CocoaPods
if ! command -v pod >/dev/null 2>&1; then
  say "Installing CocoaPods..."
  brew install cocoapods || sudo gem install cocoapods
  pod setup || true
else
  say "CocoaPods already installed (version $(pod --version))."
fi

# 7. Create a default AVD if none exists
AVD_HOME="$HOME/.android/avd"
if [[ -d "$AVD_HOME" ]] && ls "$AVD_HOME"/*.avd >/dev/null 2>&1; then
  say "AVD already exists. Skipping creation."
else
  if command -v avdmanager >/dev/null 2>&1; then
    say "Creating Pixel 6 test AVD..."
    echo no | avdmanager create avd -n pixelTest -k "system-images;android-35;google_apis;arm64-v8a" --device "pixel_6" || warn "AVD creation failed (maybe image missing)."
  fi
fi

# 8. Flutter config (if flutter installed)
if command -v flutter >/dev/null 2>&1; then
  say "Showing flutter doctor summary (post setup):"
  flutter doctor
else
  warn "Flutter not on PATH; install from https://flutter.dev/docs/get-started/install"
fi

say "Done. Restart your terminal or run: source ~/.zshrc"
warn "Still need manual Xcode full install and first-launch steps if not done yet."
