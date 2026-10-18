package com.tududi.tududi

import com.tududi.tududi.bridge.Bridges
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Bridges.register(flutterEngine.dartExecutor.binaryMessenger, tududa)
    }
}
