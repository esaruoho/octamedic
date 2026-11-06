#!/usr/bin/env bash
# ==============================================================================
# build_mac.sh — Build & Run OctaMEDIC on macOS
#
# Builds the CLI and GUI binaries natively for macOS, packages OctaMEDIC.app,
# and automatically starts the app.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

MODE="release"
BUILD_FLAG="--release"
DO_RUN=true
RUN_CLI=false
FOREGROUND=false
TARGET_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug)
            MODE="debug"
            BUILD_FLAG=""
            shift
            ;;
        --no-run)
            DO_RUN=false
            shift
            ;;
        --cli)
            RUN_CLI=true
            shift
            ;;
        --fg|--foreground)
            FOREGROUND=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] [MODULE_FILE]"
            echo ""
            echo "Options:"
            echo "  --release          Build optimized release binaries (default)"
            echo "  --debug            Build unoptimized debug binaries"
            echo "  --no-run           Build and package only, do not launch"
            echo "  --cli              Run the mmd_cli interactive REPL instead of the GUI"
            echo "  --fg, --foreground Run in the terminal foreground (shows stdout/stderr)"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                # Build and launch OctaMEDIC with example.mmd1"
            echo "  $0 example_meds/example.mmd0       # Build and launch with specific module"
            echo "  $0 --cli example_meds/example.mmd0 # Build and launch CLI REPL"
            exit 0
            ;;
        *)
            TARGET_FILE="$1"
            shift
            ;;
    esac
done

echo "==> [1/3] Building OctaMEDIC for macOS ($MODE mode)..."
if [ -n "$BUILD_FLAG" ]; then
    cargo build $BUILD_FLAG -p octamedic_gui -p mmd_cli
else
    cargo build -p octamedic_gui -p mmd_cli
fi

BIN_DIR="$SCRIPT_DIR/target/$MODE"
APP_DIR="$BIN_DIR/OctaMEDIC.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> [2/3] Packaging macOS App Bundle: $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# 1. Copy the main executable
cp "$BIN_DIR/octamedic_gui" "$MACOS_DIR/octamedic_gui"
chmod +x "$MACOS_DIR/octamedic_gui"

# 2. Write Info.plist
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>octamedic_gui</string>
    <key>CFBundleIdentifier</key>
    <string>com.octamedic.octamedic</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>OctaMEDIC</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.0.1</string>
    <key>CFBundleVersion</key>
    <string>0.0.1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# 3. Generate .icns icon from octamedic.png if available
if [ -f "$SCRIPT_DIR/octamedic.png" ] && command -v iconutil >/dev/null 2>&1 && command -v sips >/dev/null 2>&1; then
    TEMP_DIR="$(mktemp -d)"
    TEMP_ICONSET="$TEMP_DIR/OctaMEDIC.iconset"
    mkdir -p "$TEMP_ICONSET"

    TEMP_SQUARE="$TEMP_DIR/square.png"
    sips -c 1080 1080 "$SCRIPT_DIR/octamedic.png" --out "$TEMP_SQUARE" >/dev/null 2>&1

    sips -z 16 16     "$TEMP_SQUARE" --out "$TEMP_ICONSET/icon_16x16.png" >/dev/null 2>&1
    sips -z 32 32     "$TEMP_SQUARE" --out "$TEMP_ICONSET/icon_16x16@2x.png" >/dev/null 2>&1
    sips -z 32 32     "$TEMP_SQUARE" --out "$TEMP_ICONSET/icon_32x32.png" >/dev/null 2>&1
    sips -z 64 64     "$TEMP_SQUARE" --out "$TEMP_ICONSET/icon_32x32@2x.png" >/dev/null 2>&1
    sips -z 128 128   "$TEMP_SQUARE" --out "$TEMP_ICONSET/icon_128x128.png" >/dev/null 2>&1
    sips -z 256 256   "$TEMP_SQUARE" --out "$TEMP_ICONSET/icon_128x128@2x.png" >/dev/null 2>&1
    sips -z 256 256   "$TEMP_SQUARE" --out "$TEMP_ICONSET/icon_256x256.png" >/dev/null 2>&1
    sips -z 512 512   "$TEMP_SQUARE" --out "$TEMP_ICONSET/icon_256x256@2x.png" >/dev/null 2>&1
    sips -z 512 512   "$TEMP_SQUARE" --out "$TEMP_ICONSET/icon_512x512.png" >/dev/null 2>&1
    sips -z 1024 1024 "$TEMP_SQUARE" --out "$TEMP_ICONSET/icon_512x512@2x.png" >/dev/null 2>&1

    iconutil -c icns "$TEMP_ICONSET" -o "$RESOURCES_DIR/AppIcon.icns" >/dev/null 2>&1 || true
    rm -rf "$TEMP_DIR"
fi

# Symlink at project root for easy access
ln -sfn "$APP_DIR" "$SCRIPT_DIR/OctaMEDIC.app"

echo "==> Build & packaging complete!"
echo "    App bundle: $SCRIPT_DIR/OctaMEDIC.app"

if [ "$DO_RUN" = true ]; then
    # Default to example module if no file specified
    if [ -z "$TARGET_FILE" ] && [ -f "$SCRIPT_DIR/example_meds/example.mmd1" ]; then
        TARGET_FILE="$SCRIPT_DIR/example_meds/example.mmd1"
    elif [ -n "$TARGET_FILE" ] && [[ "$TARGET_FILE" != /* ]]; then
        TARGET_FILE="$SCRIPT_DIR/$TARGET_FILE"
    fi

    if [ "$RUN_CLI" = true ]; then
        echo "==> [3/3] Starting mmd_cli REPL..."
        if [ -n "$TARGET_FILE" ]; then
            exec "$BIN_DIR/mmd_cli" "$TARGET_FILE"
        else
            exec "$BIN_DIR/mmd_cli"
        fi
    elif [ "$FOREGROUND" = true ]; then
        echo "==> [3/3] Starting OctaMEDIC in foreground..."
        if [ -n "$TARGET_FILE" ]; then
            exec "$MACOS_DIR/octamedic_gui" "$TARGET_FILE"
        else
            exec "$MACOS_DIR/octamedic_gui"
        fi
    else
        echo "==> [3/3] Starting OctaMEDIC.app..."
        if [ -n "$TARGET_FILE" ]; then
            open "$APP_DIR" --args "$TARGET_FILE"
        else
            open "$APP_DIR"
        fi
        echo "==> OctaMEDIC is now running on your screen!"
    fi
fi
