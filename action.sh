#!/system/bin/sh
MODPATH="${0%/*}"

set +o standalone 2>/dev/null
unset ASH_STANDALONE 2>/dev/null

TIMEOUT=30

app_name() {
  case "$1" in
    com.facebook.orca)   echo "Messenger" ;;
    com.facebook.katana) echo "Facebook" ;;
    com.facebook.lite)   echo "Facebook Lite" ;;
    com.facebook.mlite)  echo "Messenger Lite" ;;
    *)                   echo "$1" ;;
  esac
}

is_installed() {
  pm list packages 2>/dev/null | grep -q "^package:$1$"
}

HAS_GETEVENT=1
command -v getevent >/dev/null 2>&1 || HAS_GETEVENT=0

if ! command -v timeout >/dev/null 2>&1; then
  timeout() { shift; "$@"; }
fi

echo ""
echo "  ⬆️ Vol UP   = Apply iOS emojis"
echo "  ⬇️ Vol DOWN = Unlock and clean"
echo "  Timeout ${TIMEOUT}s = Apply iOS"
echo ""

ACTION="apply"

if [ "$HAS_GETEVENT" -eq 0 ]; then
  echo "Applying iOS emojis (no getevent)"
else
  while :; do
    _ev=$(timeout "$TIMEOUT" getevent -qlc 1 2>/dev/null)
    _ec=$?
    if [ "$_ec" -eq 124 ] || [ "$_ec" -eq 143 ]; then
      echo "Applying iOS emojis (timeout)"
      ACTION="apply"
      break
    fi
    if echo "$_ev" | grep -q "KEY_VOLUMEUP.*DOWN"; then
      echo "Applying iOS emojis..."
      ACTION="apply"
      break
    fi
    if echo "$_ev" | grep -q "KEY_VOLUMEDOWN.*DOWN"; then
      echo "Unlocking and cleaning..."
      ACTION="unlock"
      break
    fi
  done
fi

echo ""

if [ "$ACTION" = "apply" ]; then
  if [ ! -f "$MODPATH/service.sh" ]; then
    echo "Error: service.sh not found"
    exec 1>&- 2>&-
    exit 1
  fi
  export ACTION_MODE=1
  exec sh "$MODPATH/service.sh"
fi

UNLOCKED=0
REMOVED=0
FAILED=0

echo "[1/3] Unlocking and removing iOS fonts from app data"

TMPFILE="$MODPATH/.tmp_revert_$$"
printf 'com.facebook.katana:app_ras_blobs:FacebookEmoji.ttf\ncom.facebook.orca:app_ras_blobs:FacebookEmoji.ttf\ncom.facebook.lite:files:emoji_font.ttf\ncom.facebook.mlite:files:emoji_font.ttf\n' > "$TMPFILE"
while IFS=: read -r pkg subdir filename; do
  [ -z "$pkg" ] && continue
  name=$(app_name "$pkg")
  for base in /data/data /data/user/0; do
    target="$base/$pkg/$subdir/$filename"
    [ -f "$target" ] || continue
    chattr -i "$target" 2>/dev/null
    UNLOCKED=$((UNLOCKED + 1))
    if rm -f "$target" 2>/dev/null; then
      echo "  $name: unlocked + removed"
      REMOVED=$((REMOVED + 1))
    else
      echo "  $name: unlocked, delete manually"
      FAILED=$((FAILED + 1))
    fi
  done
done < "$TMPFILE"
rm -f "$TMPFILE"

echo ""
echo "[2/3] Scanning for other emoji fonts"

TMPFIND="$MODPATH/.tmp_scan_$$"
for base in /data/data /data/user/0; do
  [ -d "$base" ] && find "$base" -maxdepth 6 \( -iname "*emoji*.ttf" -o -iname "*emoji*.otf" \) 2>/dev/null
done > "$TMPFIND"

EXTRA=0
while read -r font; do
  chattr -i "$font" 2>/dev/null
  UNLOCKED=$((UNLOCKED + 1))
  if rm -f "$font" 2>/dev/null; then
    echo "  Removed: $font"
    EXTRA=$((EXTRA + 1))
    REMOVED=$((REMOVED + 1))
  else
    echo "  Unlocked (rm failed): $font"
    FAILED=$((FAILED + 1))
  fi
done < "$TMPFIND"
rm -f "$TMPFIND"
[ "$EXTRA" = "0" ] && echo "  None found"

echo ""
echo "[3/3] Restoring directories and services"

for dir in "/data/data/com.facebook.orca/files/fonts" "/data/user/0/com.facebook.orca/files/fonts"; do
  [ -d "$dir" ] && chmod 755 "$dir" 2>/dev/null && echo "  Restored: $dir"
done

GMS_FONT_PROVIDER="com.google.android.gms/com.google.android.gms.fonts.provider.FontsProvider"
GMS_FONT_UPDATER="com.google.android.gms/com.google.android.gms.fonts.update.UpdateSchedulerService"
if is_installed "com.google.android.gms"; then
  for userpath in /data/user/*; do
    [ -d "$userpath" ] || continue
    userid="${userpath##*/}"
    pm enable --user "$userid" "$GMS_FONT_PROVIDER" >/dev/null 2>&1
    pm enable --user "$userid" "$GMS_FONT_UPDATER"  >/dev/null 2>&1
  done
  echo "  GMS font services re-enabled"
fi

for pkg in com.facebook.katana com.facebook.orca com.facebook.lite com.facebook.mlite; do
  is_installed "$pkg" && am force-stop "$pkg" 2>/dev/null
done
echo "  Stopped affected apps"

echo ""
echo "Unlocked : $UNLOCKED"
echo "Removed  : $REMOVED"
[ "$FAILED" -gt 0 ] && echo "Manual delete needed: $FAILED"
echo ""
echo "App locks cleared. System emoji needs reboot."

exec 1>&- 2>&-
exit 0