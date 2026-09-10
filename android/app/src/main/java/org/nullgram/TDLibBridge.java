package org.nullgram;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;

import org.drinkless.tdlib.Client;
import org.drinkless.tdlib.TdApi;
import org.json.JSONObject;

import android.os.Handler;
import android.os.Looper;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Bridges Flutter to TDLib, holding one {@link Client} per signed-in account.
 *
 * <p>TDLib itself is happy with several clients in one process — each gets its
 * own native client id and its own database directory — so every account stays
 * online at the same time and keeps delivering updates. Updates therefore
 * cannot be anonymous: each one is tagged with the account it came from before
 * it reaches Dart, and the Dart side decides whether it belongs to the account
 * currently on screen.
 *
 * <p>Clients are created on demand from Dart rather than in the constructor,
 * because only Dart knows which accounts exist and where their databases live.
 */
public class TDLibBridge implements MethodChannel.MethodCallHandler {
    private static final Handler mainHandler = new Handler(Looper.getMainLooper());

    /** The account id used before any account has been added. */
    private static final int DEFAULT_ACCOUNT_ID = 1;

    private static EventChannel.EventSink updateSink;

    private final MethodChannel tdlibChannel;

    /**
     * The running clients, keyed by account id.
     *
     * <p>Concurrent because TDLib delivers every result and update on its own
     * shared receiver thread while this map is written from the platform
     * thread. A plain HashMap read there can throw or spin, and that thread
     * carries the replies to every pending request: losing it makes the whole
     * bridge go quiet rather than fail loudly.
     */
    private final Map<Integer, Client> clients = new ConcurrentHashMap<>();

    /** Accounts whose client was closed, whose trailing updates are ignored. */
    private final Set<Integer> closedAccounts =
            Collections.newSetFromMap(new ConcurrentHashMap<>());

    private final List<String> pendingUpdates = new ArrayList<>();

    private volatile int activeAccountId = DEFAULT_ACCOUNT_ID;

    public TDLibBridge(BinaryMessenger messenger) {
        new EventChannel(messenger, "tdlib_updates")
                .setStreamHandler(new EventChannel.StreamHandler() {
                    @Override
                    public void onListen(Object arguments, EventChannel.EventSink events) {
                        updateSink = events;
                        for (String update : pendingUpdates) {
                            events.success(update);
                        }
                        pendingUpdates.clear();
                    }

                    @Override
                    public void onCancel(Object arguments) {
                        updateSink = null;
                    }
                });

        tdlibChannel = new MethodChannel(messenger, "tdlib_channel");
        tdlibChannel.setMethodCallHandler(this);

        // Log verbosity is a process-wide setting, so it is applied once
        // without a client, before any account exists.
        try {
            Client.execute(new TdApi.SetLogVerbosityLevel(1));
        } catch (Client.ExecutionException e) {
            System.err.println("Failed to set log verbosity: " + e.error.message);
        }
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "createAccount":
                createAccount(accountIdOf(call, DEFAULT_ACCOUNT_ID));
                result.success(null);
                return;
            case "setActiveAccount":
                activeAccountId = accountIdOf(call, DEFAULT_ACCOUNT_ID);
                result.success(null);
                return;
            case "closeAccount":
                closeAccount(accountIdOf(call, DEFAULT_ACCOUNT_ID));
                result.success(null);
                return;
            case "send":
                send(call, result);
                return;
            default:
                result.notImplemented();
        }
    }

    /** Reads the `accountId` argument, falling back to [fallback]. */
    private int accountIdOf(MethodCall call, int fallback) {
        Integer accountId = call.argument("accountId");
        return accountId == null ? fallback : accountId;
    }

    /**
     * Starts a client for the account, or does nothing if one already runs.
     *
     * <p>The account is marked open before the client exists: TDLib reports
     * `authorizationStateWaitTdlibParameters` from inside {@code create}, so a
     * guard that waited for the map entry would drop the very update that
     * starts the login flow.
     */
    private void createAccount(int accountId) {
        if (clients.containsKey(accountId)) return;
        closedAccounts.remove(accountId);
        clients.put(accountId, Client.create(
                object -> onUpdate(accountId, object),
                e -> onError(accountId, e),
                e -> onError(accountId, e)));
    }

    /**
     * Signals TDLib to shut the account's client down and forgets it.
     *
     * <p>The client is dropped from the map straight away so no further query
     * can reach a closing instance; TDLib finishes the shutdown on its own and
     * its trailing updates are discarded by {@link #onUpdate}.
     */
    private void closeAccount(int accountId) {
        Client client = clients.remove(accountId);
        if (client == null) return;
        closedAccounts.add(accountId);
        client.send(new TdApi.Close(), object -> { }, e -> { });
    }

    private void send(MethodCall call, MethodChannel.Result result) {
        Client client = clients.get(accountIdOf(call, activeAccountId));
        if (client == null) {
            result.error("NO_CLIENT", "No TDLib client for this account", null);
            return;
        }

        try {
            String json = call.argument("json");
            JSONObject obj = new JSONObject(json);
            TdApi.Function query = TdApiConverter.fromJson(obj);

            // Replies are posted to the platform thread: TDLib answers on its
            // own receiver thread, and a MethodChannel result may only be
            // completed on the thread that owns the channel.
            client.send(query, object -> mainHandler.post(() -> {
                try {
                    result.success(encodeResult(object));
                } catch (Exception e) {
                    result.error("TDLIB_ERROR", e.getMessage(), null);
                }
            }), e -> mainHandler.post(
                    () -> result.error("TDLIB_ERROR", e.getMessage(), null)));
        } catch (Exception e) {
            result.error("JSON_ERROR", e.getMessage(), null);
        }
    }

    /** Shapes a TDLib response into the map the Dart client expects. */
    private Object encodeResult(TdApi.Object object) throws Exception {
        if (object instanceof TdApi.OptionValueString) {
            TdApi.OptionValueString value = (TdApi.OptionValueString) object;
            Map<String, Object> res = new HashMap<>();
            res.put("@type", "OptionValueString");
            res.put("value", value.value);
            return res;
        }
        if (object instanceof TdApi.Error) {
            TdApi.Error error = (TdApi.Error) object;
            Map<String, Object> err = new HashMap<>();
            err.put("code", error.code);
            err.put("message", error.message);
            return err;
        }
        Map<String, Object> response = new HashMap<>();
        response.put("type", object.getClass().getSimpleName());
        response.put("data", TdApiConverter.toJson(object).toString());
        return response;
    }

    private void onUpdate(int accountId, TdApi.Object object) {
        // A client removed by closeAccount can still emit its closing updates;
        // nothing in Dart is listening for them any more.
        if (closedAccounts.contains(accountId)) return;
        try {
            JSONObject update = TdApiConverter.toJson(object);
            update.put("@accountId", accountId);
            emit(update.toString());
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * Reports a handler failure as an update.
     *
     * <p>It has to be valid JSON: Dart decodes every event, so a bare message
     * would throw inside the update stream and take the rest of the session's
     * updates down with it.
     */
    private void onError(int accountId, Throwable e) {
        try {
            JSONObject error = new JSONObject();
            error.put("@type", "UpdateBridgeError");
            error.put("@accountId", accountId);
            error.put("message", String.valueOf(e));
            emit(error.toString());
        } catch (Exception ignored) {
            e.printStackTrace();
        }
    }

    /**
     * Hands a serialized update to Dart, buffering it while no listener is
     * attached.
     *
     * <p>The event channel is subscribed asynchronously, so the first updates
     * of a freshly created client — including the authorization state that
     * drives the whole login flow — can arrive before Dart is listening.
     */
    private void emit(String update) {
        mainHandler.post(() -> {
            if (updateSink != null) {
                updateSink.success(update);
            } else {
                pendingUpdates.add(update);
            }
        });
    }
}
