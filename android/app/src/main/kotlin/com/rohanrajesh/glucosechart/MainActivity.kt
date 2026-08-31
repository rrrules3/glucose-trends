package com.rohanrajesh.glucosechart

import io.flutter.embedding.android.FlutterFragmentActivity

// Health Connect's permission flow presents a fragment, so the host activity
// must be a FragmentActivity. Plain FlutterActivity crashes when the sheet is
// shown on Android 14+.
class MainActivity : FlutterFragmentActivity()
