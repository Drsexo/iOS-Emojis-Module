#!/system/bin/sh

SKIPMOUNT=false
PROPFILE=false
POSTFSDATA=false
LATESTARTSERVICE=true

FONT_DIR="$MODPATH/system/fonts"
EMOJI_FONT="NotoColorEmoji.ttf"
SOURCE_FONT="$FONT_DIR/$EMOJI_FONT"

OEM_VARIANTS="
SamsungColorEmoji.ttf
LGNotoColorEmoji.ttf
HTC_ColorEmoji.ttf
AndroidEmoji-htc.ttf
ColorUniEmoji.ttf
DcmColorEmoji.ttf
CombinedColorEmoji.ttf
NotoColorEmojiLegacy.ttf
"

FACEBOOK_APPS="
com.facebook.katana:app_ras_blobs:FacebookEmoji.ttf
com.facebook.orca:app_ras_blobs:FacebookEmoji.ttf
com.facebook.lite:files:emoji_font.ttf
com.facebook.mlite:files:emoji_font.ttf
"

KEYBOARD_APPS="
com.google.android.inputmethod.latin
com.android.inputmethod.latin
com.samsung.android.honeyboard
com.touchtype.swiftkey
ru.yandex.androidkeyboard
com.baidu.input
com.cootek.smartinputv5
com.anysoftkeyboard.languagepack.english
org.futo.inputmethod.latin
com.fleksy.kb
com.grammarly.android.keyboard
kl.ime.oh
com.komikeyboard.latin
"

detect_root_manager() {
  if [ -n "$KSU" ]; then
    echo "KernelSU"
  elif [ -n "$APATCH" ]; then
    echo "APatch"
  else
    echo "Magisk"
  fi
}

app_name() {
  case "$1" in
    com.facebook.orca)                    echo "Messenger" ;;
    com.facebook.katana)                  echo "Facebook" ;;
    com.facebook.lite)                    echo "Facebook Lite" ;;
    com.facebook.mlite)                   echo "Messenger Lite" ;;
    com.google.android.inputmethod.latin) echo "Gboard" ;;
    com.android.inputmethod.latin)        echo "AOSP Keyboard" ;;
    com.samsung.android.honeyboard)       echo "Samsung Keyboard" ;;
    com.touchtype.swiftkey)               echo "SwiftKey" ;;
    ru.yandex.androidkeyboard)            echo "Yandex Keyboard" ;;
    com.baidu.input)                      echo "Baidu IME" ;;
    com.cootek.smartinputv5)              echo "TouchPal" ;;
    org.futo.inputmethod.latin)           echo "FUTO Keyboard" ;;
    com.fleksy.kb)                        echo "Fleksy" ;;
    com.grammarly.android.keyboard)       echo "Grammarly Keyboard" ;;
    kl.ime.oh)                            echo "OpenBoard" ;;
    com.komikeyboard.latin)               echo "Komi Keyboard" ;;
    *)                                    echo "$1" ;;
  esac
}

is_installed() {
  pm list packages 2>/dev/null | grep -q "^package:$1$"
}

ROOT_MANAGER=$(detect_root_manager)

ui_print "  iOS 26 Emoji"
ui_print "  Root: $ROOT_MANAGER"
ui_print ""

unzip -o "$ZIPFILE" 'system/*' -d "$MODPATH" >&2 || {
  ui_print "Failed to extract module files"
  exit 1
}

if [ ! -f "$SOURCE_FONT" ]; then
  ui_print "Emoji font not found in archive"
  exit 1
fi

ui_print "Installing system emoji font"

for variant in $OEM_VARIANTS; do
  [ -z "$variant" ] && continue
  if [ -f "/system/fonts/$variant" ]; then
    if cp "$SOURCE_FONT" "$FONT_DIR/$variant"; then
      ui_print "  Replaced: $variant"
    else
      ui_print "  Failed: $variant"
    fi
  fi
done

MIRRORPATH=""
[ -d /sbin/.core/mirror ] && MIRRORPATH=/sbin/.core/mirror
FONTS_XML="/system/etc/fonts.xml"
if [ -f "$MIRRORPATH$FONTS_XML" ]; then
  EXTRA_FONTS=$(sed -ne '/<family lang="und-Zsye".*>/,/<\/family>/ {
    s/.*<font weight="400" style="normal">\(.*\)<\/font>.*/\1/p
  }' "$MIRRORPATH$FONTS_XML")
  for font in $EXTRA_FONTS; do
    [ "$font" != "$EMOJI_FONT" ] && ln -sf "/system/fonts/$EMOJI_FONT" "$FONT_DIR/$font"
  done
fi

ui_print "Replacing app emoji fonts"

# Use temp file to avoid subshell buffering from pipe-to-while
TMPFILE="$MODPATH/.tmp_fb_$$"
printf '%s' "$FACEBOOK_APPS" > "$TMPFILE"
while IFS=: read -r pkg subdir filename; do
  [ -z "$pkg" ] && continue
  name=$(app_name "$pkg")
  if is_installed "$pkg"; then
    target="/data/data/$pkg/$subdir/$filename"
    target_dir="/data/data/$pkg/$subdir"
    if [ -d "$target_dir" ] && [ -f "$target" ]; then
      chattr -i "$target" 2>/dev/null
      cp "$SOURCE_FONT" "$target" && chmod 644 "$target"
      chattr +i "$target" 2>/dev/null
      am force-stop "$pkg" 2>/dev/null
      ui_print "  $name: replaced and locked"
    else
      ui_print "  $name: installed, will apply on boot"
    fi
  else
    ui_print "  $name: not installed"
  fi
done < "$TMPFILE"
rm -f "$TMPFILE"

ui_print "Clearing keyboard caches"

TMPFILE="$MODPATH/.tmp_kbd_$$"
printf '%s' "$KEYBOARD_APPS" > "$TMPFILE"
while read -r pkg; do
  [ -z "$pkg" ] && continue
  if is_installed "$pkg"; then
    name=$(app_name "$pkg")
    for subpath in /cache /code_cache /app_webview /files/GCache; do
      dir="/data/data/$pkg$subpath"
      [ -d "$dir" ] && rm -rf "$dir"
    done
    am force-stop "$pkg" 2>/dev/null
    ui_print "  $name: cleared"
  fi
done < "$TMPFILE"
rm -f "$TMPFILE"

if [ -d "/data/fonts" ]; then
  rm -rf "/data/fonts"
  ui_print "Removed /data/fonts overlay"
fi

ui_print "Setting permissions"
set_perm_recursive "$MODPATH" 0 0 0755 0644

if [ -f "/data/adb/modules/magisk_overlayfs/util_functions.sh" ] && \
   /data/adb/modules/magisk_overlayfs/overlayfs_system --test 2>/dev/null; then
  ui_print "Enabling OverlayFS support"
  OVERLAY_IMAGE_EXTRA=0
  OVERLAY_IMAGE_SHRINK=true
  . /data/adb/modules/magisk_overlayfs/util_functions.sh
  support_overlayfs && rm -rf "$MODPATH/system"
fi

ui_print ""
ui_print "Installation complete - reboot to apply"