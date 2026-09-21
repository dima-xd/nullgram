package org.nilgram;

import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.provider.OpenableColumns;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

/** Hands Dart the t.me link the app was opened with, or the content shared into it. */
public class IntentChannel implements EventChannel.StreamHandler {
    private static final String METHOD_CHANNEL = "nullgram/intents";
    private static final String EVENT_CHANNEL = "nullgram/intents/events";

    private final Context context;
    private final MethodChannel methodChannel;
    private final EventChannel eventChannel;

    private EventChannel.EventSink sink;
    private Map<String, Object> pending;

    public IntentChannel(BinaryMessenger messenger, Context context) {
        this.context = context.getApplicationContext();
        methodChannel = new MethodChannel(messenger, METHOD_CHANNEL);
        eventChannel = new EventChannel(messenger, EVENT_CHANNEL);
        eventChannel.setStreamHandler(this);
        methodChannel.setMethodCallHandler((call, result) -> {
            if ("getInitial".equals(call.method)) {
                Map<String, Object> initial = pending;
                pending = null;
                result.success(initial);
                return;
            }
            result.notImplemented();
        });
    }

    public void dispose() {
        methodChannel.setMethodCallHandler(null);
        eventChannel.setStreamHandler(null);
        sink = null;
    }

    /** Called for the launch intent before Dart is listening, and for every later one. */
    public void handle(Intent intent) {
        Map<String, Object> payload = parse(intent);
        if (payload == null) return;
        if (sink != null) {
            sink.success(payload);
        } else {
            pending = payload;
        }
    }

    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        sink = events;
    }

    @Override
    public void onCancel(Object arguments) {
        sink = null;
    }

    private Map<String, Object> parse(Intent intent) {
        if (intent == null || intent.getAction() == null) return null;
        String action = intent.getAction();

        if (Intent.ACTION_VIEW.equals(action)) {
            Uri data = intent.getData();
            if (data == null) return null;
            Map<String, Object> payload = new HashMap<>();
            payload.put("type", "link");
            payload.put("url", data.toString());
            return payload;
        }

        if (!Intent.ACTION_SEND.equals(action)
                && !Intent.ACTION_SEND_MULTIPLE.equals(action)) {
            return null;
        }

        List<String> paths = new ArrayList<>();
        if (Intent.ACTION_SEND.equals(action)) {
            addPath(paths, singleStream(intent));
        } else {
            for (Uri uri : multipleStreams(intent)) addPath(paths, uri);
        }

        CharSequence text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT);
        if (text == null && paths.isEmpty()) return null;

        Map<String, Object> payload = new HashMap<>();
        payload.put("type", "share");
        payload.put("text", text == null ? null : text.toString());
        payload.put("paths", paths);
        return payload;
    }

    @SuppressWarnings("deprecation")
    private Uri singleStream(Intent intent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri.class);
        }
        return intent.getParcelableExtra(Intent.EXTRA_STREAM);
    }

    @SuppressWarnings("deprecation")
    private List<Uri> multipleStreams(Intent intent) {
        ArrayList<Uri> uris;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            uris = intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri.class);
        } else {
            uris = intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM);
        }
        return uris == null ? new ArrayList<>() : uris;
    }

    private void addPath(List<String> paths, Uri uri) {
        if (uri == null) return;
        if ("file".equals(uri.getScheme())) {
            String path = uri.getPath();
            if (path != null) paths.add(path);
            return;
        }
        String copied = copyToCache(uri);
        if (copied != null) paths.add(copied);
    }

    /** A content:// URI has no path TDLib can open, so the bytes are copied out. */
    private String copyToCache(Uri uri) {
        ContentResolver resolver = context.getContentResolver();
        File directory = new File(context.getCacheDir(), "shared");
        if (!directory.exists() && !directory.mkdirs()) return null;

        File target = new File(directory, System.currentTimeMillis() + "_" + displayName(resolver, uri));
        try (InputStream input = resolver.openInputStream(uri);
             OutputStream output = new FileOutputStream(target)) {
            if (input == null) return null;
            byte[] buffer = new byte[8192];
            int read;
            while ((read = input.read(buffer)) != -1) {
                output.write(buffer, 0, read);
            }
            return target.getAbsolutePath();
        } catch (IOException | SecurityException e) {
            return null;
        }
    }

    private String displayName(ContentResolver resolver, Uri uri) {
        try (Cursor cursor = resolver.query(uri, null, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                int index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (index >= 0) {
                    String name = cursor.getString(index);
                    if (name != null && !name.isEmpty()) {
                        return name.replaceAll("[^A-Za-z0-9._-]", "_");
                    }
                }
            }
        } catch (Exception ignored) {
            // Falls through to the generic name below.
        }
        return "shared";
    }
}
