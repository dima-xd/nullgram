package org.nullgram;

import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;

/**
 * The single activity hosting the Flutter engine.
 *
 * <p>Extends {@link FlutterFragmentActivity} rather than {@code FlutterActivity} because the
 * biometric prompt behind the app's passcode lock is a fragment, and AndroidX BiometricPrompt
 * refuses to show without a FragmentActivity host.
 */
public class MainActivity extends FlutterFragmentActivity {
    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new TDLibBridge(flutterEngine.getDartExecutor().getBinaryMessenger());
    }
}
