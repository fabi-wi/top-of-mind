# Top of Mind v0.1.1 design QA

This versioned report applies to the refined native-popover implementation. The project-root `design-qa.md` remains preserved as historical v0.1.0 evidence and is not acceptance evidence for the new user-requested appearance.

**Findings**

No actionable P0/P1/P2 deviation remains after full-view and focused side-by-side inspection. Native framing, the four tints, smaller type, retained pin and removal of requested clutter match the refined direction.

The earlier P2 stale-public-imagery finding is resolved. `README.md:1` now references `docs/assets/top-of-mind-hero-v0.1.1.png`; `README.md:39` references the actual `docs/assets/top-of-mind-v0.1.1.png`. Both updated references were checked, and the new hero was opened: it presents the current three header controls and omits the removed Inbox heading/counts, manual theme control and footer.

**Source visual truth and intentional updates**

- Latest user direction, relayed by the parent agent: native glass matching Codex Rate Limits; inherit macOS appearance; retain pin, four tinted quadrants and smaller text; remove custom outer framing, manual theme control, Inbox heading/subtitle/counts, empty-list prompts and footer hints.
- Original layout reference: `design/mockups/mockup-01.png`.
- Previous-release context: `docs/assets/top-of-mind-light.png` and `docs/assets/top-of-mind-dark.png`, used to compare the removed layers and clutter, not as the new acceptance target.
- Current rendered native implementation: `docs/assets/top-of-mind-v0.1.1.png`.
- Native reference implementation inspected read-only: Codex Rate Limits' `App/AppKit/StatusBarController.swift` and `App/Views/RateLimitPopoverView.swift`.
- State: populated demo, six inbox tasks and two tasks per quadrant, axis labels hidden, native inherited dark appearance. These are sample tasks; no saved personal task file or backup was opened.

**Dimensions and comparison evidence**

| Artifact | Original pixels | Normalization |
| --- | ---: | --- |
| Mockup 01 | 1536×1024 | Estimated panel crop x118/y70/w1300/h851, normalized to 1000×650 logical panel; vertical adjustment below 1% |
| Previous light/dark captures | 2052×1352 | Content crop x26/y26/w2000/h1300 at 2× density, normalized to 1000×650 |
| v0.1.1 native capture | 2052×1352 | Same native content crop and 2× density normalization |

- Source, previous release and current native captures were opened.
- Combined comparison input prepared: `work/qa-v0.1.1-comparison.html`. It includes full matrix layout, previous/current framing, focused header/capture area and focused Do-quadrant typography/tint comparisons.
- Rendered combined comparison screenshots: `work/qa-v0.1.1-full.png`, `work/qa-v0.1.1-before-after.png` and `work/qa-v0.1.1-focused.png`. Each is 3412×2168 pixels from the native Chrome window (1706×1084 logical points at 2× density). Both source/current columns are visible together. The first capture covers the complete source/current panels; the second covers complete previous/current framing plus header detail; the third covers the full focused header and Do-quadrant details.
- Chrome was used only during the parent agent's explicit safe UI pause. A new comparison tab was opened and then closed; the existing tab was preserved. Diagnostic screenshots stay in ignored `work/`; no private browser content is transcribed here.
- The current window-only export has an opaque neutral-gray material result. It does not show the desktop behind the popover; its background tone is not evidence of the live wallpaper treatment or live contrast. No private wallpaper is reproduced here.
- No browser-console claim applies to the native product; Chrome will only render the diagnostic comparison page.

**Required fidelity surfaces**

| Surface | Current assessment |
| --- | --- |
| Fonts and typography | Full and focused comparisons confirm the approved native system sizes remain 13 points for task text, 11 for helpers and 20 for rounded headings. Main text uses semantic `.primary`; secondary controls use semantic `.secondary`. App-owned quadrant accents select a light/dark palette from the native environment. Weight, hierarchy, line spacing and alignment are coherent; populated text shows no clipping or overlap. |
| Spacing and layout rhythm | Spacious 2×2 matrix remains beside the capture/passive list. Removed Inbox heading and footer recover vertical space. Outer 18-point content margins, 12-point inbox/matrix gap, 8-point grid gap and 15-point quadrant radii remain coherent. No custom root border or rounded inset creates the earlier doubled edge. |
| Colours and tokens | Four green/warm/blue/rose tints remain, now at 0.22 opacity in light appearance and 0.12 in dark. Native `NSPopover` supplies its material, bezel and arrow. `NSHostingController` is plain, with no custom effect wrapper or root paint/stroke/clip. Production appearance is inherited; overrides are limited to isolated demo capture options. Live desktop contrast requires the parent agent's native observation rather than this isolated export. |
| Image quality and assets | Focused current 2× capture has clean native text and SF Symbol controls. The supplied clipboard resource remains a tiny template menu-bar icon. README now presents the version-appropriate native capture and opened 1672×941 product hero. The hero's app copy, task rows, quadrant labels and header controls agree with the current UI; old imagery remains historical. |
| Copy and content | Quadrant title/helper copy and task-only rows remain coherent. Inbox title/subtitle/counts, quadrant counts, empty prompts, footer copy and theme control are absent from both the current source and opened native capture. Pin, view options, close and task menus remain available. |

**Interaction evidence / residual gaps**

The parent agent supplied direct CUA observations from clean, hands-off v0.1.1 demo tests. This reviewer did not repeat native-app actions during Chrome capture:

- Quick capture using Return and pin operation.
- Full-row drag using `NSItemProvider` onto a quadrant heading.
- Inbox sixth-to-first reordering and Do second-to-first reordering.
- Per-task destination menu returning a task to Inbox.
- Complete a task and restore it from Completed history; trash and restore a task from Trash.
- Demo was closed after those checks; no production task data or backup was opened by this reviewer.

The parent subsequently installed the verified CI-built universal v0.1.1 package and inspected the actual installed app with CUA. It showed a single native border and no Inbox heading, counters, empty hints or theme switch. An existing task remained in its previous quadrant. The parent confirmed the private task file was byte-for-byte unchanged after restarting, and that the installed binary matched the verified CI package. This reviewer did not open that private file or backup.

A live desktop/wallpaper comparison and a separate smaller-screen state were not captured in this pass. The native material follows the same plain hosting/popover structure as Codex Rate Limits; the isolated export's neutral gray is classified as capture context. The combined browser evidence validates layout and app-owned visuals, not live wallpaper compositing.

**Comparison history**

1. v0.1.0's historical custom-host/root layers were inspected. Native Rate Limits uses plain hosting with no custom root material. The parent and native-UI agent replaced the host and removed custom root paint/stroke/clip, forced production appearance and requested clutter.
2. Opened the v0.1.1 native capture and current host/BoardView source. One outer native edge is visible; requested tints/pin/text remain and requested clutter is absent. Prepared the combined diagnostic. Identified the P2 stale-public-imagery issue.
3. Parent replaced README's old imagery with `top-of-mind-hero-v0.1.1.png` and the native v0.1.1 capture. Verified the new file references and opened the updated hero. Captured and inspected all full-view and focused combined comparisons during the safe Chrome pause. Post-fix evidence is the updated README/assets plus the three `work/qa-v0.1.1-*.png` captures listed above. No actionable P0/P1/P2 issue remains.
4. Parent verified the installed universal v0.1.1 package, inspected the actual app, and confirmed existing task placement and unchanged task-file bytes after restart. The installed binary matched the verified CI artifact. No further visual or persistence regression was reported.

**Implementation Checklist**

- [x] Open the current native capture and visual references.
- [x] Inspect plain native hosting, automatic appearance and removal of root layers/clutter.
- [x] Capture and inspect the rendered full-view and focused combined comparison.
- [x] Replace stale public product screenshots/hero references and verify the updated README.
- [x] Record the parent agent's actual v0.1.1 GUI evidence.
- [x] Record the parent agent's installed-package visual and persistence checks.

**Follow-up Polish**

- No additional native layout polish is requested from the current evidence.

final result: passed
