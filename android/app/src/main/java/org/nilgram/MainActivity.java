package org.nilgram;

import android.content.Intent;

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
    private TDLibBridge bridge;
    private PushChannel pushChannel;
    private IntentChannel intentChannel;

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        bridge = new TDLibBridge(
                flutterEngine.getDartExecutor().getBinaryMessenger(), true);

        // The app supersedes the headless engine, so drop it before attaching.
        // Order is free here: a bridge adds no sink until Dart subscribes.
        NullgramMessagingService.stopPushEngine();

        pushChannel = PushChannel.attachMain(
                flutterEngine.getDartExecutor().getBinaryMessenger());

        intentChannel = new IntentChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(), this);
        intentChannel.handle(getIntent());
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        if (intentChannel != null) intentChannel.handle(intent);
    }

    @Override
    public void cleanUpFlutterEngine(FlutterEngine flutterEngine) {
        // Dropping the sink matters: a destroyed engine that kept one would
        // leave the update buffer switched off for the next engine.
        if (bridge != null) bridge.dispose();
        bridge = null;
        PushChannel.detachMain(pushChannel);
        pushChannel = null;
        if (intentChannel != null) intentChannel.dispose();
        intentChannel = null;
        super.cleanUpFlutterEngine(flutterEngine);
    }
}
