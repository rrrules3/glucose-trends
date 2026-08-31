# Privacy Policy — Glucose Chart

**Effective date:** August 25, 2026
**Published by:** Rohan Rajesh
**Contact:** rohan.rajesh1205@gmail.com

> **Fill in the four fields above before publishing.** This policy describes the
> app as built; if you change what it does, change this document too.

## The short version

Glucose Chart shows you your own Dexcom CGM history. Your glucose data stays
on your phone, and the app has **no internet access at all** — it holds no
network permission, so it cannot send your data anywhere even in principle.
There is no analytics, no advertising, and no tracking of any kind.

## What the app handles

**Glucose readings.** Estimated glucose values, their timestamps, and their
trend arrows. These reach the app one of two ways: read from Android's Health
Connect after you grant permission, or read from a Dexcom Clarity CSV file you
choose to import. This is health data, and it is treated as sensitive.

**Your settings.** Preferred units (mmol/L or mg/dL), your target glucose range,
and the last timeframe you viewed.

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

Glucose readings and settings are kept in the app's private storage, which
other apps cannot read. Nothing is backed up to any cloud service of ours,
because there isn't one — and the app could not reach it if there were.

## What leaves your device

Nothing.

The app declares no internet permission. Android will not let it open a network
connection, so your readings cannot be transmitted anywhere — not to us, not to
anyone. This is checkable: the permission list below is the complete set the app
requests, and none of them grant network access.

Both ways data reaches the app are local to your phone. Health Connect is an
Android system service on the device. A Clarity CSV is a file you already have.

**We do not collect, receive, transmit, sell, or share your data with anyone.**
The app contains no analytics, no crash reporting, no advertising, and no
third-party tracking libraries.

## Permissions

On Android the app requests two permissions, both read-only and both for
Health Connect:

- **Read blood glucose** — to read the readings your Dexcom app has shared.
- **Read health data history** — Health Connect otherwise returns only the last
  30 days, and the app's longer timeframes need more than that.

That is the entire list. No internet, no location, no storage, no camera, no
contacts. The app schedules no background work and posts no notifications.

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

Deleting data from this app does not delete anything from Health Connect or
from your Dexcom account. Health Connect data is managed in Android Settings;
for data Dexcom holds, contact Dexcom.

## Children

The app is not directed at children and does not knowingly handle data from
anyone under 13. It has no accounts, no profiles, and no social features.

## Not a medical device

Glucose Chart is an informational tool for reviewing your own historical CGM
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
