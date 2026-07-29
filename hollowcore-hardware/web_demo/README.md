# HollowCore Web Demo

Browser control panel for the HollowCore automation node. It authenticates against the
same Firebase project as the SphereCore Flutter app (`hollow-core`), so an account
registered on mobile signs in here with no separate user record.

## Setup

```bash
cd hollowcore-hardware/web_demo
cp .env.example .env
npm install
npm run dev
```

The dev server listens on <http://localhost:5180>.

`.env` is gitignored. The values in `.env.example` mirror the web block of
`spherecore/lib/firebase_options.dart`, plus `VITE_FIREBASE_DATABASE_URL`, which the
Flutter SDK derives from the project ID but the JS SDK requires explicitly.

## Modes

The header carries an explicit **App Mode / Result Mode** switch. The selection persists
in `localStorage`.

**App Mode** is a read/write reimplementation of the SphereCore screens that are backed
by Firebase: Devices, Vital32, Reminders and Profile. Writes go to the same Realtime
Database paths the mobile app writes to, so toggling a device here drives real hardware.

**Result Mode** is a read-only mirror driven by `onValue` listeners. Toggle a device in
the mobile app and this view updates within milliseconds: the affected tile flashes, an
`UPDATED` badge appears, and a timestamped entry lands in the change feed. Nothing is
polled and nothing is simulated.

Two SphereCore screens are deliberately not reimplemented. `ControlScreen` talks to an
ESP32-CAM over `ws://<lan-ip>:81` and an MJPEG stream, and `MembersScreen` calls
`http://<lan-ip>/users`. Both require the reviewer to be on the same LAN as the hardware,
so they cannot work from a remote browser.

## Architecture

```
src/
  firebase/    SDK initialisation and env-backed config
  auth/        sign-in, registration, session observation
  api/         Realtime Database paths and read/write services
  realtime/    onValue subscriptions, connection monitor, pin diffing
  ui/          shell, views, reusable components
  lib/         DOM helper and formatting
  styles/      design tokens translated from spherecore AppTheme
```

The layers only depend downwards: `ui` uses `api` and `realtime`, both of which use
`firebase` and `auth`. No view talks to the Firebase SDK directly.

## Data model

Device state lives at `users/{uid}/virtualPins/{pushId}`:

```json
{ "id": "-OWLbEYsujEjrFI6SEIs", "label": "Living room light", "pin": 26, "state": false }
```

`pin` is the ESP32 GPIO number and `state` is the relay's desired level. The record's
`id` field is not authoritative; some existing rows carry a stale value, so the push key
is used instead, matching `DatabaseService.getPins()` in the Flutter app.

## Design tokens

Colours, fonts and radii are taken from `spherecore/lib/themes/app_theme.dart` and
declared as CSS custom properties in `src/styles/base.css`. SphereCore ships a light
theme (`themeProvider` is hardcoded to `ThemeMode.light`), so this panel is light too.
Poppins and the LifeSphere logos are copied from `spherecore/assets`; the logos are
cropped to their content bounds because the originals are centred on 500x500 canvases.

## Security

`database.rules.json` in the parent directory scopes every read and write to the owning
user. Deploy it before demoing:

```bash
firebase deploy --only database --project hollow-core
```

Without it the database is world-readable.
