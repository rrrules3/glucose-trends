# Glucose Trends

An Android and iOS app for reviewing Dexcom G7 history: a glucose chart over
any timeframe, the **minimum and maximum** for that timeframe (with the time
each occurred), time-in-range, variability, and a daily-pattern overlay.

Built with Flutter — one codebase, both stores. Verified on Flutter 3.41.6 /
Dart 3.11.4. Minimum versions: Android 6.0 (API 23), iOS 14.

> Not a medical device. Do not use it to make treatment decisions — confirm with
> the Dexcom app or a fingerstick.

## How it gets your data

The G7's Bluetooth protocol is proprietary and authenticated, and the sensor
only pairs with a limited number of clients. There is no public SDK for reading
the sensor directly, so this app uses the two supported routes:

| Source | Setup | Freshness | History |
| --- | --- | --- | --- |
| **Health Connect** (Android) | Grant one permission | ~3 h delay | Whatever Dexcom has written |
| **Dexcom API v3** | Register a free developer app | ~3 h delay on a public developer account | Configurable, 30 days to everything available |
| **Clarity CSV export** | None — just export and import | Manual | Whatever you export |
| **Demo data** | None | n/a | 90 days of synthetic readings |

All real sources merge into one timeline keyed by timestamp, so importing an
old export alongside a live sync widens your history rather than replacing it.

**Health Connect is the route most people should use.** It needs nothing from
Dexcom — no developer account, no client secret, no partnership approval — only
the user's permission on the device. The Dexcom app writes glucose into Health
Connect (turn it on under Connections), and this app reads it. Two permissions
are requested, both read-only: `READ_BLOOD_GLUCOSE`, and
`READ_HEALTH_DATA_HISTORY` because Health Connect otherwise serves only the
last 30 days. The app holds no write permission and never modifies a health
record.

Requires Android 8.0 (API 26), which the `health` plugin sets as its floor.

**Enabling sharing does not backfill.** Verified with Samsung Health: readings
logged *before* the Health Connect connection existed were never forwarded,
only ones recorded afterwards. Someone who switches sharing on and syncs
straight away sees an empty result and reasonably concludes the app is broken,
so both the error message and the Settings caption say so explicitly.

## Features

- Timeframes: 3h, 6h, 12h, 24h, 7d, 14d, 30d, 90d, or a custom date range
- **Daily view for 7 days and longer**: one point per day showing that day's
  average inside a band from its low to its high. Tap a day to pin its average,
  high and low with the time each occurred. Below a week the raw 5-minute trace
  is shown instead — past that it is tens of thousands of points in a few
  hundred pixels and individual days stop being legible
- **Lowest and highest** reading for the selected timeframe, each stamped with
  when it happened and colour-coded against your target range
- Average, standard deviation, coefficient of variation, GMI (estimated A1c),
  reading count and sensor coverage
- Time in range — below / in / above, against a target range you set
- Daily pattern: every day in the window collapsed onto one 24-hour axis as a
  median line inside a 10th–90th percentile band
- Date axes always show exactly four labels, each on a real day with a gridline
  through its own data point, naming the month only where it changes:
  `Aug 17 · 19 · 22 · 24` inside one month, `Jul 25 · Aug 4 · 14 · 24` across a
  boundary. The axis is inset slightly so the first and last gridlines sit
  inside the plot rather than on its boundary, where they would be invisible. The daily chart plots against day *index* rather than timestamp so
  ticks cannot drift off their points — a literal quarter of a seven-day span
  falls at 08:00 on day three, and calendar days are not all 24 hours long
- How far back a full sync reaches is configurable (Settings → History to
  sync): 30 days through to everything Dexcom still holds. Their 30-day cap is
  **per request**, not on total history — a longer window is simply chunked
  into more requests
- mmol/L or mg/dL, switchable at any time (data is always stored in mg/dL)
- History cached on-device, so the app works offline

## Running it

Check what your machine is missing first:

```bash
flutter doctor
```

You can always try the UI with no mobile toolchain at all:

```bash
flutter run -d chrome
```

### Android

Needs the Android SDK and a JDK. Install
[Android Studio](https://developer.android.com/studio) and let it install the
SDK on first launch. Once `[✓] Android toolchain` passes, plug in a phone (USB
debugging on) or start an emulator and `flutter run`.

```bash
flutter build apk --release      # sideloading / direct install
flutter build appbundle --release  # what Google Play requires
```

Both are debug-signed until you add `android/key.properties` — see
[Shipping to Google Play](#shipping-to-google-play).

### iOS

Needs Xcode, CocoaPods, and the iOS platform components. If a build fails with
*"iOS 26.5 is not installed"*, the platform support files are missing — install
them from **Xcode → Settings → Components**, or:

```bash
xcodebuild -downloadPlatform iOS
```

That is an ~8.5 GB download, so give it room. Then:

```bash
flutter build ipa --release
```

That produces `build/ios/archive/Runner.xcarchive` plus an `.ipa` under
`build/ios/ipa/`, ready to upload with Transporter or `xcrun altool`.

Both iOS targets have been built and the app run on an iPhone 17 simulator:
`flutter build ios --simulator --debug` and
`flutter build ios --release --no-codesign` (18.3 MB). The release bundle was
checked to confirm `PrivacyInfo.xcprivacy` is actually copied into
`Runner.app/`, `MinimumOSVersion` is 14.0, and no stray `CFBundleURLTypes`
entry was added.

## Connecting your Dexcom account

Dexcom issues client credentials per *application*, not per user, so the app
cannot ship one — you register your own:

1. Sign up at [developer.dexcom.com](https://developer.dexcom.com) and create an
   app.
2. Set its redirect URI to **`http://localhost:8423/callback`**.

   Dexcom's portal rejects custom schemes — it accepts only `http://` or
   `https://` — so the app uses the loopback redirect RFC 8252 defines for
   native apps: it listens on `127.0.0.1:8423` for the few seconds the login
   takes, opens Dexcom's page in the system browser, and catches the
   authorization code when the browser is redirected back. The code never
   leaves the device.

   The port is part of the registered URI and matched exactly, so it is fixed
   in `DexcomAuth.defaultRedirectUri`. Change it there and in the portal
   together, or login fails with a redirect mismatch.
3. In the app: **Settings → Dexcom account**, paste the client ID and secret,
   pick an environment, and tap **Connect**.

**Sandbox** works immediately and needs no password: the Dexcom login page
shows a drop-down of simulated accounts — including *Sandbox User - G7* — and
you pick one. Use it to exercise the whole OAuth round-trip before you point at
real data. **Production** returns your own readings, delayed roughly three hours
on a standard developer account. Real-time access requires a separate
partnership agreement with Dexcom.

The OAuth endpoints are `/v3/oauth2/login` and `/v3/oauth2/token`, and the data
endpoints are `/v3/users/self/egvs` and `/v3/users/self/dataRange`. Older
write-ups still show `/v2/oauth2/...`; those are superseded, and
[`test/dexcom_endpoints_test.dart`](test/dexcom_endpoints_test.dart) pins the
correct paths so a regression fails the suite rather than surfacing as a broken
login.

Tokens are stored via `flutter_secure_storage` — the Android keystore, and the
iOS Keychain marked device-only and non-syncing — never in plain shared
preferences.

### Read this before distributing the app to anyone else

The current build is a **single-user, device-only design**: you supply your own
client ID and secret, and the tokens live on your phone. That is fine for
running the app on your own device against your own Dexcom account. It does
**not** scale to other users, for two reasons.

**1. Dexcom requires server-side tokens.** From their authentication docs:

> "An application's client_secret should never be shared or distributed."
>
> "Dexcom requires that partners store tokens (e.g., client secret, access
> tokens) on their servers. Integrations with mobile applications should not
> store tokens on the mobile device."

Dexcom's OAuth has no PKCE or public-client flow, so `client_secret` is
mandatory at token exchange. There is no way for a shipped mobile binary to
hold it safely — anything embedded in an APK or IPA can be extracted. Storing
it in the Keychain/keystore protects it from other apps on the device, but it
does not satisfy the requirement above.

**2. Production access is gated.** Registering gets you Sandbox immediately.
Real data needs an upgrade request reviewed by Dexcom's Strategic Partnerships
team:

| Tier | For | Users | Process |
| --- | --- | --- | --- |
| Sandbox | Anyone, immediately | simulated only | just register |
| Limited Access | Individuals, prototypes | **up to 5** | upgrade request, reviewed |
| Full Access | Commercial release | unlimited | questionnaire + technical review |

**What this means in practice**

- *Just you* — works today, no changes.
- *You and up to four others* — apply for Limited Access, and add a backend that
  holds the secret and does the token exchange. The app then talks to your
  server instead of Dexcom directly.
- *Public release on either store* — Full Access plus that backend, and the
  Data Licensing Agreement.

The backend is the real work: an OAuth callback handler, encrypted token
storage per user, refresh handling, and a thin API the app calls. The Dart side
changes less than you would expect — `DexcomAuth` and `DexcomApiClient` are
already isolated behind `GlucoseRepository`, so pointing them at your own
server is a swap at that seam rather than a rewrite. The CSV import path needs
none of this and keeps working offline regardless.

### Why the OAuth flow looks unusual

Dexcom's API is built for server-side web apps, and it pushes back on a
standalone mobile client in two ways:

- **Redirect URIs must be `http://` or `https://`.** Custom schemes such as
  `myapp://callback` are rejected by the portal, which rules out the usual
  mobile pattern of `flutter_web_auth_2` plus an intent-filter. Hence the
  loopback listener in
  [`loopback_redirect_server.dart`](lib/data/sources/loopback_redirect_server.dart).
- **Tokens are supposed to live on your server**, as quoted above.

Both point the same way: for anything beyond personal use, Dexcom expects a
backend. The loopback flow is a legitimate, standards-based fit for a
single-user app, but it is not what Dexcom designed for.

## Combining old history with ongoing readings

The common case — someone who wants to analyse months of past data *and* keep
seeing new readings — needs both sources, because neither covers it alone:

- **Health Connect only goes forward.** Sharing does not backfill, so it starts
  from the day it is switched on.
- **A Clarity export only goes backward.** It is a snapshot of what existed
  when it was generated.

They compose, because the repository merges everything into one timeline keyed
by timestamp. The order that avoids a gap:

1. **Turn on Health Connect sharing in the Dexcom app first.** The forward feed
   starts from this moment, so do it before anything else.
2. **Then export from Clarity**, covering as far back as wanted and up to
   today, and import it. Because step 1 already happened, the export overlaps
   the start of the live feed rather than leaving a hole between them.
3. **After that, just open the app** (or pull to refresh) to pull new readings.

Re-importing later is safe: readings merge by timestamp, so overlapping exports
widen the history and never duplicate.

Doing it the other way round — exporting first, enabling sharing afterwards —
leaves a gap covering however long passed in between, and nothing backfills it.
A second export closes the gap if it happens.

## Giving the app to someone else

The CSV route needs no Dexcom developer account, no backend, no approval, and
no secret to protect — which makes it the practical way to hand this app to one
other person. They install it, export from Clarity, and import. Everything in
the app works identically: same charts, same min/max, same time in range.

Because that is the only path a second user has, importing is the **primary
action on the empty state**, not buried in Settings. First launch shows just
the import card — no empty chart furniture above it.

What to tell them:

1. Sign in at [clarity.dexcom.com](https://clarity.dexcom.com) and choose
   **Export data → CSV**. Pick as long a window as they want history for.
2. Get the file onto the phone — AirDrop, email, or save to Files/Drive.
3. Open the app, tap **Import Clarity CSV**, pick the file.

Re-importing later is safe and additive: readings merge by timestamp, so a new
export that overlaps an old one widens the history instead of duplicating it.
Their data never leaves their device.

The trade-off is that it is manual — no live reading, no auto-sync. If they
want that, it needs the backend described above plus Limited Access approval.

## Importing a Clarity export

1. Go to [clarity.dexcom.com](https://clarity.dexcom.com) → **Export data** →
   CSV.
2. **Settings → Import Clarity CSV** and pick the file.

The parser locates columns by header text rather than fixed position, so it
handles the regional variations in Clarity's export (mg/dL or mmol/L, `T` or
space in timestamps, CRLF endings) and the `Low`/`High` strings the sensor
reports outside 40–400 mg/dL.

[`sample_data/clarity_export_sample.csv`](sample_data/clarity_export_sample.csv)
is a synthetic export in the real format — useful for exercising the import path
without touching real data.

## Shipping to Google Play

### Already configured

- **`targetSdk` 36.** New apps must target Android 16 (API 36) from
  **31 August 2026**. Flutter 3.41.6 defaults to 36, so this is met.
  `minSdk` is 24.
- **Release signing wired up.** [`android/app/build.gradle.kts`](android/app/build.gradle.kts)
  reads `android/key.properties` and signs with your upload key. If that file
  is absent it falls back to debug signing so `flutter run --release` still
  works locally — but a debug-signed build is rejected by Play.
- **Credentials gitignored**: `key.properties`, `*.jks`, `*.keystore`.
  [`android/key.properties.example`](android/key.properties.example) shows the
  shape.
- **Internet permission**, plus the `<queries>` entry url_launcher needs to
  find a browser under Android 11+ package visibility.

R8 shrinking is deliberately **off** — see the comment in the build file.

### Set up the Android toolchain

`flutter doctor` currently fails on Android: there is no JDK and no SDK on this
machine. Both are required — without a JDK, `keytool` cannot create your upload
key; without the SDK, `flutter build appbundle` cannot run.

The lean route (~3–5 GB, enough to build and ship — no IDE or emulator):

```bash
brew install --cask temurin@17 android-commandlinetools
```

Point Flutter at both, then install the SDK pieces for API 36:

```bash
flutter config --android-sdk /usr/local/share/android-commandlinetools
flutter config --jdk-dir /Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0"
```

If `build-tools;36.0.0` is not found, run `sdkmanager --list | grep build-tools`
and take the newest 36.x. Then accept the licences and confirm:

```bash
flutter doctor --android-licenses
flutter doctor
```

You want `[✓] Android toolchain`. The full Android Studio cask
(`brew install --cask android-studio`) is the alternative — heavier, but adds
an IDE and emulator, and it will pick up an SDK installed by the route above.

### Create your upload key

Needs a JDK, which you get with Android Studio. Then:

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Copy `android/key.properties.example` to `android/key.properties` and fill in
the passwords, alias, and the absolute path to the `.jks`.

**Back that file up somewhere safe.** With Play App Signing, Google holds the
real app-signing key and this is only your *upload* key, so a loss is
recoverable by contacting Google — but it is still a slow, annoying problem to
have.

### Build the bundle

Play requires an Android App Bundle, not an APK:

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`.

### Getting it to one other person

You do **not** need the Production track, and this matters:

| Track | Who can install | Requirements |
| --- | --- | --- |
| **Internal testing** | up to 100 testers you list by email | none — available immediately |
| Closed testing | testers you invite | complete app setup |
| Production | everyone | see below |

**Internal testing is the right track here.** No waiting, no minimum tester
count. You add their Google account email, they get an opt-in link, and they
install from Play normally.

Production is gated for personal developer accounts created after
13 November 2023: you need **12 testers opted in to a closed test for
14 continuous days** before you can even apply, and the application review takes
up to about a week. Organization accounts and older personal accounts are
exempt. For handing an app to one person, that whole path is unnecessary.

### What has actually been verified

Both platforms have been built and run, not just compiled:

- **Android**: `flutter build appbundle --release` produces
  `app-release.aab` (43.6 MB — the bundle carries debug symbols in
  `BUNDLE-METADATA` that Play strips before delivery, so the download is far
  smaller). The release APK was installed on an API 36 arm64 emulator, launched
  with no crash, and a Clarity CSV was imported through Android's real document
  picker: 2,016 readings parsed and charted.
- **iOS**: both targets build, and the app was driven on an iPhone 17
  simulator.
- 64 unit tests cover the shared Dart layer.

Still unexercised on both platforms: the OAuth round-trip against a real Dexcom
account, since that needs credentials. The endpoints are pinned by
[`test/dexcom_endpoints_test.dart`](test/dexcom_endpoints_test.dart), but the
handshake itself has never run. Dexcom's passwordless sandbox is the cheapest
way to close that gap.

#### Toolchain notes

Three things bit during the first Android build, recorded in case you rebuild
on another machine:

- **Android Studio's bundled JDK is 25**, which Gradle 8.14 rejects with a bare
  `What went wrong: 25.0.2`. Use JDK 21: `brew install openjdk@21`, then
  `flutter config --jdk-dir /usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home`.
- **Studio installs the platform as `android-37.0`**, but AGP asks for the hash
  `android-37`, which Google no longer publishes. See the `subprojects` block
  in [`android/build.gradle.kts`](android/build.gradle.kts).
- **`cmdline-tools` must live inside the same SDK root.** `apkanalyzer`
  resolves the SDK from its own real path, so a symlink from another SDK makes
  it fail with "Cannot locate latest build tools" — which surfaces confusingly
  as *"Release app bundle failed to strip debug symbols"* even though stripping
  worked fine.

### Still to do before uploading

1. **Play Console account** — $25 one-time. (Google is also rolling out free
   *Limited Distribution* accounts during 2026; worth checking whether that
   covers your case before paying.)
2. ~~**App icon and screenshots.**~~ Done — see
   [Icon and store assets](#icon-and-store-assets).
3. **Privacy policy URL** — required, and doubly so for a health app.
4. **Data safety form.** Nothing leaves the device, so this is short — but the
   form is mandatory and Play cross-checks it against app behaviour. Declare
   the Clarity CSV and Dexcom sync as health data *collected and stored on
   device only*, not shared.
5. **Health apps declaration.** Play asks about health functionality during
   setup. Answer factually: this displays a user's own CGM history and makes no
   diagnosis or treatment recommendation. The disclaimer in Settings → About
   backs that up — keep it.
6. **Content rating questionnaire.**
7. **Version numbers.** `pubspec.yaml`'s `version: 1.0.0+1` drives
   `versionName`/`versionCode`. The build number after `+` must increase on
   every upload.

## Shipping to the App Store

What is already configured in this repo:

- **Privacy manifest** at [`ios/Runner/PrivacyInfo.xcprivacy`](ios/Runner/PrivacyInfo.xcprivacy),
  wired into the Runner target's resources. It declares no tracking, no
  collected data types, and the `CA92.1` reason for UserDefaults access. Every
  plugin used here ships its own manifest too.
- **Export compliance**: `ITSAppUsesNonExemptEncryption = false` in
  `Info.plist`, so uploads do not stop to ask. The app only uses HTTPS and
  Apple's Keychain, both covered by the standard exemption — confirm that still
  describes your build before you rely on it.
- **Keychain policy**: tokens use `first_unlock_this_device` and
  `synchronizable: false`, so a Dexcom session cannot be restored onto a
  different phone from a backup.
- **No usage-description strings needed**: the CSV import uses
  `UIDocumentPickerViewController`, not the photo library.

What you still have to do:

1. **Apple Developer Program membership** ($99/year) and a real bundle
   identifier. `com.glucosetrends.app` is a placeholder — set your own in Xcode
   under Signing & Capabilities, and enable automatic signing.
2. ~~**App icon.**~~ Done — see [Icon and store assets](#icon-and-store-assets).
3. **Privacy policy URL.** Required for every app on the store. A draft is in
   [`PRIVACY.md`](PRIVACY.md) — fill in the four bracketed fields and host it
   publicly.
4. **App Privacy answers in App Store Connect.** Apple defines "collect" as
   transmitting data off the device. This app fetches from Dexcom and caches
   locally, and sends nothing anywhere, so *Data Not Collected* is the accurate
   answer. Re-check it if you ever add analytics or crash reporting.
5. **Age rating** — the questionnaire asks about medical/treatment information.

### Two things likely to matter at review

**The name.** The project was originally "Dexcomm" — one letter from "Dexcom",
which invites rejection under the guideline on implying an association with
another company, and is a trademark risk regardless of Apple. It has been
renamed: the Dart package is `glucose_trends`, both bundle identifiers are
`com.glucosetrends.app`, and the display name is "Glucose Trends" on both
platforms. Nothing user-facing says "Dexcom" except factual descriptions of
where the data comes from — keep it that way in your store listing, and swap
`com.glucosetrends.app` for a reverse-DNS identifier on a domain you actually
own before you create the App Store Connect record. **The bundle ID is
permanent once submitted.**

**Medical-app scrutiny.** Guideline 1.4.1 says apps that could provide
inaccurate medical data get evaluated more carefully, and reviewers may ask who
you are and what the app claims to do. Two things help: the app already carries
a plain "not a medical device, do not use for treatment decisions" notice in
Settings → About, and it displays Dexcom's own values without reinterpreting
them. Keep both true. If you ever add dosing suggestions or alerts, the
regulatory picture changes completely.

Also worth confirming before you submit:

- **Dexcom's developer terms** — check what they permit for a publicly
  distributed third-party client, and whether the ~3-hour delay on standard
  developer accounts is something you can ship against. Real-time access needs a
  separate agreement with Dexcom.
- **Sign in with Apple** (guideline 4.8) applies to third-party *social* logins
  used to create an account in your app. Signing in to your own existing Dexcom
  account to reach your own data should fall under the exemption for
  service-specific clients, but confirm it rather than assume it.

### iOS-specific things you might want next

- **HealthKit.** The natural iOS integration: read glucose that other apps have
  already written, or write your imported history back so it shows up in Health.
  It needs the HealthKit entitlement, two usage-description strings, and a
  privacy policy, and it adds review surface — worth doing deliberately rather
  than by default.
- **Widgets / Live Activities** for the current reading on the lock screen.
- **Background refresh**, which would need the Keychain accessibility relaxed
  from `first_unlock_this_device` so tokens are readable when the app wakes.

## Icon and store assets

The icon is generated by [`tool/generate_icon.py`](tool/generate_icon.py)
rather than checked in as an opaque binary, so it can be regenerated at any
size and its colours stay tied to the ones the app actually uses. It is a CGM
trace over the app's blue, crossing a faint target-range band, with the newest
reading marked in the in-range green.

```bash
python3 tool/generate_icon.py     # rewrites assets/icon/*
dart run flutter_launcher_icons   # installs them into android/ and ios/
```

That produces `assets/icon/icon.png` (1024×1024, flattened — iOS rejects an
alpha channel), `icon_foreground.png` for Android adaptive icons,
`play_store_512.png` for the Play listing, and
`play_feature_graphic_1024x500.png` for the listing banner.

Store screenshots live in [`screenshots/`](screenshots): 1080×1920, 24-bit PNG,
no alpha. That is **9:16 deliberately** — Play rejects a screenshot whose long
side is more than twice its short side, so the emulator's native 1080×2400
(2.22×) is not valid. They were captured with the display temporarily set to
9:16:

```bash
adb shell wm size 1080x1920 && adb shell wm density 420
# ... capture with `adb exec-out screencap -p > shot.png` ...
adb shell wm size reset && adb shell wm density reset
```

Play needs at least two screenshots; four or more at 1080p makes the listing
eligible for larger promotional placements.

## Why there is no background sync

It was built, measured, and removed. `workmanager` takes the app's permission
list from three to ten — boot-completed, wake lock, network state, foreground
service, notifications — and those are declared whether or not the feature is
switched on, so they show in the Play listing either way.

That is a poor trade for what it buys. Readings are ~3 hours delayed at source,
so a background refresh saves one tap on data that is stale regardless. Syncing
when the app opens costs nothing and needs no permissions.

If it is ever revisited, two things from the first attempt are worth keeping:
it must read Health Connect only (OEMs cut background network, which would make
a background API sync fail at random), and the WorkManager dispatcher must be a
top-level function annotated `@pragma('vm:entry-point')` or release builds
tree-shake it away and the task silently never runs.

## Privacy

[`PRIVACY.md`](PRIVACY.md) is a draft policy describing the app as actually
built. Its claims were checked against the code rather than assumed:

- The only network destinations in `lib/` are `api.dexcom.com` and
  `sandbox-api.dexcom.com`.
- The shipped release APK requests exactly one permission, `INTERNET`
  (`apkanalyzer manifest permissions <apk>`).
- There is no analytics, crash-reporting, advertising, or tracking dependency
  in `pubspec.yaml`.

If you add any of those, or a backend, the policy has to change with them.

## Layout

```
lib/
  models/       glucose readings, trends, timeframes, statistics
  data/
    sources/    Dexcom OAuth, Dexcom API v3 client, Clarity CSV, demo generator
    reading_store.dart      delta-encoded local cache
    glucose_repository.dart merges sources into one timeline
  state/        user settings
  ui/           screens and chart widgets
  util/         unit conversion, colour language, downsampling, formatting
```

Two decisions worth knowing about:

- **Glucose is stored in mg/dL everywhere**, and converted only for display.
  Stored data never depends on a user setting.
- **The chart downsamples with a min/max envelope.** A 90-day window is ~26,000
  readings; taking every Nth point would drop exactly the spikes and lows you
  opened the chart to see, so each bucket contributes both its minimum and its
  maximum in chronological order.

## Tests

```bash
flutter test
```

53 tests covering the statistics engine (including the min/max reporting),
CSV parsing, Dexcom API response parsing, the downsampler's extreme
preservation, cache encoding, and repository merge/window behaviour.
