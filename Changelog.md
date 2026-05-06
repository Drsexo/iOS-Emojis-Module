## 26.4.1
- Added action menu: Vol UP applies iOS emojis, Vol DOWN unlocks and cleans all patched app fonts immediately without a reboot.
- Fixed KSU action console not showing close button after completion. 
- Cleaned up code

## 26.4
- Updated to iOS 26.4 emojis.
- Fixed action button crash on KernelSU variants.
- Fixed `cp: Operation not permitted` on all Facebook emoji fonts when re-running the action button. Files locked with `chattr +i` in a prior run now have the immutable flag stripped before each copy.
- Fixed temp files using `/tmp`, all temp files now write to `$MODPATH` instead.
- Fixed secondary emoji font scan silently skipping immutable files, `[ -w "$font" ]` returns false for immutable files even as root, replaced with `chattr -i` + `cp` attempt.
- Fixed log ordering and delayed console output in the action console.
- Added `[1/5]…[5/5]` step progress headers in action console.
- Added log rotation: up to 3 archived `service.log` files, max 5 MB each.