package org.nilgram;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

import io.flutter.FlutterInjector;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.embedding.engine.loader.FlutterLoader;

import org.drinkless.tdlib.Client;
import org.drinkless.tdlib.TdApi;
import org.json.JSONObject;

/** Receives Telegram's pushes and gets them to Dart; the payload is encrypted,
 *  so nothing here reads it beyond asking TDLib which account it is for. */
public class NullgramMessagingService extends FirebaseMessagingService {
    private static final String TAG = "NullgramMessaging";

    private static final Handler mainHandler = new Handler(Looper.getMainLooper());

    /** The headless engine, kept between pushes so a burst pays for one start. */
    private static FlutterEngine pushEngine;

    /** That engine's bridge, held so its update sink can be withdrawn again. */
    private static TDLibBridge pushBridge;

    @Override
    public void onNewToken(String token) {
        PushChannel.onToken(token);
    }

    @Override
    public void onMessageReceived(RemoteMessage message) {
        String payload = new JSONObject(message.getData()).toString();
        long receiverId = receiverIdOf(payload);
        Log.i(TAG, "push received for receiver " + receiverId);

        mainHandler.post(() -> {
            // Decided on the main thread so the check and the invoke cannot be
            // split by a teardown; the running app supersedes a push engine.
            if (PushChannel.tryDeliverToMain(payload, receiverId)) {
                Log.i(TAG, "push handed to the running app");
                return;
            }
            Log.i(TAG, "push handed to the headless engine");
            startPushEngine();
            PushChannel.deliverToBackground(payload, receiverId);
        });
    }

    /** Which account the payload belongs to; 0 means every account, and is
     *  also what an unreadable payload answers. */
    private long receiverIdOf(String payload) {
        try {
            TdApi.Object answer =
                    Client.execute(new TdApi.GetPushReceiverId(payload));
            if (answer instanceof TdApi.PushReceiverId) {
                return ((TdApi.PushReceiverId) answer).id;
            }
        } catch (Throwable e) {
            Log.w(TAG, "getPushReceiverId failed", e);
        }
        return 0;
    }

    /** Starts the headless engine, once. Must run on the main thread. */
    private void startPushEngine() {
        if (pushEngine != null) {
            Log.i(TAG, "push engine already running");
            return;
        }
        Log.i(TAG, "starting the push engine");

        FlutterLoader loader = FlutterInjector.instance().flutterLoader();
        loader.startInitialization(getApplicationContext());
        loader.ensureInitializationComplete(getApplicationContext(), null);

        // The constructor registers the pubspec plugins itself; the TDLib
        // bridge is ours and has to be added by hand.
        pushEngine = new FlutterEngine(getApplicationContext());
        // Takes no buffered updates: draining them here would leave the app's
        // engine, which has not subscribed yet, with nothing to read.
        pushBridge = new TDLibBridge(
                pushEngine.getDartExecutor().getBinaryMessenger(), false);
        PushChannel.attachBackground(
                pushEngine.getDartExecutor().getBinaryMessenger());

        pushEngine.getDartExecutor().executeDartEntrypoint(
                new DartExecutor.DartEntrypoint(
                        loader.findAppBundlePath(), "pushMain"));
        Log.i(TAG, "push engine started");
    }

    /** Tears the headless engine down; the running app supersedes it. Must run
     *  on the main thread. */
    static void stopPushEngine() {
        if (pushEngine == null) return;
        Log.i(TAG, "stopping the push engine");
        if (pushBridge != null) pushBridge.dispose();
        pushBridge = null;
        PushChannel.detachBackground();
        pushEngine.destroy();
        pushEngine = null;
    }
}
