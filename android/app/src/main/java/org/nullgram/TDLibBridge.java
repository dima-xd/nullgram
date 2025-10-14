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
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class TDLibBridge implements MethodChannel.MethodCallHandler {
    private static final Handler mainHandler = new Handler(Looper.getMainLooper());
    private static EventChannel.EventSink updateSink;

    private final MethodChannel tdlibChannel;
    private final Client client;
    private final List<String> pendingUpdates = new ArrayList<>();

    public TDLibBridge(BinaryMessenger messenger) {
        // TDLib updates channel
        new EventChannel(messenger, "tdlib_updates")
                .setStreamHandler(new EventChannel.StreamHandler() {
                    @Override
                    public void onListen(Object arguments, EventChannel.EventSink events) {
                        updateSink = events;
                        for (String update : pendingUpdates) {
                            updateSink.success(update);
                        }
                        pendingUpdates.clear();
                    }

                    @Override
                    public void onCancel(Object arguments) {
                        updateSink = null;
                    }
                });

        // TDLib method channel
        tdlibChannel = new MethodChannel(messenger, "tdlib_channel");
        tdlibChannel.setMethodCallHandler(this);

        // TDLib client
        client = Client.create(this::onUpdate, this::onError, this::onError);
        // TODO: Make log level configurable
        client.send(new TdApi.SetLogVerbosityLevel(1), object -> {
            if (object instanceof TdApi.Error) {
                TdApi.Error error = (TdApi.Error) object;
                System.err.println("Failed to set log verbosity level: " + error.message);
            } else {
                System.out.println("Log verbosity level set to 1");
            }
        }, e -> System.err.println("Error setting log verbosity level: " + e.getMessage()));
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if (!"send".equals(call.method)) {
            result.notImplemented();
            return;
        }

        try {
            String json = call.argument("json");
            JSONObject obj = new JSONObject(json);
            TdApi.Function query = TdApiConverter.fromJson(obj);

            client.send(query, object -> {
                try {
                    if (object instanceof TdApi.OptionValueString) {
                        TdApi.OptionValueString value = (TdApi.OptionValueString) object;
                        Map<String, Object> res = new HashMap<>();
                        res.put("@type", "OptionValueString");
                        res.put("value", value.value);
                        result.success(res);
                    } else if (object instanceof TdApi.Error) {
                        TdApi.Error error = (TdApi.Error) object;
                        Map<String, Object> err = new HashMap<>();
                        err.put("code", error.code);
                        err.put("message", error.message);
                        result.success(err);
                    } else {
                        JSONObject jsonResult = TdApiConverter.toJson(object);
                        Map<String, Object> response = new HashMap<>();
                        response.put("type", object.getClass().getSimpleName());
                        response.put("data", jsonResult.toString());
                        result.success(response);
                    }
                } catch (Exception e) {
                    result.error("TDLIB_ERROR", e.getMessage(), null);
                }
            }, e -> result.error("TDLIB_ERROR", e.getMessage(), null));
        } catch (Exception e) {
            result.error("JSON_ERROR", e.getMessage(), null);
        }
    }

    private void onUpdate(TdApi.Object object) {
        try {
            if (updateSink != null) {
                String jsonUpdate = TdApiConverter.toJson(object).toString();
                mainHandler.post(() -> {
                    if (updateSink != null) {
                        updateSink.success(jsonUpdate);
                    } else {
                        pendingUpdates.add(jsonUpdate);
                    }
                });
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private void onError(Throwable e) {
        try {
            if (updateSink != null) {
                mainHandler.post(() -> {
                    if (updateSink != null) {
                        updateSink.success(e.toString());
                    } else {
                        pendingUpdates.add(e.toString());
                    }
                });
            }
        } catch (Exception er) {
            er.printStackTrace();
        }
    }
}
