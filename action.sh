#!/system/bin/sh
MODPATH="${0%/*}"

set +o standalone 2>/dev/null
unset ASH_STANDALONE 2>/dev/null

if [ ! -f "$MODPATH/service.sh" ]; then
  echo "Error: service.sh not found"
  exit 1
fi

export ACTION_MODE=1
sh "$MODPATH/service.sh"
exit $?
