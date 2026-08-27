# Glucose Trends

An Android app for reviewing Dexcom G7 history: a glucose chart over
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
| **Clarity CSV export** | None — just export and import | Manual | Whatever you export |
| **Demo data** | None | n/a | 90 days of synthetic readings |

All real sources merge into one timeline keyed by timestamp, so importing an
old export alongside a live sync widens your history rather than replacing it.

**Health Connect is the main route.** It needs nothing from Dexcom — no developer account, no client secret, no partnership approval — only
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
- **No internet permission.** The app makes no network calls at all — Health
  Connect and CSV import are both local — so there is nothing to declare and
  nothing to justify.

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

Run on real hardware, not just compiled:

- **A Galaxy S23 (Android 16)** — the full Health Connect path end to end:
  permission request, both grants, query, unit conversion, merge, storage,
  chart. Proven with real records written by Samsung Health, which confirmed the
  mmol/L conversion against live data rather than only against tests.
- **An API 36 arm64 emulator** — CSV import through Android's real document
  picker, the empty-result and permission-declined paths, gap handling against
  CSVs with deliberate 3-day and 5-hour outages, and the pinned tooltip.
- **iOS** builds for both simulator and device and was driven on an iPhone 17
  simulator, though it is not currently maintained.
- 101 unit tests cover the shared Dart layer.

**Still unexercised:** whether the Dexcom G7 app actually writes glucose into
Health Connect. Dexcom documents this for the G6 and is silent on G7, and
confirming it needs a real sensor. Everything on this side of that boundary is
verified. If G7 turns out not to populate Health Connect, the failure is benign:
the user sees the app's "no glucose found" guidance and CSV import still works.

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
4. **Data safety form.** Nothing leaves the device — the app has no network
   permission — so this is short, but the form is mandatory and Play
   cross-checks it against app behaviour. Declare glucose as health data
   *collected and stored on device only*, not shared.
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

## Why there is no Dexcom API integration

There was one, and it worked — full OAuth against Dexcom's sandbox, verified
end to end. It was removed anyway.

Dexcom's API has no PKCE or public-client flow, so `client_secret` is mandatory
at token exchange, and their docs say it must never be distributed and that
tokens belong on a server. A standalone mobile app cannot satisfy that: the
secret would either sit in an extractable APK or have to be registered by each
user individually. Production access is also gated behind a partnership review
capped at five users. So the feature could only ever have been a developer
curiosity, sitting in Settings inviting people to tap something that would not
work for them.

Removing it took the app to **two permissions and no network access at all** —
Health Connect and a CSV file are both local. For a health app that is worth
more than an integration nobody could use. The code is in the first commit if
it is ever needed.

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

- There are **no** network calls anywhere in `lib/`, and the shipped APK
  declares no `INTERNET` permission — verified with
  `apkanalyzer manifest permissions <apk>`.
- The only two permissions are Health Connect reads.
- There is no analytics, crash-reporting, advertising, or tracking dependency
  in `pubspec.yaml`.

If you add any of those, or a backend, the policy has to change with them.

## Layout

```
lib/
  models/       glucose readings, trends, timeframes, statistics
  data/
    sources/    Health Connect, Clarity CSV, demo generator
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
