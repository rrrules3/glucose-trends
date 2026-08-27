# Privacy Policy — Glucose Trends

**Effective date:** August 25, 2026
**Published by:** Rohan Rajesh
**Contact:** rohan.rajesh1205@gmail.com

> **Fill in the four fields above before publishing.** This policy describes the
> app as built; if you change what it does, change this document too.

## The short version

Glucose Trends shows you your own Dexcom CGM history. Your glucose data stays
on your phone. It is never sent to us — we do not operate a server, and we have
no way to see your data. There is no analytics, no advertising, and no tracking
of any kind in this app.

## What the app handles

**Glucose readings.** Estimated glucose values, their timestamps, and their
trend arrows. These reach the app one of three ways: read from Android's Health
Connect after you grant permission, downloaded from your Dexcom account if you
connect one, or read from a Dexcom Clarity CSV file you choose to import. This
is health data, and it is treated as sensitive.

**Your settings.** Preferred units (mmol/L or mg/dL), your target glucose range,
and the last timeframe you viewed.

**Dexcom credentials.** If you connect a Dexcom account, the app stores the
developer client ID and secret you entered, plus the OAuth access and refresh
tokens Dexcom issues.

## Health Connect (Android)

If you grant it, the app reads **blood glucose** from Health Connect — the
readings your Dexcom app has shared there. It requests two permissions:

- `READ_BLOOD_GLUCOSE` — to read those readings.
- `READ_HEALTH_DATA_HISTORY` — Health Connect otherwise returns only the last
  30 days, and the app's longer timeframes need more than that.

**The app only ever reads.** It holds no write permission and cannot add,
change, or delete anything in your health record. It requests no other Health
Connect data type.

Data read from Health Connect is used solely to draw your charts and statistics
inside the app. It is stored on your device as described below, and is never
transmitted anywhere, shared with third parties, or used for advertising. You
can revoke access at any time in Settings → Security & privacy → Health
Connect, and clear what the app has cached with **Settings → Clear stored
readings**.

## Where it is stored

Everything is stored **on your device only**, in storage private to this app
that other apps cannot read.

Glucose readings and settings are kept in the app's private preferences.
Dexcom credentials and OAuth tokens are kept in the platform's secure
credential store — the Android Keystore, or the iOS Keychain. On iOS those
items are additionally marked device-only and non-synchronising, so restoring a
backup onto a different phone does not carry your Dexcom session with it.

The app does not back your glucose history up to any cloud service of ours,
because there isn't one.

## What leaves your device, and what does not

The app makes network connections to exactly two addresses, both operated by
Dexcom:

- `https://api.dexcom.com`
- `https://sandbox-api.dexcom.com`

Those connections happen only if you choose to connect a Dexcom account, and
they exist solely to log you in and download your own readings. Data travels
between your phone and Dexcom directly; it does not pass through us. Dexcom's
handling of that data is governed by Dexcom's own privacy policy and by the
authorisation you grant when you log in. You can revoke that authorisation at
any time from your Dexcom account settings, and the app will stop being able to
sync.

If you only import Clarity CSV files, the app makes no network connections at
all and works entirely offline.

**We do not collect, receive, transmit, sell, or share your data with anyone.**
The app contains no analytics, no crash reporting, no advertising, and no
third-party tracking libraries.

## Permissions

On Android the app requests three permissions:

- **Internet** — used only for the Dexcom API connections described above.
- **Read blood glucose** and **Read health data history** — Health Connect
  access, described above, and only after you grant them. The second exists
  because Health Connect otherwise returns only the last 30 days.

The app schedules no background work and posts no notifications.

Importing a CSV uses your system's file picker, which hands the app the one file
you select. The app does not request broad access to your files, photos,
location, camera, microphone, contacts, or any other sensitive permission.

## Keeping and deleting your data

Your data stays on your device until you remove it. There is no retention
period on our side because we hold nothing.

You can delete everything the app stores in two ways:

- **Settings → Clear stored readings**, which removes the local glucose history.
- **Uninstalling the app**, which removes the history, your settings, and the
  stored Dexcom credentials and tokens.

Deleting data from this app does not delete anything from your Dexcom account.
To do that, or to request deletion of data Dexcom holds, contact Dexcom.

## Children

The app is not directed at children and does not knowingly handle data from
anyone under 13. It has no accounts, no profiles, and no social features.

## Not a medical device

Glucose Trends is an informational tool for reviewing your own historical CGM
data. It is not a medical device, it is not intended for diagnosis or treatment,
and it must not be used to make treatment decisions. Always confirm with the
Dexcom app or a fingerstick, and follow your healthcare professional's advice.

## Your rights

Because your data never leaves your device, requests to access, correct,
export, or delete it are things you carry out yourself, using the controls
above. If you have questions about this policy, contact rohan.rajesh1205@gmail.com.

Depending on where you live, you may have rights under laws such as the GDPR or
the CCPA. Those rights generally apply to data a company holds about you; we
hold none.

## Changes

If this policy changes, the updated version will be posted at this URL and the
effective date above will be revised. Material changes will also be noted in the
app's release notes.

## Trademarks

Dexcom, Dexcom G7, and Dexcom Clarity are trademarks of DexCom, Inc. This app is
an independent project. It is not made, endorsed, sponsored, or supported by
DexCom, Inc.
