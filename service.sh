#!/system/bin/sh
MODPATH="${0%/*}"
SOURCE_FONT="$MODPATH/system/fonts/NotoColorEmoji.ttf"
LOGFILE="$MODPATH/service.log"

GMS_FONT_PROVIDER="com.google.android.gms/com.google.android.gms.fonts.provider.FontsProvider"
GMS_FONT_UPDATER="com.google.android.gms/com.google.android.gms.fonts.update.UpdateSchedulerService"

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

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOGFILE" 2>/dev/null
  [ "$ACTION_MODE" = "1" ] && echo "$1"
}

replace_font() {
  local pkg="$1" subdir="$2" filename="$3"
  local name target_dir target
  name=$(app_name "$pkg")
  if is_installed "$pkg"; then
    target_dir="/data/data/$pkg/$subdir"
    target="$target_dir/$filename"
    if [ -d "$target_dir" ] && [ -f "$target" ]; then
      chattr -i "$target" 2>/dev/null
      if cp "$SOURCE_FONT" "$target"; then
        chmod 644 "$target"
        chown "$(stat -c %u:%g "$target_dir" 2>/dev/null)" "$target" 2>/dev/null
        log "  $name: replaced"
      else
        log "  $name: copy failed"
      fi
    else
      log "  $name: installed, font dir not ready"
    fi
  else
    log "  $name: not installed"
  fi
}

lock_font() {
  local pkg="$1" subdir="$2" filename="$3"
  local name target
  name=$(app_name "$pkg")
  [ -d "/data/data/$pkg" ] || return
  target="/data/data/$pkg/$subdir/$filename"
  mkdir -p "/data/data/$pkg/$subdir" 2>/dev/null
  chattr -i "$target" 2>/dev/null
  if cp -f "$SOURCE_FONT" "$target" 2>/dev/null; then
    chmod 444 "$target" 2>/dev/null
    if chattr +i "$target" 2>/dev/null; then
      log "  $name: immutable lock applied"
    else
      log "  $name: read-only lock applied"
    fi
  else
    log "  $name: lock failed"
  fi
}

clear_keyboard_cache() {
  local pkg="$1" dir
  is_installed "$pkg" || return
  for subpath in /cache /code_cache /app_webview /files/GCache; do
    dir="/data/data/$pkg$subpath"
    [ -d "$dir" ] && rm -rf "$dir"
  done
  am force-stop "$pkg" 2>/dev/null
  log "  $(app_name "$pkg"): cleared"
}

[ ! -f "$SOURCE_FONT" ] && exec 1>&- 2>&- && exit 0

if [ "$ACTION_MODE" != "1" ]; then
  while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 5; done
  while [ ! -d /sdcard ]; do sleep 5; done
fi

: > "$LOGFILE"

log "[1/5] Replacing app emoji fonts"
replace_font "com.facebook.katana" "app_ras_blobs" "FacebookEmoji.ttf"
replace_font "com.facebook.orca"   "app_ras_blobs" "FacebookEmoji.ttf"
replace_font "com.facebook.lite"   "files"          "emoji_font.ttf"
replace_font "com.facebook.mlite"  "files"          "emoji_font.ttf"

log ""
log "[2/5] Scanning for additional emoji fonts"
TMPFIND="$MODPATH/.tmp_scan_$$"
for base in /data/data /data/user/0; do
  [ -d "$base" ] && find "$base" -maxdepth 5 -iname "*emoji*.ttf" 2>/dev/null
done > "$TMPFIND"
EXTRA_COUNT=0
while read -r font; do
  chattr -i "$font" 2>/dev/null
  cp "$SOURCE_FONT" "$font" 2>/dev/null && chmod 644 "$font" || continue
  log "  Patched: $font"
  EXTRA_COUNT=$((EXTRA_COUNT + 1))
done < "$TMPFIND"
rm -f "$TMPFIND"
[ "$EXTRA_COUNT" = "0" ] && log "  No additional fonts found"

log ""
log "[3/5] Locking Facebook emoji fonts"
lock_font "com.facebook.katana" "app_ras_blobs" "FacebookEmoji.ttf"
lock_font "com.facebook.orca"   "app_ras_blobs" "FacebookEmoji.ttf"
lock_font "com.facebook.lite"   "files"          "emoji_font.ttf"
lock_font "com.facebook.mlite"  "files"          "emoji_font.ttf"

for dir in "/data/data/com.facebook.orca/files/fonts" "/data/user/0/com.facebook.orca/files/fonts"; do
  [ -d "$dir" ] && rm -rf "$dir"
  mkdir -p "$dir" 2>/dev/null && chmod 000 "$dir" 2>/dev/null
done

log "  Stopping Facebook apps"
for pkg in com.facebook.katana com.facebook.orca com.facebook.lite com.facebook.mlite; do
  is_installed "$pkg" && am force-stop "$pkg" 2>/dev/null
done

log ""
log "[4/5] Clearing keyboard caches"
clear_keyboard_cache "com.google.android.inputmethod.latin"
clear_keyboard_cache "com.android.inputmethod.latin"
clear_keyboard_cache "com.samsung.android.honeyboard"
clear_keyboard_cache "com.touchtype.swiftkey"
clear_keyboard_cache "ru.yandex.androidkeyboard"
clear_keyboard_cache "com.baidu.input"
clear_keyboard_cache "com.cootek.smartinputv5"
clear_keyboard_cache "org.futo.inputmethod.latin"
clear_keyboard_cache "com.fleksy.kb"
clear_keyboard_cache "com.grammarly.android.keyboard"
clear_keyboard_cache "kl.ime.oh"
clear_keyboard_cache "com.komikeyboard.latin"

log ""
log "[5/5] Disabling GMS font services"
if is_installed "com.google.android.gms"; then
  USERS_FOUND=0
  for userpath in /data/user/*; do
    [ -d "$userpath" ] || continue
    userid="${userpath##*/}"
    pm disable --user "$userid" "$GMS_FONT_PROVIDER" >/dev/null 2>&1 \
      && log "  Font provider disabled (user $userid)"
    pm disable --user "$userid" "$GMS_FONT_UPDATER" >/dev/null 2>&1 \
      && log "  Font updater disabled (user $userid)"
    USERS_FOUND=$((USERS_FOUND + 1))
  done
  [ "$USERS_FOUND" = "0" ] && log "  GMS not found or no users"
else
  log "  GMS not installed, skipping"
fi

[ -d "/data/fonts" ] && rm -rf "/data/fonts" && log "  Removed /data/fonts overlay"

TMPGMS="$MODPATH/.tmp_gms_$$"
find /data -maxdepth 8 -type d -path "*com.google.android.gms/files/fonts*" 2>/dev/null > "$TMPGMS"
while read -r dir; do
  rm -rf "$dir" && log "  Removed GMS font dir: ${dir##*/data/data/}"
done < "$TMPGMS"
rm -f "$TMPGMS"

log ""
log "Done"

exec 1>&- 2>&-
exit 0