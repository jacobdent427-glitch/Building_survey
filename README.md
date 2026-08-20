# Building Survey App

A Flutter app for on-site building condition surveys, matching the workflow from
`Hierachy Database 210305.xlsx` and `app rough output.xlsx`.

## Workflow

1. **Surveyor entry** — enter a surveyor ID, then start a new project or resume a
   saved one.
2. **New project** — site reference and address.
3. **Buildings** — add a building reference, or mark the location as "External".
   Edit or delete any building from its list entry.
4. **Rooms** — add a room reference, floor, and (optionally) a what3words
   location. Edit or delete any room from its list entry.
5. **Components** — for each component: take 3 reference photos, then search the
   maintenance hierarchy database (Group -> System -> Element -> Sub-Element ->
   Component -> Sub-Component), then record quantity, core/non-core, condition
   rating (A-D) and priority (1-4). RSL, SFG code, rate, and every maintenance
   frequency column are looked up automatically from the matched database row —
   they're never shown in the app, only in the export. Edit or delete any
   component from its list entry (editing reopens the same capture screen,
   pre-filled).
6. **Export** — from the project screen, "Export CSV" builds a CSV (one row per
   surveyed component, in the same column layout as `app rough output.xlsx`,
   floor column included) and opens the phone's native share sheet.

## Architecture (`lib/`)

- `models/` — plain OOP domain classes: `Project` -> `Building` -> `Room` ->
  `SurveyedComponent`, plus `HierarchyEntry` (one row of the database) and the
  `ConditionRating` / `ConditionPriority` / `CoreSystem` enums.
- `services/` — single-purpose services: `HierarchyRepository` (loads and
  queries the bundled database), `LocalProjectStore` (on-device JSON
  persistence — the source of truth), `SyncService` (best-effort push to
  Firebase when online), `PhotoService`, `CsvExportService`,
  `What3WordsService`, `ConnectivityService`, `AuthService`.
- `state/project_controller.dart` — the one place the UI mutates project data
  (add/edit/delete building, room, component); every change auto-saves
  locally and attempts a background cloud sync.
- `screens/` and `widgets/` — one screen per step of the workflow above.

The app is **offline-first**: every survey action is saved to the device
immediately, works with no signal, and syncs to Firebase opportunistically
when a connection is available. Cloud sync is entirely optional — if Firebase
isn't reachable or configured, the app keeps working locally.

## Data

`assets/data/hierarchy.json` is the maintenance hierarchy database, converted
from `Hierachy Database 210305.xlsx` (17,747 rows). To regenerate it after an
update to the source spreadsheet, re-run the two scripts used to build it:
convert the sheet to CSV with openpyxl (`read_only=True`, `data_only=True` —
plain `load_workbook` chokes on this file's formatting and is extremely slow),
then convert that CSV to the compact `{header, rows}` JSON shape the app
loads. A handful of sub-component names in the source database are not
unique (~1,700 of them repeat under a different unit/rate) — the app handles
this by prompting the surveyor to pick the exact database row whenever a
selection is ambiguous.

## Running it

```bash
flutter pub get
flutter run --dart-define=WHAT3WORDS_API_KEY=your-key-here
```

Or just run `run_app.ps1`, which already has the what3words key wired in.

what3words is entirely optional: the field is always a plain text box the
surveyor can type or paste into directly (works fully offline); the API key
only adds live autosuggest on top when the device is online.

## Firebase / cloud sync

Configured for Android via `android/app/google-services.json`
(project: `building-surveying-app`, package: `com.Eddisons.building_survey`).
Firestore holds one document per project (all its buildings/rooms/components)
under the `projects` collection. Surveyors sign in anonymously in the
background (Firebase Auth) purely so Firestore security rules can require
"signed in" — there is no login screen; the surveyor ID field is just data.

**Photos are not uploaded to the cloud** — Firebase Cloud Storage requires
the paid "Blaze" billing plan (a card on file), which this project isn't on.
Photos stay device-local; they're still captured, shown in the app, and
included in the CSV export by filename, they just don't sync across devices.
If you later add Blaze, re-introducing Storage upload is a small, contained
change to `SyncService` (git history has the previous implementation).
Because there's no photo upload step, sync is now a single atomic Firestore
write per save — there's no partial-upload state to get stuck in if the app
closes mid-sync; the next save (or automatic connectivity-triggered retry)
just re-sends the whole project.

**Before sync will actually work**, open the Firebase console for
`building-surveying-app` and set Firestore rules to allow the app's
anonymous-auth users to read/write (Console > Firestore Database > Rules):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /projects/{projectId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

A fresh Firestore instance defaults to denying all access, so until this is
set, `SyncService` will fail silently and every project will just stay in
local-only mode (the app still works fine — sync is best-effort).

Also enable **Anonymous** sign-in under Console > Authentication > Sign-in
method — it's off by default on a new project, and `AuthService` needs it
to sign the surveyor's device in.

## iOS (no Mac, no paid Apple account, no Xcode)

Apple's iOS toolchain (Xcode) only runs on macOS — that's an Apple
restriction with no legitimate workaround, so this machine can't build iOS
directly. The project builds **in the cloud** via
[Codemagic](https://codemagic.io) (`codemagic.yaml` at the repo root already
defines the build) and installs onto your iPhone via
[Sideloadly](https://sideloadly.io) (Windows-native, no Mac involved).

The `ios-workflow` build deliberately produces an **unsigned** `.ipa`
(`flutter build ios --no-codesign`, zipped up manually) rather than trying
to code-sign in CI. Signing happens afterwards, on your PC, inside
Sideloadly itself — it can sign and install an app using just your Apple ID
(the same mechanism AltStore uses), so there's no certificate, no
provisioning profile, and no Apple Developer Program membership to set up
anywhere. Just a free Apple ID.

Steps:
1. Push this repo to GitHub (done) and connect it to Codemagic (done).
2. Run the `ios-workflow` build in Codemagic — it produces
   `BuildingSurvey-unsigned.ipa`.
3. Download that `.ipa`.
4. Open Sideloadly on this PC, plug in your iPhone via USB, drag the `.ipa`
   in, and sign in with your Apple ID when Sideloadly asks — it handles
   signing and installs it directly.
5. Free Apple ID installs expire after 7 days; re-run step 4 with the same
   `.ipa` to reinstall (no need to rebuild unless the code changed).

Bundle ID: `com.Eddisons.buildingsurvey`. Firebase for iOS is **not**
registered yet — `flutterfire configure`, or manually register an iOS app
for `building-surveying-app` in the Firebase console and drop the resulting
`GoogleService-Info.plist` into `ios/Runner/`, before cloud sync will work
on iOS (Android already works today; iOS local-only features — capture,
CSV export — don't need this at all).

## Known limitations / next steps

- Deleting a building/room/component removes it locally and from the next
  Firestore sync, but doesn't retroactively scrub older synced copies of
  data you may have already pulled elsewhere - there's no cross-device
  merge, just last-write-wins per project.
- No offline queueing of Firebase Auth's anonymous sign-in itself - if the
  very first sync attempt happens while offline, sign-in (and therefore
  sync) is skipped for that attempt and retried on the next connectivity
  change or save, same as everything else in `SyncService`.
