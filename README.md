# Building Survey App

A Flutter app for on-site building condition surveys, matching the workflow from
`Hierachy Database 210305.xlsx` and `app rough output.xlsx`.

## Workflow

1. **Surveyor entry** — enter a surveyor ID, then start a new project or resume a
   saved one.
2. **New project** — site reference and address.
3. **Buildings** — add a building reference, or mark the location as "External".
4. **Rooms** — add a room reference and (optionally) a what3words location.
5. **Components** — for each component: take 3 reference photos, then search the
   maintenance hierarchy database (Group -> System -> Element -> Sub-Element ->
   Component -> Sub-Component), then record quantity, core/non-core, condition
   rating (A-D) and priority (1-4). RSL, SFG code, rate, and every maintenance
   frequency column are looked up automatically from the matched database row —
   they're never shown in the app, only in the export.
6. **Export** — from the project screen, "Export CSV" builds a CSV (one row per
   surveyed component, in the same column layout as `app rough output.xlsx`) and
   opens the phone's native share sheet.

## Architecture (`lib/`)

- `models/` — plain OOP domain classes: `Project` -> `Building` -> `Room` ->
  `SurveyedComponent`, plus `HierarchyEntry` (one row of the database) and the
  `ConditionRating` / `ConditionPriority` / `CoreSystem` enums.
- `services/` — single-purpose services: `HierarchyRepository` (loads and
  queries the bundled database), `LocalProjectStore` (on-device JSON
  persistence — the source of truth), `SyncService` (best-effort push to
  Firebase when online), `PhotoService`, `CsvExportService`,
  `What3WordsService`, `ConnectivityService`, `AuthService`.
- `state/project_controller.dart` — the one place the UI mutates project data;
  every change auto-saves locally and attempts a background cloud sync.
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
Firestore holds one document per project under the `projects` collection;
photos are uploaded to Cloud Storage under `projects/{projectId}/photos/`.
Surveyors sign in anonymously in the background (Firebase Auth) purely so
Firestore/Storage security rules can require "signed in" — there is no
login screen; the surveyor ID field is just data.

## iOS (no Mac needed to build or install, but read this first)

Apple's iOS toolchain (Xcode, code signing) only runs on macOS — that's an
Apple restriction with no legitimate workaround, so this machine can't build
iOS directly. Instead the project is set up to build **in the cloud** via
[Codemagic](https://codemagic.io) (`codemagic.yaml` at the repo root already
defines the iOS build) and install onto your iPhone **without Xcode** via
[Sideloadly](https://sideloadly.io) (Windows-native, installs a built `.ipa`
over USB).

Bundle ID: `com.Eddisons.buildingsurvey`. Firebase for iOS is **not**
registered yet — `flutterfire configure`, or manually register an iOS app
for `building-surveying-app` in the Firebase console and drop the resulting
`GoogleService-Info.plist` into `ios/Runner/`, before cloud sync will work
on iOS (Android already works today; iOS local-only features — capture,
CSV export — don't need this at all).

**The one honest caveat**: code-signing an iOS app for CI to build
automatically works most reliably with a paid Apple Developer Program
membership ($99/year) — Codemagic can then fetch signing certificates
programmatically. A completely free Apple ID *can* sign apps, but Apple ties
that to interactively using Xcode on a real Mac at least once, which
partially defeats the "no Mac" goal. If you don't want to pay, the
practical fallback is a one-off session on any Mac (borrowed, a library, or
an hourly rental like MacinCloud) just to generate a certificate/profile —
after that, Codemagic can reuse it for every future build.

Steps once you're ready:
1. Push this repo to GitHub (see below).
2. Create a free Codemagic account, connect it to the repo — it will detect
   `codemagic.yaml` automatically.
3. In Codemagic's UI, set up iOS code signing (Team settings > Code signing
   identities) with either your Developer Program certificate, or one
   generated via the Mac session above, and put it in a variable group named
   `ios_signing` (referenced in `codemagic.yaml`).
4. Run the `ios-workflow` build — it produces a `.ipa` artifact.
5. Download the `.ipa`, open Sideloadly on this PC, plug in your iPhone,
   drag the `.ipa` in, sign in with your (free is fine) Apple ID when
   prompted, and it installs directly.
6. Free Apple ID installs expire after 7 days and need re-installing via
   Sideloadly; a paid Developer Program account doesn't have that limit.

**Before sync will actually work**, open the Firebase console for
`building-surveying-app` and set Firestore + Storage rules to allow the
app's anonymous-auth users to read/write (Console > Firestore Database >
Rules, and Console > Storage > Rules):

```
// Firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /projects/{projectId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

```
// Storage
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /projects/{projectId}/photos/{photoId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

A fresh Firestore/Storage instance defaults to denying all access, so until
these are set, `SyncService` will fail silently and every project will just
stay in local-only mode (the app still works fine — sync is best-effort).

Also enable **Anonymous** sign-in under Console > Authentication > Sign-in
method — it's off by default on a new project, and `AuthService` needs it
to sign the surveyor's device in.

## Known limitations / next steps

- The "floor" column in the CSV export template has no corresponding input
  in the app yet (not part of the described workflow) — it exports blank.
- No edit/delete for a component once saved, or for buildings/rooms — only
  additive entry, matching the described "keep putting in components" flow.
- Firebase Storage uploads are not resumed automatically if the app is
  closed mid-upload; the next `saveNow()` / mutation will retry the whole
  project's sync.
