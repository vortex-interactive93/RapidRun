// File: rapidrun_driver/android/app/src/main/kotlin/com/example/rapidrun_driver/MainActivity.kt

package com.example.rapidrun_driver

import android.app.UiModeManager
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enforceDarkModeForMaps()
        super.onCreate(savedInstanceState)
    }

    private fun enforceDarkModeForMaps() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val uiModeManager = getSystemService(UiModeManager::class.java)
            uiModeManager?.setApplicationNightMode(UiModeManager.MODE_NIGHT_YES)
        }
        resources.configuration.uiMode =
            (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
                Configuration.UI_MODE_NIGHT_YES
    }
}
