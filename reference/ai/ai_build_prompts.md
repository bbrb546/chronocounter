*Godot 4.6.3 (Android first) client for the FastAPI /count endpoint, built and tested on a Google Pixel 6a*

*Revision 2 changes: (1) the top measure label of each page is now one less than its first detection's number, unless that detection is a long rest; (2) the next page starts at the previous page's end value plus 1, or at the end value itself when its first detection is a long rest; (3) the app sends a provisional initial number to the server and resolves the real one locally. Affected: Shared Brief sections 2 and 4, Prompts 1, 5, 6, 9, 10 and 13, Appendix A.*

*Revision 3 changes: you export and install the Godot project yourself, so the agent no longer touches anything about Android export (build template, SDK, JDK, keystore, export permissions, manifest, APK). Affected: How to use, Preflight, Shared Brief section 0, Prompts 1 and 2, Appendix A.*

*Revision 4 changes: the target device is a Google Pixel 6a. A new Shared Brief section 7 records its screen, density, memory, camera and navigation, and the prompts now use those numbers. Affected: Preflight, Shared Brief sections 1 and 6 and new section 7, Prompts 1, 2, 3, 4, 7, 8, 11, 12 and 13, Appendix A.*

*Revision 5 changes: (1) a headless test runner is created in Prompt 1 so every later prompt can run tests; (2) mock mode uses image/JSON pairs and skips the parity check; (3) the Pixel 6a is treated as an Android 16 device, and back-button handling starts in Prompt 1; (4) the server flags long rests whose number it could not read confidently, and the app marks them for checking; (5) wording fixes: dp figure, side-margin rule, persisted haptics setting, fade duration, duplicated hint, `first_page_provisional_initial()` name, fixture descriptions, and undo details. Affected: How to use, Preflight, Shared Brief sections 0, 1, 2, 4, 5, 6 and 7, Prompts 1 to 7, 9, 10, 12 and 13, Appendix A.*

## How to use this document

1. Do the **Preflight** below once (its first item is applying Appendix A to your Python pipeline). Then start a fresh agent session on the repository root and paste the **Shared Brief** as your first message. Tell the agent to save it verbatim as `docs/SPEC.md`.
2. Send Prompts 1 to 13 one at a time, in order. Each one starts by telling the agent to re-read SPEC.md (and UI\_GUIDE.md from Prompt 2 on), so you can resume in a new session at any step.
3. Do not send the next prompt until every item under **Verify** passes. If one fails, paste that item and what you saw back to the agent.
4. Items marked **\[You\]** need a human (running the server, using a phone, working in the Godot editor). The agent cannot confirm them alone.
5. You export and install the Godot project yourself whenever a step needs a phone test. The agent never builds, exports or signs anything.

Decisions already baked in from your answers: Godot 4.6.3 with the Native Camera Plugin; first detection a long rest on a no-pickup first page counts as measure 1; the top label of each page is one less than its first detection's number (the same number if that detection is a long rest); the next page starts at the previous page's end value plus 1 (the same value if its first detection is a long rest); later line-start labels use start + span after a long rest; the app renumbers locally after edits; uploads are upright JPEGs under 9.5 MiB (PNG sources pass through untouched when small enough); server URL is a Settings field with a default constant over local-network HTTP; pinch and two-finger pan only, plus a reset-view button; color-coded boxes with optional labels; delete on any detection, duration 1 to 999, long rests whose number the server could not read confidently are marked '?' for checking, no add feature; delete and retake photos but no reordering; in-memory only; on a failed page, stop and offer retry.

## Preflight (you do this once, before Prompt 1)

Target device: a Google Pixel 6a (1080x2400 screen, 60 Hz, 12 MP rear camera, Android 12 to 16). Also decided since the first version: a dark, camera-style interface, portrait only, with a shared design system built in Prompt 2 and a UX polish pass in Prompt 12. The project, the Native Camera Plugin and every part of the Android export (build template, SDK, JDK, keystore, permissions, cleartext HTTP) are handled by you, not the agent.

- [ ] The project in `godot/` is Godot 4.6.3, Compatibility renderer, portrait, base size 1080x1920 (Prompt 1 re-checks this). The Pixel 6a screen is 1080x2400, so the `expand` aspect gives a 1080x2400 viewport on the phone.
- [ ] The Native Camera Plugin is installed and enabled, and its README and demo are copied to `reference/native-camera/`.
- [ ] The Python pipeline is copied to `reference/pipeline/` (read-only reference).
- [ ] Your Pixel 6a is on the same Wi-Fi network as the PC (not a guest network, and with any VPN switched off). Note its Android version (Settings > About phone); it shipped with Android 12 and has since been updated to Android 16, so expect Android 16 (API 36) unless you have held back updates.
- [ ] Shoot the test photos with the Pixel 6a's own camera app at full resolution, so the fixtures match what the app will really produce: `phone_photo.jpg` with the phone held landscape (stored 4032x3024 with EXIF orientation 1, so no rotation is needed) and `exif6.jpg` with the phone held upright in portrait (also stored 4032x3024, but with EXIF orientation 6, so it displays as 3024x4032).
- [ ] Two or three of your own test pages have been run through the pipeline. Save each image and its `predictions.json` in `godot/fixtures/`, naming the JSON `predictions_<initial>.json` (for example `predictions_1.json`).
- [ ] For mock mode, make 2 or 3 pairs in `godot/fixtures/`: `mock_page_<i>.jpg` (or `.png`) plus `mock_page_<i>.json`. The JSON must be the real pipeline output for that exact image, so the boxes line up; copies of your test pages and their `predictions_*.json` work. At least one pair should contain a long rest, and one long rest in one JSON should have `measures_spanned_confident` set to `false` (edit it by hand if needed) so the '?' marker can be seen.
- [ ] Optional, for a more polished look: put a font (for example Inter) and a set of SVG icons (for example Lucide) in `reference/assets/`. Check their licences allow bundling. Without them the agent uses Godot's default font and draws minimal icons itself.
- [ ] When a prompt says so, start the server on the same network as the phone: `uvicorn api:app --host 0.0.0.0 --port 8000` with `ROBOFLOW_API_KEY` set.

## Shared Brief (paste once, save as docs/SPEC.md)

### 0. Repository layout and ground rules

```
chronocounter/
  docs/        SPEC.md  UI_GUIDE.md  SERVER.md  ANDROID.md  QA.md  UI_STATES.md  screenshots/
  godot/       the Godot 4.6.3 project; res:// maps to this folder
  reference/   pipeline/ (read-only Python)  native-camera/ (README + demo)  assets/ (optional fonts, icons)
```

- Paths like `docs/SPEC.md` are relative to the repository root. Paths starting `res://` are inside `godot/`.
- Treat `reference/` as read-only. Read the pipeline files to confirm numbering and the JSON shape, but never edit or run them, and never put an API key anywhere in the repository.
- The project already exists and the Native Camera Plugin is already installed. The user exports and installs the project personally: never edit export presets, the Android build template or the manifest, never touch SDK or JDK settings, and never try to build an APK or AAB. Anything else that needs the Godot editor UI (such as a plugin toggle) is the user's job too: list it instead of attempting it.
- At the start, check whether you can run `godot --headless` here. If you cannot, give exact commands for me to run and I will paste the output back.

### 1. What we are building

Chronocounter is a Godot 4.6.3 mobile app (typed GDScript, Compatibility renderer, portrait only, dark camera-style UI, Android first, iOS later; developed and tested on a Google Pixel 6a). The user photographs pages of sheet music, the app sends them one at a time to a FastAPI server on the local network, and the server returns detected bars and long rests. The app draws the detections over each photo, shows the running measure number at the start of every staff line (the main output), and lets the user fix mistakes by changing a long rest's length or deleting a detection. Everything lives in memory for the session. Only settings persist: the server URL, the mock-mode flag, the haptics switch and which first-run hints have been shown.

### 2. Server API (do not change the server)

- `POST {base_url}/count?initial_measure_number=N`, N >= 1.
- Body is the raw image bytes. Content-Type must be exactly `image/png`, `image/jpeg` or `image/webp` and must match the bytes. The server limit is 10 MB; the app keeps uploads at or under 9.5 MiB (9,961,472 bytes).
- A 200 response is a JSON array of staff lines, top to bottom. Each line is an array of detections, left to right: `{class, x, y, width, height, measure_number, measures_spanned?, measures_spanned_confident?}`. x and y are the box CENTER in pixels of the image that was sent. `measures_spanned` and `measures_spanned_confident` exist only on long rests. `measures_spanned_confident` is false when the server could not read the rest's number confidently and used a fallback guess. The app treats a missing value as true, so older fixtures still work, and the flag never affects numbering.
- Classes: `bar`, `repeat bar`, `double bar`, `long rest`, `long rest bottom`.
- Errors: 400 invalid or empty image, 413 over 10 MB, 415 wrong content type, 503 server has no Roboflow key. A request can take tens of seconds.
- The server runs with `uvicorn api:app --host 0.0.0.0 --port 8000` and the environment variable `ROBOFLOW_API_KEY`. Local network, plain HTTP.
- Constant `DEFAULT_API_URL = 'http://192.168.1.100:8000'`, editable in Settings.
- The `initial_measure_number` the app sends is provisional (see section 4). The app resolves the real initial number after each response and renumbers locally; it never displays the server's numbers.

### 3. Coordinates

The app displays exactly the image it uploaded, so detection coordinates map 1:1 to that image's pixels. No scaling anywhere. World space equals image pixel space.

### 4. Numbering rules

The server numbers detections with the algorithm below. Port it exactly into `NumberingEngine.gd` so the app can renumber locally after edits.

```
measure_num = initial; first_counted = true; pcls = 'fpbar'
for each line:
  for each detection d, left to right:
    cls = d.class
    d.measure_number = measure_num
    if cls is 'long rest' or 'long rest bottom':
      first_counted = false
      d.measures_spanned = n          # the editable duration
      measure_num += n
    elif cls is 'bar', 'repeat bar' or 'double bar':
      if not first_counted and pcls in {bar, repeat bar, double bar, 'pbar', 'fpbar'}:
        measure_num += 1
      d.measure_number = measure_num
      first_counted = false
    pcls = cls
  pcls = 'pbar'                       # reset at the end of every line
```

Extra rules the app adds on top:

- `end_measure(d)` is `d.measure_number + d.measures_spanned` for a long rest and `d.measure_number` for anything else. Use it everywhere a 'number after this detection' is needed. (The server's own hand-off uses the raw number, which is wrong after a long rest.)
- Page end value: `end_measure` of the rightmost detection in the last non-empty line. If the page has no detections, it is the page's own initial number minus 1, so an empty page passes the running count straight through.
- Page 1 initial number: 1 if the user ticked 'First bar is a pickup'. Otherwise 2, or 1 if the page's first detection is a long rest (so that rest starts at measure 1).
- Page N+1 initial number: `prev_end + 1`, where `prev_end` is the page N end value, or `prev_end` itself if page N+1's first detection is a long rest. The first detection is the leftmost detection of the page's first non-empty line. A page with no detections counts as starting with a bar.
- Provisional server initial: the app cannot know a page's first detection before the server answers, so it sends a provisional `initial_measure_number` (page 1: 1 with a pickup, otherwise 2; page N+1: `prev_end + 1`). After the response it resolves the real initial number with the rules above and renumbers locally. The two differ by exactly 1 whenever a page's first detection is a long rest, except on page 1 with a pickup, where they match. The server's numbers are never displayed. Server-parity checks compare against the provisional initial that was sent, so they must pass on every page.
- Line-start labels (drawn at the left of each staff line): the first non-empty line shows `first.measure_number - 1`, where `first` is its leftmost detection, unless `first` is a long rest, in which case it shows `first.measure_number`. A label can therefore be 0 (a pickup page). Each later non-empty line shows `end_measure` of the rightmost detection of the previous non-empty line. On every page after the first, the first label therefore equals the previous page's end value, matching `algorithm1.draw_measure_numbers`.
- Long-rest length is an integer from 1 to 999. Delete is allowed on every detection type. There is no add-detection feature.
- `needs_check`: a long rest is flagged when the server sent `measures_spanned_confident: false` (a missing value means not flagged). The flag only prompts the user to check the number and has no effect on numbering. Applying a length in the edit sheet clears it.
- After any edit, renumber ALL pages from page 1, because an edit changes every later page's initial number. This includes a delete that changes which detection is first on a page, since that can change the page's own initial number. Never call the server again after an edit.

### 5. Architecture and conventions

```
godot/ (this is res://)
  autoload/  Settings.gd  AppState.gd  ApiClient.gd  Router.gd  GestureState.gd  Haptics.gd
  logic/     DetectionData.gd  PhotoPage.gd  NumberingEngine.gd  ImageEncoder.gd  PageProcessor.gd
  theme/     DesignTokens.gd  app_theme.tres  fonts/  icons/
  ui/        PrimaryButton  SecondaryButton  IconButton  Pill  BottomSheet  Snackbar  ConfirmDialog  Spinner  SafeAreaContainer  HintOverlay
  scenes/    main_menu  capture  processing  results  detection_marker  edit_popup
  tests/     run_all.gd (runner), test_*.gd, ui_gallery.tscn, marker_sandbox.tscn
  fixtures/  test.png, phone_photo.jpg, exif6.jpg, mock_page_<i>.jpg|png + mock_page_<i>.json pairs, predictions_<initial>.json (supplied by me)
```

Docs live outside the project, in `../docs/` (see section 0).

- Strongly typed GDScript. Logic scripts have no scene dependencies (RefCounted or static) so they run headless.
- Tests run with `godot --headless -s res://tests/run_all.gd`. The runner (created in Prompt 1) is a `SceneTree` script that finds every `res://tests/test_*.gd`, instantiates it and calls `run() -> Array`, where each element is a Dictionary `{name: String, passed: bool, detail: String}`. It prints PASS or FAIL per case and exits non-zero if any case fails or any test script errors. After adding scripts that use `class_name`, run `godot --headless --import` once so the class cache is current.
- Signals up, calls down. Constants at the top of each file, no magic numbers. Debug prints only behind `OS.is_debug_build()`. Free textures and nodes when leaving a page.
- Never guess the Native Camera Plugin's API. Read its README and demo project and use only what they document.

### 6. Visual design: dark, camera-style, portrait only

The photo is the hero. Chrome stays dark, quiet and out of the way, like a camera app, with one accent color. Controls sit in the lower third of the screen (the thumb zone); the top bar holds only the back or menu button and status.

Units: the base viewport is 1080x1920 with `canvas_items` stretch, so on the Pixel 6a (about 411 dp wide) 1 dp is about 2.6 base px. Every size below is in base px.

| Token                                 | Value | Use |
| ------------------------------------- | ------------------------------------------------------------------------------------------------ | ------------------------- |
| bg                                    | #0E0F12 | Screen background |
| surface                               | #1A1C21 | Panels and sheets |
| surface\_raised                       | #252830 | Buttons, pills, fields |
| scrim                                 | #000000 at 60% | Behind modal sheets |
| text\_primary                         | #F2F3F5 | Main text |
| text\_secondary                       | #A4A9B4 | Captions, hints |
| accent                                | #FFC83D | Primary action, selection |
| accent\_ink                           | #1A1400 | Text on accent |
| danger                                | #FF5C5C | Delete |
| success                               | #4CD38A | Positive status |
| class colors (drawn over white paper) | bar #1E6BFF, double bar #8A3FFC, repeat bar #FF7A00, long rest #00A86B, long rest bottom #00A3A3 | Detection boxes |
| type sizes                            | caption 32, body 40, button 44, heading 56, title 72 | One font family |
| spacing                               | 12, 24, 36, 48, 72 | Margins and gaps |
| radius                                | 24 (36 on the top corners of sheets) | Panels, buttons |

Rules:

- Portrait only; never rotate.
- Every button and icon button has a hit area of at least 144 px (about 55 dp on the Pixel 6a; Android's minimum is 48 dp, about 126 px). Detection markers follow their own rule in Prompt 7.
- Keep UI clear of the status bar, camera cutout and gesture bar (safe areas). Controls that are swiped or dragged (such as the thumbnail strip) and the page arrows stay at least 96 px from the left and right screen edges, where Android's back-swipe gesture lives. Plain tap targets (buttons, switches, fields) only need the SafeAreaContainer side margin of 24 px.
- Text contrast at least 4.5:1. Never rely on color alone to show a state.
- Every screen has empty, loading and error states with short, plain, sentence-case copy.
- Motion: 150 ms screen fades, 200 ms sheet slides, ease-out, nothing over 250 ms.
- Icons are simple SVGs, 4 px stroke, 96 px box, in `res://theme/icons/`.
- Use only tokens from `DesignTokens.gd`; no hard-coded colors or sizes in scenes.

### 7. Target device: Google Pixel 6a

Sizes, performance targets and device tests assume a Google Pixel 6a. The figures come from published specs; wherever a prompt says to log or report a value, the real value on my phone wins over this table.

| Item | Pixel 6a | What it means for the app |
| --- | --- | --- |
| Screen | 6.1 in OLED, 1080x2400 (20:9), about 430 ppi, 60 Hz, punch-hole camera at top centre | With the 1080x1920 base size and `expand` aspect the viewport is 1080x2400. Layouts must stretch to the taller 20:9 shape and never assume 16:9. Target 60 fps (16.7 ms per frame); do not plan for 90 or 120 Hz. |
| Density | about 411 dp wide, so 1 dp is about 2.6 base px | 144 px is about 55 dp and 96 px is about 37 dp. Android's 48 dp minimum is about 126 px. |
| Android | ships with Android 12; has since been updated to Android 16 | Expect API 31 to 36, and API 36 on my phone unless updates are held back. Android 15 draws apps edge to edge when they target API 35, and Android 16 removes the opt-out for apps targeting API 36, so safe areas must be checked on the phone, not assumed. |
| Chip and memory | Google Tensor, 6 GB RAM, Mali-G78 GPU, 64-bit ARM | The Compatibility renderer is fine. A full 12 MP image decodes to about 48 MB, so hold at most one full-size decoded image at a time. |
| Rear camera | main 12.2 MP (4032x3024, 4:3) with OIS, plus a 12 MP ultrawide | Use the main camera. An upright portrait photo is 3024x4032. The 4:3 image does not match the 20:9 screen, so the live preview is cropped or letterboxed. |
| Navigation | gesture navigation by default, 3-button optional | Test both, including the back button and back gesture (set up in Prompt 1). Keep swipe and drag controls 96 px from the side edges and clear of the bottom gesture bar. |

## Prompt 1: Preflight check, scaffold and navigation

**Goal.** Confirm the manually created project is set up correctly, then add the app skeleton: autoloads, navigation between plain main-menu, capture and results screens, a persisted server-URL setting, a headless test runner, minimal back-button handling, and a short export checklist for you (the agent does not change any export settings).

**Steps**

1. Read `docs/SPEC.md`. **Preflight:** inspect `godot/project.godot` and `godot/addons/`, and report in a short table whether: the renderer is Compatibility; orientation is portrait only; base size is 1080x1920 with stretch mode `canvas_items` and aspect `expand`; the Native Camera Plugin folder exists and is enabled. You may fix plain-text settings in `project.godot` yourself. For anything that needs the editor UI (such as plugin toggles), list it for me and stop until I confirm. Do not inspect or edit export presets or `godot/android/`.
2. Create the folder layout from SPEC section 5 inside `godot/`. Do not touch `reference/`, and add files to `docs/` only when a step names them.
3. Autoload `Settings.gd` with `api_base_url` (default `DEFAULT_API_URL`), `mock_mode` (bool, default false), `haptics_enabled` (bool, default true) and `hints_seen` (Dictionary). Save and load through `ConfigFile` at `user://settings.cfg`.
4. Autoload `AppState.gd` with `pickup_first_bar: bool = false`, `pages: Array[PhotoPage]`, `current_page_index: int`, signal `numbering_changed`, `reset_session()`, and `first_page_provisional_initial() -> int` (1 if pickup, else 2: the provisional page-1 value sent to the server; never use it for display, the resolved value comes from `NumberingEngine.resolve_initial`). Add a stub `PhotoPage.gd` (RefCounted).
5. Autoload `Router.gd` with `goto(key)` wrapping `change_scene_to_file` for `main_menu`, `capture` and `results`.
6. Build plain, functional `main_menu.tscn` (title, 'Take photos', 'Settings' popup with a URL LineEdit, a 'Use mock server' checkbox and Save), plus placeholder `capture.tscn` and `results.tscn` with a Back button each. Styling comes in Prompt 2. Every button is already at least 144 px tall (about 55 dp).
7. Do not edit `export_presets.cfg`, `godot/android/` or any manifest; I export the project myself. Write `docs/ANDROID.md`, a short checklist of what the app needs from my export settings: the INTERNET, CAMERA and VIBRATE permissions, the Native Camera Plugin enabled for export, and cleartext HTTP allowed (`android:usesCleartextTraffic='true'` or the equivalent in my template), because the server is plain HTTP on the local network. Also note that the Pixel 6a is 64-bit ARM, so an arm64-v8a build is all it needs; that the phone is probably on Android 16 (API 36), where apps targeting API 36 are always drawn edge to edge and the safe-area code must handle it; and that I should check which target SDK my export uses and whether predictive back is enabled, because that affects the back button (step 10).
8. Write `docs/SERVER.md`: the start command, how to find the PC's LAN IP, a reminder to allow port 8000 through the firewall, and two Pixel 6a checks: it must be on the same Wi-Fi as the PC (a guest network or router 'client isolation' blocks it), and any VPN on the phone must be off while testing.
9. Debug builds only: log, and show in a small label at the bottom of the Settings sheet, a device report: `OS.get_model_name()`, `OS.get_version()`, `DisplayServer.screen_get_size()`, `DisplayServer.screen_get_dpi()` and the safe-area rectangle. This lets us confirm the real phone matches SPEC section 7.
10. Back button (minimal, so it can be tested early): in `project.godot` set `application/config/quit_on_go_back=false`. I believe this is the setting that stops Godot quitting on Android's back action; confirm the exact name in the 4.6.3 docs or editor and tell me if it differs. In `Router.gd`, handle `NOTIFICATION_WM_GO_BACK_REQUEST` (confirm that an autoload receives it): on the menu call `get_tree().quit()`; on Capture or Results go to the menu. Prompt 13 replaces this with confirmation dialogs.
11. Test runner: write `tests/run_all.gd` and `tests/test_smoke.gd` (one trivial passing case) following the contract in SPEC section 5. Later prompts only add `test_*.gd` files and do not touch the runner.

**Verify**

- The preflight table is complete and every missing item is listed. **\[You\]** Resolve those before moving on.
- The project opens in 4.6.3 with zero errors or warnings in the Output panel.
- Menu to Capture and back, and Menu to Results and back, work in the editor.
- Change the URL, close and reopen the app: the value persists.
- **\[You\]** After you export and install a build yourself, the app launches on your Pixel 6a, navigation works, and rotating the phone does not rotate the app.
- **\[You\]** With gesture navigation, and again with 3-button navigation: the back gesture or button on Capture or Results returns to the menu instead of closing the app, and on the menu it exits. If the app closes from Capture or Results, tell the agent (see the predictive-back note in `docs/ANDROID.md`).
- Run `godot --headless --import`, then `godot --headless -s res://tests/run_all.gd`: the smoke test prints PASS and the run exits 0. The agent also shows that a temporarily failing case makes it exit non-zero, then removes that case.
- **\[You\]** The debug device report on the Pixel 6a shows model 'Pixel 6a', a screen of about 1080x2400, a dpi in the 400s, a non-zero top safe-area inset and the Android version you noted in Preflight (probably 16). Paste it to the agent; if anything differs from SPEC section 7, the agent updates section 7 and `docs/UI_GUIDE.md`.
- `docs/ANDROID.md` lists the permissions, the plugin and the cleartext setting. **\[You\]** Make sure your own export has them.
- **\[You\]** With the server running, `http://<LAN-IP>:8000/docs` opens in the phone's browser on the same Wi-Fi.

## Prompt 2: UI foundation (dark camera-style theme and shared components)

**Goal.** One design system that every later screen reuses: tokens, theme, fonts, icons, safe-area handling and a small set of touch-friendly components, applied to the existing menu and settings.

**Steps**

1. Read `docs/SPEC.md` section 6. Write `theme/DesignTokens.gd` with every color, size, radius, spacing and duration from that section as constants, and build `theme/app_theme.tres` from them (Button, Label, CheckButton, LineEdit, PanelContainer, ProgressBar, ScrollContainer). Set it as the project's custom theme and set the default clear color to `bg`.
2. Fonts and icons: use the font and SVGs in `reference/assets/` if present. Otherwise use Godot's default font and draw simple SVG icons yourself in `theme/icons/` (chevron-left, chevron-right, close, trash, undo, reset-view, minus, plus, settings, check; 96 px box, 4 px stroke, white). Note any licences in `docs/UI_GUIDE.md`.
3. `SafeAreaContainer` (a MarginContainer): applies `DisplayServer.get_display_safe_area()` converted to viewport units plus a side margin (exported `side_margin`, default 24 px; use 96 px for areas holding swipe or drag controls, see SPEC section 6), and updates on resize. Every screen puts its UI inside one; full-bleed content (camera preview, photo) goes behind it.
4. Build these components as scenes with scripts under `ui/`: `PrimaryButton` (accent fill), `SecondaryButton` (raised surface), `IconButton` (144 px hit area, 96 px icon, optional filled circle), `Pill` (rounded label for counters and the page indicator), `BottomSheet` (slides up in 200 ms, drag handle, respects the bottom safe area, `open()` and `close()`, and a `modal` flag: true shows a scrim that closes the sheet on tap; false shows no scrim and does not block input outside the sheet), `Snackbar` (text plus an optional action, auto-dismisses after 5 s), `ConfirmDialog` (title, message, confirm and cancel, optional danger styling) and `Spinner` (a rotating arc drawn in `_draw`).
5. `autoload/Haptics.gd` with `tap()` and `heavy()` calling `Input.vibrate_handheld` (the VIBRATE permission must be enabled in your export; see `docs/ANDROID.md`); a no-op on desktop or when `Settings.haptics_enabled` is false.
6. Router: add a 150 ms fade between screens.
7. Restyle `main_menu.tscn`: wordmark, one PrimaryButton 'Take photos', one SecondaryButton 'Settings', and a small version label. Move the Settings popup into a BottomSheet (URL field, 'Use mock server' switch, Save).
8. Build `tests/ui_gallery.tscn` showing every component in each state (normal, disabled, pressed where relevant).
9. Write `tests/test_ui_rules.gd` (headless, following the runner contract in SPEC section 5): (a) the WCAG contrast of each text and background token pair is at least 4.5:1; (b) every interactive component's minimum size is at least 144 px in both directions.
10. Write `docs/UI_GUIDE.md`: the tokens, each component with usage, and the SPEC section 6 rules. All later prompts follow it.

**Verify**

- `godot --headless -s res://tests/run_all.gd` passes, including the contrast and touch-size tests.
- In the gallery, the BottomSheet opens and closes by scrim tap and by its handle, ConfirmDialog returns the user's choice, and the Snackbar dismisses itself.
- **\[You\]** On the Pixel 6a, nothing sits under the status bar, the centred camera punch-hole or the gesture bar, with both gesture and 3-button navigation, and the menu looks dark, calm and uncluttered.
- Screen changes fade, with no flash of default grey.
- Screenshots of the gallery and main menu at 1080x2400 (the Pixel 6a's native size) are saved to `docs/screenshots/` (if the agent can run Godot with a display; otherwise **\[You\]** take them on the phone), and you review them against SPEC section 6.

## Prompt 3: Image encoding and the photo model

**Goal.** Pure-logic code that turns any image (camera frame, PNG, JPEG, WebP) into upload-ready bytes: upright, correct MIME type, at most 9,961,472 bytes.

**Steps**

1. Read `docs/SPEC.md`. Flesh out `PhotoPage.gd`: `id`, `bytes: PackedByteArray`, `mime: String`, `width`, `height`, `thumbnail: ImageTexture`, `lines: Array` (empty until processed), `initial_measure_number: int`, `status` enum (PENDING, PROCESSING, DONE, FAILED) and `error_message`.
2. Write `ImageEncoder.gd` (static functions): `decode(bytes, mime) -> Image` and `encode_for_upload(image: Image, source_bytes := PackedByteArray(), source_mime := '') -> Dictionary` returning `{bytes, mime, width, height}` or `{error}`.
3. Rule 1: if the source is PNG and `source_bytes.size()` is within budget, return the original bytes unchanged with mime `image/png`.
4. Rule 2 (everything else): bake in orientation, convert to RGB8 (drop alpha), encode JPEG at quality 0.95, lowering by 0.05 down to 0.70 until it fits. If it still does not fit, scale the image by 0.9 (Lanczos) and retry at 0.85, repeating until it fits. Never let the shorter side fall below 1500 px; if that is the only way to fit, return `{error}`. 4a. Re-encoding strips EXIF, which is intended: the server's `cv2.imread` honours EXIF, so the uploaded pixels must already be upright with no tag.
5. Add `read_exif_orientation(bytes) -> int` (parse JPEG APP1 EXIF tag 0x0112, handle both byte orders, default 1) and `apply_orientation(image, o)` for values 2 to 8, because Godot ignores EXIF on load.
6. Log the chosen quality, scale, final size and the milliseconds spent decoding and encoding, in debug builds. A Pixel 6a photo is 4032x3024 (about 48 MB decoded), so run the work on one image at a time and release the decoded `Image` as soon as the bytes exist.
7. Write `tests/test_image_encoder.gd` (the runner `tests/run_all.gd` already exists from Prompt 1; follow its contract). Fixtures supplied by me: `test.png` (small), `phone_photo.jpg` (shot landscape, stored 4032x3024, EXIF orientation 1), `exif6.jpg` (shot upright in portrait, stored 4032x3024 with EXIF orientation 6). The test also generates a noisy 12 MB+ PNG in memory.

**Verify**

- `godot --headless -s res://tests/run_all.gd` prints PASS for every case and exits 0.
- `test.png` comes back byte-identical (hash equal) with mime `image/png`.
- The oversized noisy PNG comes back at most 9,961,472 bytes, mime `image/jpeg`, and decodes cleanly.
- `phone_photo.jpg` output has no orientation tag (re-parse returns 1) and keeps its dimensions (4032x3024).
- `exif6.jpg` output has width and height swapped versus the raw decode. The test saves it to `user://debug/` and the agent tells me the path.
- With the Pixel 6a fixtures, the agent reports for each the EXIF orientation found, the chosen quality, the final byte size and the encode time. A normal portrait shot from the Pixel's camera app should read orientation 6 and come out 3024x4032.
- **\[You\]** Open the saved exif6 output and confirm it is visually upright. Then run `curl -X POST -H 'Content-Type: image/jpeg' --data-binary @out.jpg 'http://HOST:8000/count?initial_measure_number=1'`; it must return 200 with JSON.

## Prompt 4: Camera capture screen and photo list

**Goal.** A capture screen with a live native-camera preview, a shutter button, the pickup toggle, and a thumbnail strip where photos can be deleted or retaken. Captured photos are stored in `AppState.pages`.

**Steps**

1. Read `docs/SPEC.md` and `docs/UI_GUIDE.md`. The Native Camera Plugin is already installed in `godot/addons/`: confirm it is enabled and read its README in `reference/native-camera/` before coding. Request the CAMERA permission at runtime; if denied, show an in-screen message with a PrimaryButton to ask again and a SecondaryButton to open the app's system settings.
2. Write `CameraService.gd` hiding the plugin behind this interface: signals `photo_captured(image: Image)` and `capture_failed(reason: String)`; methods `start_preview()`, `stop_preview()`, `capture()`. Capture grabs the latest frame at the highest resolution the plugin supports (aim for 3000 px or more on the long side), with rotation set so the image is upright for the way the phone is held. The Pixel 6a's main rear camera is 12.2 MP (4032x3024): request the largest still the plugin offers, expect about that size, and log the actual width and height.
3. Add an editor and desktop fallback in the same service: when not on Android, `capture()` opens a `FileDialog` (png, jpg, jpeg, webp). A file import passes its original bytes and mime to `ImageEncoder.encode_for_upload` so PNG pass-through works.
4. Build `capture.tscn` like a camera app, using the shared components inside a SafeAreaContainer. The live preview runs full-bleed behind everything with its correct aspect ratio (cropped or letterboxed, never stretched). A translucent top bar holds a Back IconButton and a Pill with the page count. Four thin corner brackets inset 48 px act as a framing guide, with a plain caption 'Fill the frame with the page' (hidden after the first capture; Prompt 12 replaces it with a HintOverlay). A bottom panel (surface at 85% opacity, rounded top corners, no taller than 45% of the screen) holds, top to bottom: the thumbnail strip (it scrolls sideways, so inset it 96 px from the left and right screen edges); the pickup switch labelled 'First bar is a pickup', bound to `AppState.pickup_first_bar` (default off); a centred 216 px shutter button (white ring, accent centre); and a full-width PrimaryButton 'Process N pages' (disabled at 0 pages). Cap at 30 pages with a clear message.
5. On shutter: `Haptics.tap()` and an 80 ms white flash. Run `encode_for_upload` on a worker thread (`WorkerThreadPool`) with a Spinner, then create a `PhotoPage` (encoded bytes, mime, size, thumbnail of at most 256 px) and append it. Do NOT keep full-size `Image` objects around.
6. Tapping a thumbnail opens a modal BottomSheet with a larger preview, a danger 'Delete' button and a 'Retake' button. Retake replaces that page in place; Delete renumbers the badges. No reordering.
7. 'Process N pages' only logs the pages for now (wired in Prompt 6). Back with pages present opens the shared ConfirmDialog before discarding.
8. Stop the preview on pause and restart it on resume.
9. If the plugin's README documents torch and tap-to-focus, add them as IconButtons. If it does not, leave them out and say so in `docs/UI_GUIDE.md`; do not fake them.

**Verify**

- **\[You\]** First run shows the permission prompt; deny shows the retry message without crashing; allow shows a live, upright preview in portrait that is not stretched.
- **\[You\]** The framing guide is visible, the controls sit in the lower part of the screen, nothing is under the status bar or gesture area, and the panel text is readable over a bright preview.
- **\[You\]** Take 3 photos: each gives a flash and a haptic tap, and 3 thumbnails appear with badges 1 to 3. Logs show each upload at most 9,961,472 bytes, mime `image/jpeg`, and a size of about 3024x4032 (portrait) with the milliseconds spent encoding; the UI keeps animating while it runs.
- **\[You\]** Delete page 2: badges become 1, 2. Retake page 1: its thumbnail changes and the count stays the same.
- Toggling the pickup switch makes `AppState.first_page_provisional_initial()` log 1 or 2.
- **\[You\]** Backgrounding and returning to the app does not crash or freeze the preview.
- In the editor, importing `test.png` and a JPEG both work.
- **\[You\]** The 4:3 preview fills the 20:9 screen by cropping or letterboxing, never stretching, and the saved photo still contains everything inside the framing brackets.
- After 10 captures, the agent reports static memory from `Performance` monitors; growth must be roughly the encoded bytes plus thumbnails, not 10 full images.
- `tests/test_ui_rules.gd` still passes with every new button at least 144 px.

## Prompt 5: Numbering engine (pure logic, with tests)

**Goal.** `NumberingEngine.gd` that reproduces the server's numbering exactly and can renumber every page after edits.

**Steps**

1. Read `docs/SPEC.md` section 4 carefully. Write `DetectionData.gd` (RefCounted): `id`, `cls`, `x`, `y`, `w`, `h` (center-based, as the API returns), `measures_spanned` (int; 1 default for long rests, 0 otherwise), `measure_number` (computed), `server_measure_number` (as received), `edited: bool`, `needs_check: bool` (true for a long rest when the server sent `measures_spanned_confident: false`; a missing value means false; cleared when the user applies a length), signal `changed`, `static from_json(dict)`, `is_long_rest()`, `is_bar()`, `end_measure()`.
2. Write `NumberingEngine.gd` with static functions: `number_page(lines, initial)` annotating in place with the exact pseudocode; `resolve_initial(lines, page_index, prev_end, pickup) -> int` implementing the page initial rules in SPEC section 4 (page 1 ignores `prev_end`); `end_value(lines, initial) -> int` (`initial - 1` for a page with no detections); `line_start_labels(lines) -> Array` (one entry per line, `-1` for empty lines; the first non-empty line follows the top-label rule in SPEC section 4); and `number_all_pages(pages, pickup)`, which for each page in order resolves its initial number from the previous page's end value, numbers the page, and stores `page.initial_measure_number`.
3. Port the quirks exactly: `first_counted` is global to the page; `pcls` starts as `fpbar` and is reset to `pbar` after every line; a bar after a long rest does not increment.
4. Write `tests/test_numbering.gd` with the cases below. Notation: B = bar, R(n) = long rest spanning n, RB(n) = long rest bottom spanning n; a `/` separates lines.
5. Add a parity test: for each `fixtures/predictions_*.json` (real pipeline output, saved with the initial number that was sent in the file name), run `number_page` with that initial and assert every detection's computed number equals the JSON `measure_number`.
6. Add an invariant test: for every multi-page case in the table, the first line-start label of each page after the first equals the previous page's end value, and for page 1 it equals the first detection's number minus 1 (or the number itself if that detection is a long rest).
7. Write `tests/test_detection_data.gd`: `from_json` gives `needs_check` true when `measures_spanned_confident` is false, false when it is true or missing, and false for a bar even if the flag is present.

| Case | Input | Settings | measure\_number per detection | End value | Line-start labels |
| --- | --- | --- | --- | --- | --- |
| A | B,B,B / B,B | initial 1 | 1,2,3 / 4,5 | 5 | 0, 3 |
| B1 (server parity) | R4,B,B / B,RB2,B | initial 2 | 2,6,7 / 8,8,10 | 10 | 2, 7 |
| B2 (resolved initial) | R4,B,B / B,RB2,B | page 1, no pickup (`resolve_initial` gives 1) | 1,5,6 / 7,7,9 | 9 | 1, 6 |
| D | B,R3 / B,B | initial 1 | 1,1 / 5,6 | 6 | 0, 4 |
| G | B,R2 | page 1, no pickup (first detection is a bar, so initial 2) | 2,2 | 4 | 1 |
| Edit | A with the 2nd bar of line 1 deleted | initial 1 | 1,2 / 3,4 | 4 | 0, 2 |
| Chain 1 | p1 = A; p2 = B,B / B; p3 = R2,B | pickup | p1 as A; p2 initial 6: 6,7 / 8; p3 initial 8 (first is a long rest): 8,10 | 5, 8, 10 | p1: 0, 3; p2: 5, 7; p3: 8 |
| Chain 2 | p1 = A; p2 empty; p3 = B | pickup | p2 initial 6, end 5; p3 initial 6: 6 | 5, 5, 6 | p1: 0, 3; p3: 5 |
| Chain 3 | p1 = R4,B; p2 = B | no pickup | p1 initial 1 (first is a long rest): 1,5; p2 initial 6: 6 | 5, 6 | p1: 1; p2: 5 |

**Verify**

- Every row in the table has a PASS line in the headless run, so does the invariant test, the `needs_check` cases pass too, and the run exits 0.
- The parity test passes against at least one real fixture, or the agent states plainly that no fixture was supplied and asks me for one.
- **\[You\]** Give the agent one `predictions.json` from your Python pipeline that contains a long rest, rename it `predictions_<initial>.json`, and confirm the parity test passes on it.
- The agent shows that `number_all_pages` after deleting a detection on page 1 changes page 2's `initial_measure_number` in the Chain 1 setup (the Edit row's end value 4 gives page 2 initial 5 instead of 6).

## Prompt 6: API client and sequential page processing

**Goal.** Send the stored photos to the server one by one with chained initial numbers, show progress, and stop with a retry option on any failure. Include a mock mode so the rest of the app can be built and tested without the server.

**Steps**

1. Read `docs/SPEC.md`. Write the `ApiClient.gd` autoload with `send_page(bytes, mime, initial) -> Dictionary` (awaitable, returns `{ok, lines, status, error}`). Create one `HTTPRequest` per call with a 120 s timeout and call `request_raw(url, ['Content-Type: ' + mime], HTTPClient.METHOD_POST, bytes)`. The URL is the base URL without a trailing slash plus `/count?initial_measure_number=` and N.
2. Parse the JSON strictly (array of arrays of dictionaries with all required keys; `measures_spanned_confident` is optional and must be a bool when present) and convert with `DetectionData.from_json`. Map errors to friendly messages: 400, 413, 415 and 503 as described in SPEC; connection failure ('Can't reach server at URL. Same Wi-Fi? Is it running?'); timeout; malformed JSON. Add `cancel()`.
3. Add `test_connection()` (GET base URL + `/docs`) and a 'Test connection' button in the Settings popup that shows OK or the failure reason.
4. Mock mode: when `Settings.mock_mode` is on, do not use the network. Wait 1.5 s, then use fixture pair number `i modulo (number of pairs)`: return `res://fixtures/mock_page_<n>.json` as the detections AND replace the page's `bytes`, `mime`, `width`, `height` and `thumbnail` with the paired `mock_page_<n>.jpg` or `.png`, so the boxes line up with the image that is shown. The camera photo is dropped for that session.
5. Write `PageProcessor.gd` (RefCounted; signals `progress(i, n)`, `page_done(i)`, `failed(i, message)`, `finished`). Pages are processed strictly in order. The initial number sent to the server is provisional: page 0 sends `AppState.first_page_provisional_initial()`; page i > 0 sends `prev_end + 1`, where `prev_end` is the end value of page i-1 computed locally from its resolved numbering. After each response, store the lines on the page, compute `initial = NumberingEngine.resolve_initial(page.lines, i, prev_end, AppState.pickup_first_bar)`, run `NumberingEngine.number_page(page.lines, initial)`, and set `page.initial_measure_number = initial`.
6. Debug-only parity check: on a deep copy, number with the provisional initial that was sent and compare with each detection's `server_measure_number`. Log `PARITY OK page i` or `PARITY MISMATCH page i`. Skip the check in mock mode (the fixture numbers were computed with a different initial) and log `PARITY SKIPPED (mock) page i`. With the real server a mismatch is always a real problem.
7. On failure, stop immediately, mark that page FAILED, keep completed pages, and emit `failed`. `retry()` resends the same page with the same initial number and then continues.
8. Build `processing.tscn`: 'Processing page i of n', a ProgressBar, the shared Spinner, a thumbnail of the page being sent, and Cancel (aborts the request and returns to capture with photos intact). The error dialog (the shared ConfirmDialog, with plain-language copy) offers Retry and Back to photos. Wire 'Process N pages' to this screen, and go to Results when finished. Finish by calling `NumberingEngine.number_all_pages` so state is consistent.

**Verify**

- Mock mode with 3 photos reaches the Results screen and the spinner keeps animating the whole time. Each page then shows its paired fixture image with the boxes on the bars, and the parity log says SKIPPED.
- **\[You\]** Real server, 2 photos: the console shows `initial_measure_number=1` (with pickup) or 2 (without) for page 1, and page 2's request value equals page 1's end value plus 1. The agent prints both, together with each page's resolved initial number.
- With the real server, parity logs say OK on every page.
- **\[You\]** Stop uvicorn mid-run: the error dialog appears. Restart the server and tap Retry: processing resumes at the failed page, and the server log shows page 1 was not requested again.
- A wrong URL gives the friendly 'Can't reach server' message with no crash. 'Test connection' reports OK and failure correctly.
- A file-imported PNG and a camera JPEG both process successfully; the agent logs the mime sent for each.
- Cancel returns to the capture screen with all photos intact.

## Prompt 7: The detection marker scene

**Goal.** A reusable `detection_marker.tscn` that is instantiated once per detection, takes only the detection data, renders itself, and reports taps.

**Steps**

1. Read `docs/SPEC.md` and `docs/UI_GUIDE.md`. The root node is a `Control` with `DetectionMarker.gd`. `setup(data: DetectionData)` is the only input: it sets `position = (x - w/2, y - h/2)` and `size = (w, h)`. Class, duration, x, y, width and height all come from `data`.
2. Take colors from the class colors in `DesignTokens.gd`. The selected state is a 6 px amber outline over a 2 px dark outer stroke, so it reads on white paper.
3. Draw in `_draw()`: a 25% translucent fill and an outline. Keep the outline about 2 screen pixels at any zoom by scaling its width by 1/zoom. The viewer calls `set_view_zoom(z)` and the marker redraws.
4. Long rests always show a '×N' badge at the centre (N = `measures_spanned`) on a dark pill with white text, so it stays legible on paper. When `data.needs_check` is true the badge reads '×N ?', with the '?' in the `accent` color; the symbol, not the color, is the cue. A `show_labels` property (default false) additionally draws the class above the box and `m<measure_number>` below it, on the same dark pill. Text size is about 30 screen px divided by zoom.
5. Markers do not handle input themselves (`mouse_filter = IGNORE`). A separate `MarkerPicker.gd` does the picking for all markers on a page. A tap is a single finger down and up within 12 px and 400 ms. The picker selects the marker whose box is nearest to the tap, within a pick radius of at least 96 screen px (about 37 dp on the Pixel 6a; convert to world units with the current zoom), with the smaller box winning ties. It calls `marker.tap()`, which emits `tapped(marker)`. It ignores taps while `GestureState.multitouch_active` is true (create `GestureState` as a tiny autoload now; Prompt 11 will drive it).
6. Give each marker `hit_distance(world_point) -> float` (0 inside the box, otherwise the distance to it), `set_selected(bool)` and `refresh()`. The marker also refreshes itself when `data.changed` fires.
7. Build `tests/marker_sandbox.tscn`: a white 'paper' rectangle with one marker per class at different sizes, a very thin bar about 6 px wide, two bars about 40 px apart, a long rest with `needs_check` set, a zoom slider that scales the parent node, and a MarkerPicker.

**Verify**

- Five distinct colors show on the white paper, and both long-rest types show ×N.
- Moving the zoom slider keeps outlines about 2 px on screen.
- The thin bar can be selected at zoom 0.3 from up to about 96 screen px away. With the two close bars, tapping nearer to one selects that one.
- A tap far from every marker selects nothing.
- The selected marker is clearly visible on white paper.
- Toggling `show_labels` shows and hides the class and `m#` text.
- Changing `data.measures_spanned` in code updates the badge without re-instancing.
- A long rest with `needs_check` shows '×N ?'; clearing the flag in code removes the '?' without re-instancing.

## Prompt 8: Results viewer and page navigation

**Goal.** The Results screen shows one page at a time: the photo with all markers aligned on it, a page indicator, left and right arrow buttons, and a labels toggle.

**Steps**

1. Read `docs/SPEC.md` and `docs/UI_GUIDE.md`. In `results.tscn`, make a `Node2D` world with a `Camera2D`, plus a `CanvasLayer` for UI inside a SafeAreaContainer. The dark `bg` color shows behind the photo. World units are image pixels.
2. The world holds a `Sprite2D` (centered off, at the origin) whose texture is decoded on demand from the current page's bytes; a `Markers` node holding one `detection_marker` per detection in every line of the page; and the `MarkerPicker` from Prompt 7. Free the previous page's markers and texture on every page change so only one full texture exists at a time.
3. UI, camera-app style: a translucent top bar with a menu IconButton (placeholder until Prompt 13) and a centred Pill such as '2 / 5'. A bottom control cluster in the thumb zone holds an IconButton 'Reset view' (wired in Prompt 11) and a 'Labels' toggle that sets `show_labels` on all markers. The left and right page arrows are 144 px IconButtons, vertically centred and at least 96 px in from the screen edges (clear of Android's back-swipe zone), drawn as 60% opaque dark circles with white chevrons. They dim to 30% after 2 s without touch, brighten on touch, and disable at the first and last page.
4. `fit_to_screen()` sets the zoom so the image width fits the viewport and positions the image at the top. On the Pixel 6a a 3024x4032 photo fits at about 0.36x, leaving the lower part of the 1080x2400 viewport for the controls. Call it on every page change. Emit `view_zoom_changed(zoom)` from the camera controller and forward it to every marker.
5. Show a Spinner if decoding takes over 100 ms. Keep `AppState.current_page_index` up to date so returning from popups restores the page.
6. Pages whose status is not DONE, or that have no detections, show a clear empty-state message ('No bars or rests found on this page') in the shared style but can still be navigated.

**Verify**

- With mock fixtures, boxes sit exactly on the bars; compare with `test_debug.png` from the Python pipeline for the same image and they coincide.
- Arrows move between pages, are disabled at both ends, and the indicator is correct.
- Going 3 to 2 to 3 repeatedly does not grow memory (the agent shows texture memory from `Performance` staying flat).
- The Labels toggle shows and hides class and `m#` on all boxes of the current page.
- A PNG-sourced page and a JPEG-sourced page both display correctly (not rotated or offset).
- **\[You\]** A full-size 3024x4032 Pixel 6a photo loads and displays on the phone without a black texture or a crash.
- **\[You\]** On the phone, swiping in from the screen edge triggers Android's back gesture instead of a page arrow, the arrows are easy to hit with a thumb, and the control cluster is reachable one-handed.

## Prompt 9: Line-start measure numbers (the main output)

**Goal.** Draw the measure number at the start of each staff line, following `algorithm1.draw_measure_numbers`, and keep it correct after edits.

**Steps**

1. Read `docs/SPEC.md` section 4 (line-start labels). Add `LineNumberOverlay.gd` as a `Node2D` child of the world, above the photo and below the markers.
2. `refresh(page)` calls `NumberingEngine.line_start_labels(page.lines)`. For each non-empty line, draw the number at x = 15 image pixels from the left edge, vertically centred on the mean y of that line's detections (this mirrors `algorithm1.draw_measure_numbers`). A label of 0 is valid and is drawn.
3. Font size in image pixels: `clamp(median_detection_height * 0.7, 20, 72)`. Use dark text with a light halo so it stays legible over a photo.
4. Connect to `AppState.numbering_changed` and call `refresh` on the current page. Also refresh on page change.
5. Keep the label logic in one function (`line_start_labels`) so changing the rule later is a one-line edit.

**Verify**

- A line that follows a line ending in a long rest shows start + span (use a fixture that has one, or craft one and say so).
- The first line shows one less than its first detection's number, unless that detection is a long rest, in which case it shows that detection's number. With a pickup and a first bar, page 1's top label is 0.
- On every page after the first, the first line's label equals the previous page's end value, whether that page starts with a bar or a long rest.
- Toggling the pickup switch on the capture screen and reprocessing shifts the numbers by the expected amount.
- Numbers are readable at fit-to-screen zoom on a phone and are not clipped at the image edge.
- **\[You\]** Run the Python pipeline on one of your test images and compare its `output.png` with the app on the same image and the page's resolved initial number (see SPEC section 4) passed to the pipeline: same values, same line positions.

## Prompt 10: Edit popup and live renumbering

**Goal.** Tapping a marker opens a bottom sheet where a long rest's length can be changed or any detection can be deleted, and all numbers update everywhere.

**Steps**

1. Read `docs/SPEC.md` and `docs/UI_GUIDE.md`. When the MarkerPicker emits `tapped`, select that marker (the previous one deselects), call `Haptics.tap()`, and open `edit_popup.tscn`, built on the shared BottomSheet with `modal = false` so the photo stays visible and gestures still work outside the sheet. If the marker would be hidden behind the sheet, pan the camera so it stays visible.
2. Sheet contents: a header with the class color dot, the type name and 'Measure N' (plus, for a long rest with `needs_check`, a line under it: 'Couldn't read this number with confidence. Check it against the page.'); for long rests, a stepper with 144 px minus and plus IconButtons, a numeric field (number keyboard) and an Apply PrimaryButton; a danger 'Delete' SecondaryButton for every type; and a Close IconButton. Tapping empty photo space also closes the sheet; tapping another marker switches the selection.
3. Validation: only integers 1 to 999 are accepted; show an inline message and keep the sheet open on invalid input.
4. Apply sets `data.measures_spanned`, `data.edited = true` and `data.needs_check = false` (applying the same number confirms it). Delete removes the detection from its line (dropping empty lines) and calls `Haptics.heavy()`. After either, call `NumberingEngine.number_all_pages(AppState.pages, AppState.pickup_first_bar)` and emit `AppState.numbering_changed`.
5. After a delete, show the shared Snackbar with an Undo action (5 s). Before deleting, record the page, the line index, the detection's index within its line, and whether the line becomes empty and is dropped; Undo reinserts the detection at that position (recreating the line at its original index if it was dropped) and renumbers again. Only the most recent delete can be undone: a new delete makes the previous one permanent. Edited long rests show a small dot on their badge.
6. The viewer refreshes the current page's marker labels and the line-number overlay on `numbering_changed`. Other pages update when visited (their data is already renumbered).
7. While the current page has long rests with `needs_check`, show a Pill 'N to check' beside the page indicator (hidden at 0), refreshed on `numbering_changed` and on page change.

**Verify**

- Tap a long rest: the sheet shows its current length. Set 6: the badge shows ×6, later numbers on that page shift by the difference, and page 2's first line label shifts too.
- Delete a bar: every later number on the page drops by 1 and later pages' initial numbers drop accordingly (agent prints each page's `initial_measure_number` before and after).
- Delete the first bar on page 1: the next detection takes the page's newly resolved initial number (1 with a pickup; otherwise 2 if it is a bar, or 1 if it is a long rest).
- Deleting the first bar of a page after page 1 so that a long rest becomes its first detection lowers that page's initial number by 1 (`prev_end + 1` becomes `prev_end`) and shifts every later page. Deleting a first long rest so that a bar becomes first raises it by 1. The agent prints the page's initial number before and after, and the page's first label still equals the previous page's end value.
- Undo restores the detection and every number returns to its earlier value.
- Delete the only detection on a line, then Undo: the line comes back at its original index. Delete two detections within 5 s: Undo restores only the second.
- A long rest the server flagged shows '×N ?' and the page's 'N to check' Pill, and its sheet shows the warning line. Apply (even with the same number) removes the '?' and lowers the count; deleting a flagged rest lowers it too.
- 0, 1000, empty and non-numeric input are rejected with a message.
- Deleting a long rest that ends a page changes the next page's initial number.
- A thin bar can be tapped at fit-to-screen zoom and the sheet does not cover the tapped marker.
- `godot --headless -s res://tests/run_all.gd` still passes.

## Prompt 11: Pinch zoom and two-finger pan

**Goal.** Two fingers zoom and move the view; one finger never moves it, so single taps stay reserved for selecting detections.

**Steps**

1. Read `docs/SPEC.md`. Add `ViewController.gd` on the `Camera2D`. Track touches by index from `InputEventScreenTouch` and `InputEventScreenDrag`.
2. With exactly two fingers down: zoom by the ratio of the finger distance to the previous frame, anchored on the midpoint (the world point under the midpoint stays under it), and pan by the midpoint's movement. Clamp zoom between half the fit-to-screen zoom and 8x. Keep at least 25 percent of the image on screen.
3. Set `GestureState.multitouch_active` to true when a second finger goes down and clear it 150 ms after all fingers are up. Markers must ignore taps while it is true. Never open a popup when a pinch starts or ends on top of a marker.
4. Touches that begin on the edit sheet or UI buttons are not consumed by the camera.
5. Wire the 'Reset view' icon button from Prompt 8 so it calls `fit_to_screen()`. A page change also resets the view.
6. Desktop testing: mouse wheel zooms at the cursor, and middle or right mouse drag pans.
7. Emit `view_zoom_changed` on every zoom change so markers keep constant-size outlines and labels.

**Verify**

- **\[You\]** On the phone: pinch to 8x and back; the content under the fingers stays put. Two-finger drag pans. One-finger drag does nothing to the view.
- **\[You\]** Starting a pinch with a finger on a marker never opens the edit sheet, and lifting one of the two fingers does not either.
- **\[You\]** Reset view returns to the fit view. You cannot drag the image completely off screen.
- Outlines stay thin and labels stay readable at 0.5x and 8x.
- The agent reports frame time with 150 or more markers visible. **\[You\]** On the Pixel 6a (a 60 Hz screen) the debug build shows about 60 fps (`Engine.get_frames_per_second()`) while pinching and panning, with no visible stutter.
- **\[You\]** A two-finger pan that starts near the screen edge does not trigger Android's back gesture; if it does, tell the agent so it can move the gesture's activation area inward.
- Arrow buttons and Labels toggle still work during and right after gestures.

## Prompt 12: UX polish and visual review

**Goal.** First-run guidance, friendly empty and error states, haptics and motion, and a screenshot-based visual review, so the app feels finished and is easy to use one-handed.

**Steps**

1. Read `docs/SPEC.md` and `docs/UI_GUIDE.md`. Build `HintOverlay` (a small coach-mark card in the shared style, dismissed by tapping anywhere) and show each hint once, recording it in `Settings.hints_seen`: on the capture screen 'Fill the frame with the page. Keep it flat and well lit.' (replacing the plain caption from Prompt 4); the first time Results opens, 'Pinch with two fingers to zoom. Drag with two fingers to move.'; and the first time a page with detections is shown, 'Tap a box to change a rest's length or delete it.' Add 'Show hints again' to Settings.
2. List every screen and each of its states (empty, loading, error, normal) in `docs/UI_STATES.md`, then implement any that are missing: capture with 0 photos ('Take a photo of each page, in order'), camera permission denied, server unreachable (with an action that opens the Settings sheet), a failed page, and a page with no detections.
3. Haptics: shutter, selection, Apply and Undo use `Haptics.tap()`; Delete uses `Haptics.heavy()`. Add a 'Haptics' switch in Settings, bound to the persisted `Settings.haptics_enabled`.
4. Motion: page changes cross-fade in 150 ms (the screen-fade token), sheets slide in 200 ms, snackbars slide up, nothing animates longer than 250 ms, and no animation blocks input.
5. Audit and fix against `docs/UI_GUIDE.md`: touch targets, spacing from the token scale, alignment, safe areas, text contrast, and consistent copy (short, sentence case, no technical jargon). List each fix you make.
6. Build `tests/screenshot_tour.tscn`, which walks through the app with mock data and saves 1080x2400 screenshots (the Pixel 6a's native size) to `docs/screenshots/`: main menu, settings sheet, capture with 3 thumbnails, processing, results fit-to-screen with labels off, results zoomed in with a selected marker and the edit sheet open, the delete snackbar, and an error dialog. If you cannot run Godot with a display, say so and I will capture the same eight screens on the phone.
7. Review the screenshots as a design critic would: is the photo the focus; is anything cramped, clipped or low-contrast; are primary actions obvious; do all screens look like one app? Fix what you find and re-shoot.

**Verify**

- **\[You\]** Review the screenshots: consistent dark theme, the photo as the visual focus, one accent color, no clipped text, comfortable spacing.
- **\[You\]** On a fresh install each hint appears once, does not return after a restart, and 'Show hints again' brings them back.
- Every state in `docs/UI_STATES.md` has been seen at least once, and the agent says how it triggered each.
- **\[You\]** Haptics feel right on the Pixel 6a and the Settings switch turns them off. If nothing vibrates at all, check the phone's own vibration and haptics settings before blaming the app.
- `godot --headless -s res://tests/run_all.gd` passes, contrast and touch-size tests included.
- **\[You\]** One-handed test: using only your thumb, you can take a photo, process it, change a rest's length and return to the menu.

## Prompt 13: Return to menu, session lifecycle and final QA

**Goal.** Clean exit from the results back to the main menu, correct Android back-button behaviour, a fresh session each time, and a documented end-to-end test.

**Steps**

1. Read `docs/SPEC.md`. Wire the results top-bar menu button to the shared ConfirmDialog ('Discard photos and results?') with Cancel and 'Back to menu'. Confirming calls `AppState.reset_session()` (frees pages, bytes and textures) and goes to the main menu.
2. Extend the back handling from Prompt 1 (`application/config/quit_on_go_back` is already false and the Router already receives `NOTIFICATION_WM_GO_BACK_REQUEST`): on Results show the same confirmation; on Capture confirm if pages exist, otherwise return to the menu; on the menu quit with `get_tree().quit()`. Also call `get_tree().set_auto_accept_quit(false)` so a desktop window-close request can be intercepted the same way. If the system back gesture closes the app without reaching this code (a predictive-back setting in my export), tell me so I can check my export.
3. A new session starts clean: capture list empty, pickup switch back to its default, camera preview restarts.
4. Handle `NOTIFICATION_APPLICATION_PAUSED` and `RESUMED` for the preview and any in-progress processing (pause or show the retry dialog; never crash).
5. Remove stray debug output (keep it behind `OS.is_debug_build()`), and run all headless tests.
6. Write `docs/QA.md` containing the end-to-end checklist below and a short README with setup steps for the server, the phone and the plugin.

**Verify** (all **\[You\]** on your Pixel 6a, with the real server)

- Pickup on, 3 photos, Process: numbers chain across pages (the first label of page 2 equals page 1's end value, and the first label of page 3 equals page 2's end value).
- Change one long rest's length and delete one bar: all pages renumber and the later pages' starting numbers shift.
- Pinch, pan, tap a thin bar at high zoom, and edit it.
- Menu button and back button both show the confirmation; confirming returns to the main menu with a clean state. Check the back button with gesture navigation and again with 3-button navigation.
- Start a second session without restarting the app; it behaves identically.
- The agent reports memory (`OS.get_static_memory_usage()`) before the first session and after reset; they should be close. **\[You\]** Run three sessions of 10 photos each in a row to confirm the Pixel 6a's 6 GB of RAM is never a problem.
- All headless tests pass and `docs/QA.md` is complete.

## Appendix A: things to watch

- **Pickup label.** With a pickup, page 1's top label is 0 (the pickup measure). This is intended.
- **Server numbers versus app numbers.** The app sends a provisional initial number (page 1: 1 with a pickup, otherwise 2; later pages: previous end + 1) and renumbers locally from the resolved one. The two differ by exactly 1 on any page whose first detection is a long rest (except page 1 with a pickup, where they match), by design. The app's local numbers are the ones displayed; parity checks compare against the provisional initial that was sent and must pass on every page.
- **Confidence threshold.** `CONFIDENT_MIN = 0.6` in algorithm2 is a starting guess. After a few real runs, look at the `measure_count_confidence` values and adjust it so that few correct readings are flagged and few wrong ones slip through.
- **Plain HTTP on Android.** Needs the cleartext setting in your own export (listed in `docs/ANDROID.md`). For iOS later you would also need an App Transport Security exception and a camera usage description.
- **Pixel 6a numbers.** SPEC section 7 comes from published specs. If the debug device report from Prompt 1 disagrees (different dpi, safe area or Android version), update section 7 and `docs/UI_GUIDE.md` before continuing.
- **Plugin API.** Prompt 4 depends on what the Native Camera Plugin actually documents. If it cannot capture a full-resolution still, the agent should say so and propose the nearest alternative instead of guessing.
