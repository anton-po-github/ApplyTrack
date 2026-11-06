# ApplyTrack

Track your job proposals in one place. Built with Flutter for Android, iOS, and the web.

Freelancers send many proposals and forget which ones got a reply.
ApplyTrack shows what is sent, what is waiting, and what is won.

| | Link |
|---|---|
| Live demo (web) | https://applytrackflutter.web.app/ |
| Android APK | [Download](https://github.com/anton-po-github/ApplyTrack/releases/download/v1.0.0/ApplyTrack-1.0.0.apk) |

## Screenshots

<p align="center">
  <img src="docs/screenshots/01-list.jpg" width="23%" alt="Proposal list" />
  <img src="docs/screenshots/02-form.jpg" width="23%" alt="Add proposal form" />
  <img src="docs/screenshots/03-login.jpg" width="23%" alt="Login screen" />
  <img src="docs/screenshots/04-stats.jpg" width="23%" alt="Stats screen" />
</p>

## Features

- Sign up and sign in (email and password, or Google)
- Create, read, update, and delete proposals
- Status flow: Draft → Sent → Viewed → Interview → Won / Lost
- Search and filter by status
- Follow-up date for each proposal
- Stats screen: total, count by status, win rate
- Dark Material 3 theme, works on phone, tablet, and desktop screens

## Proposal fields

| Field | Rule |
|---|---|
| Title | Required, 3–120 characters |
| Company / client | Optional, up to 120 characters |
| Platform | Upwork, LinkedIn, Email, or Other |
| Status | Draft, Sent, Viewed, Interview, Won, or Lost |
| Budget | Optional, number ≥ 0 |
| Follow-up date | Optional |
| Link | Optional, valid URL |
| Notes | Optional, up to 2000 characters |

## Tech stack

| Part | Technology |
|---|---|
| App | Flutter, Dart |
| State | Riverpod |
| Navigation | go_router (with an auth guard) |
| HTTP | Dio |
| Token storage | flutter_secure_storage |
| Google sign-in | google_sign_in |
| Backend | .NET 10 Web API (Azure App Service) |
| Database | PostgreSQL (Supabase) |
| Web hosting | Firebase Hosting |

Data flow: `Flutter app → .NET API → PostgreSQL`.
The app never talks to the database directly.

## Repository structure

```text
.
├── app/            # Flutter app (Android, iOS, Web)
├── server/         # .NET 10 Web API
├── firebase.json   # Firebase Hosting config
└── README.md
```

## Architecture

The Flutter code is split by feature. Each feature has four layers:

```text
app/lib/
├── core/        # API client, config, layout, links
├── router/      # routes and auth guard
├── theme/       # app theme
└── features/
    ├── auth/        # sign up, sign in, session
    ├── proposals/   # list, form, detail, stats
    ├── shell/       # navigation
    └── <feature>/
        ├── domain/  # models and validators (plain Dart)
        ├── data/    # API classes
        ├── state/   # Riverpod controllers
        └── ui/      # screens and widgets
```

Main ideas:

- Loosely coupled. Dependencies come from Riverpod providers.
- Easy to test. Domain code is plain Dart. The API client and API classes have fakes.
- The server is the boss. The app validates input for good UX, but the server checks everything again.
- Fast by design. Lists use cursor paging, and stats come from one summary row.

## Run the app

### Requirements

- Flutter SDK (Dart `^3.13.7`)
- Android Studio for Android
- Chrome for web
- `xcross` and an iPhone for iOS builds on Windows

### Steps

```bash
git clone <repo-url>
cd <repo-folder>/app
flutter pub get
```

Android (USB or Wi-Fi):

```bash
flutter devices
flutter run -d <device-id> --dart-define-from-file=config/dev.json
```

iPhone (cable):

```bash
xcross flutter run
```

Web:

```bash
flutter run -d chrome --dart-define-from-file=config/dev.json
```

### Config

Settings are passed with `--dart-define`. Files are in `app/config/`:

| Key | Meaning |
|---|---|
| `API_BASE_URL` | Backend address. Default is the hosted API. |
| `GOOGLE_SERVER_CLIENT_ID` | Google OAuth client ID. Needed for Google sign-in. |

Use `config/dev.json` for development and `config/prod.json` for release builds.

## Run the backend (optional)

The app uses the hosted API by default. To run your own:

```bash
cd server/ApplyTrack.End
dotnet run --launch-profile http
```

## Test and check

Run in the `app/` folder:

```bash
flutter analyze
flutter test
```

Tests cover validation, API classes, state controllers, routing, and screens.

## Build

Run in the `app/` folder:

```bash
# Web
flutter build web --release --dart-define-from-file=config/prod.json

# Android APK
flutter build apk --release --dart-define-from-file=config/prod.json
```

The web build is in `app/build/web`.
The APK is in `app/build/app/outputs/flutter-apk/app-release.apk`.

Deploy web to Firebase Hosting (run in the repo root):

```bash
firebase deploy --only hosting
```

## Download

- Android APK: [ApplyTrack-1.0.0.apk](https://github.com/anton-po-github/ApplyTrack/releases/download/v1.0.0/ApplyTrack-1.0.0.apk)
- iPhone: open the [live demo](https://applytrackflutter.web.app/) in Safari, tap Share, then "Add to Home Screen".

To install the APK, allow "Install unknown apps" on your phone, then open the file.

## Security

- All endpoints need a valid token, except sign up and sign in.
- The server validates every field and checks that a user can only touch their own rows.
- Delete is a soft delete, so data is not lost by mistake.