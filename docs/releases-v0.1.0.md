# Top of Mind 0.1.0

The first public release of Top of Mind: a native macOS menu bar task inbox and Eisenhower matrix.

- Spacious glass panel with a scrollable inbox on the left and four coloured quadrants.
- Quick title-only capture, drag and drop, manual ordering, and per-task destination menus.
- Complete, edit, return to inbox, trash, and restore tasks.
- Manual light/dark switch beside the pin, independent of macOS appearance.
- Optional matrix axis labels and a pin to keep the panel open.
- Local atomic persistence; no accounts, tracking, sync or network calls.
- Checklist menu bar icon and a dedicated app icon.

## Download

`TopOfMind-v0.1.0-macos-universal.zip` includes both Apple Silicon and Intel executables. Requires macOS 14 or later. Unzip, move Top of Mind.app to Applications, and open it.

The release is ad-hoc signed, not Apple-notarized. macOS may require a first-launch approval in System Settings → Privacy & Security. Installation details are in the README.

The accompanying `.sha256` file contains the archive checksum.

## Verification

23 core tests pass in the macOS build environment. Native Mac checks covered capture, matrix drops, destination menus, title editing, completion/trash recovery, long inbox scrolling, optional axis labels and manual appearance. The installed production app retained a task and the chosen theme after quitting and reopening. Package checksum, archive integrity and signature were verified after download.
