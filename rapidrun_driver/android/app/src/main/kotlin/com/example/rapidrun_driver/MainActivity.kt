package com.example.rapidrun_driver

import android.os.Bundle
import androidx.appcompat.app.AppCompatDelegate
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Force Dark Mode so Google Maps Android SDK selects the Dark mode
        // Cloud Map Style slot ("RapidRun Midnight Gold 3D") on Map ID 2af4647f58c6980d6ea47ab0.
        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES)
        super.onCreate(savedInstanceState)
    }
}
