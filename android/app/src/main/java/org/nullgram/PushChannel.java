package org.nullgram;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.google.android.gms.tasks.Task;
import com.google.firebase.messaging.FirebaseMessaging;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Carries the FCM token and every push payload between Java and Dart, and
 *  holds which engine is attached, since that decides who handles a push. */
public class PushChannel implements MethodChannel.MethodCallHandler {
    private static final String TAG = "PushChannel";

    /** How many early payloads are held before the oldest ones are dropped. */
    private static final int MAX_PENDING = 64;

    private static final Handler mainHandler = new Handler(Looper.getMainLooper());

    // Both slots, and every instance field below, are touched on the main
    // thread only, which is what makes check-and-deliver atomic without a lock.
    private static PushChannel main;
    private static PushChannel background;

    private final MethodChannel channel;

    /** Payloads that arrived before Dart said it was ready. */
    private final List<Map<String, Object>> pending = new ArrayList<>();

    private boolean ready;
    private boolean warnedAboutDrops;

    private PushChannel(BinaryMessenger messenger) {
        channel = new MethodChannel(messenger, "nullgram_push");
        channel.setMethodCallHandler(this);
    }

    /** Attaches the channel of the activity's engine. Main thread only. */
    public static PushChannel attachMain(BinaryMessenger messenger) {
        main = new PushChannel(messenger);
        return main;
    }

    /** Detaches the given channel, if it is still the attached one. */
    public static void detachMain(PushChannel attached) {
        // A recreated activity attaches before the old one is destroyed, so an
        // unconditional clear would drop the channel that just arrived.
        if (main == attached) main = null;
    }

    /** Attaches the channel of the headless push engine. Main thread only. */
    public static void attachBackground(BinaryMessenger messenger) {
        background = new PushChannel(messenger);
    }

    /** Forgets the headless engine's channel as that engine is destroyed. */
    public static void detachBackground() {
        background = null;
    }

    /** Hands the payload to the running app; true means it took it and no
     *  headless engine has to be started. Main thread only. */
    public static boolean tryDeliverToMain(String payload, long receiverId) {
        PushChannel target = main;
        if (target == null || !target.ready) return false;
        target.deliver(payload, receiverId);
        return true;
    }

    /** Hands the payload to the headless engine. Main thread only. */
    public static void deliverToBackground(String payload, long receiverId) {
        PushChannel target = background;
        if (target == null) return;
        target.deliver(payload, receiverId);
    }

    /** Reports a refreshed token to whichever engine can act on it. */
    public static void onToken(String token) {
        mainHandler.post(() -> {
            // Read on the main thread, where the slots live, and prefer a main
            // engine only once it is ready to be called.
            PushChannel target = main != null && main.ready ? main : background;
            if (target == null) return;
            target.channel.invokeMethod("onToken", token);
        });
    }

    private void deliver(String payload, long receiverId) {
        Map<String, Object> arguments = new HashMap<>();
        arguments.put("payload", payload);
        arguments.put("receiverId", receiverId);

        // The push engine is told to deliver as soon as it is created, long
        // before its Dart entrypoint has run, so early arrivals wait here.
        if (!ready) {
            bufferEarly(arguments);
            return;
        }
        channel.invokeMethod("onPush", arguments);
    }

    private void bufferEarly(Map<String, Object> arguments) {
        // Bounded, because an entrypoint that never reports ready would
        // otherwise grow this list for the life of the process.
        while (pending.size() >= MAX_PENDING) {
            pending.remove(0);
            if (!warnedAboutDrops) {
                warnedAboutDrops = true;
                Log.w(TAG, "push buffer full, dropping the oldest payloads");
            }
        }
        pending.add(arguments);
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "ready":
                ready = true;

                // Only now is the app able to take pushes, so only now can the
                // headless engine go; its own ready must not destroy it.
                if (this == main) NullgramMessagingService.stopPushEngine();

                for (Map<String, Object> arguments : pending) {
                    channel.invokeMethod("onPush", arguments);
                }
                pending.clear();
                result.success(null);
                return;
            case "getToken":
                getToken(result);
                return;
            default:
                result.notImplemented();
        }
    }

    /** Answers the current FCM token, or null when Firebase is not configured:
     *  a build without google-services.json must still run. */
    private void getToken(MethodChannel.Result result) {
        try {
            Task<String> task = FirebaseMessaging.getInstance().getToken();
            task.addOnCompleteListener(completed -> {
                if (completed.isSuccessful()) {
                    result.success(completed.getResult());
                } else {
                    Log.w(TAG, "FCM token unavailable", completed.getException());
                    result.success(null);
                }
            });
        } catch (Exception e) {
            Log.w(TAG, "FCM token unavailable", e);
            result.success(null);
        }
    }
}
