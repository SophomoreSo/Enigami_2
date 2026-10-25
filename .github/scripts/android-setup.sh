#!/usr/bin/env bash
# Tell the Android exporter where the SDK, the JDK and a signing key are.
#
# Godot keeps these in editor settings rather than the project, so a CI box has
# to be given them — there is no project file that can carry them. Without a
# key of its own it writes a throwaway debug key, which is enough for an APK
# that installs on a test device and no use for anything else.
#
# For a real signed build, set three repository secrets:
#   ANDROID_KEYSTORE_BASE64    base64 of your .keystore  (base64 -i k.keystore)
#   ANDROID_KEYSTORE_PASSWORD  its password
#   ANDROID_KEYSTORE_USER      the key alias

set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.5.1}"
SETTINGS_DIR="$HOME/.config/godot"
# Editor settings are keyed to the minor version: 4.5.1 -> editor_settings-4.5.tres
SETTINGS="$SETTINGS_DIR/editor_settings-${GODOT_VERSION%.*}.tres"

SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[ -n "$SDK" ] || { echo "::error::No Android SDK on this runner."; exit 1; }
[ -n "${JAVA_HOME:-}" ] || { echo "::error::No JAVA_HOME on this runner."; exit 1; }

DEBUG_KEYSTORE="$HOME/debug.keystore"
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android \
	-keystore "$DEBUG_KEYSTORE" -storepass android \
	-dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12 >/dev/null 2>&1

mkdir -p "$SETTINGS_DIR"
{
	echo '[gd_resource type="EditorSettings" format=3]'
	echo
	echo '[resource]'
	echo "export/android/android_sdk_path = \"$SDK\""
	echo "export/android/java_sdk_path = \"$JAVA_HOME\""
	echo "export/android/debug_keystore = \"$DEBUG_KEYSTORE\""
	echo 'export/android/debug_keystore_user = "androiddebugkey"'
	echo 'export/android/debug_keystore_pass = "android"'
} > "$SETTINGS"

if [ -n "${KEYSTORE_B64:-}" ]; then
	RELEASE_KEYSTORE="$HOME/release.keystore"
	echo "$KEYSTORE_B64" | base64 --decode > "$RELEASE_KEYSTORE"
	{
		echo "export/android/release_keystore = \"$RELEASE_KEYSTORE\""
		echo "export/android/release_keystore_user = \"${KEYSTORE_USER:-}\""
		echo "export/android/release_keystore_pass = \"${KEYSTORE_PASS:-}\""
	} >> "$SETTINGS"
	echo "Release keystore in place — Android will be signed for distribution."
else
	echo "::notice title=Android will be debug-signed::Set ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD and ANDROID_KEYSTORE_USER for a distributable APK."
fi

echo "SDK: $SDK"
echo "JDK: $JAVA_HOME"
