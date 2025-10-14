package org.nullgram;

import org.drinkless.tdlib.TdApi;
import org.json.JSONObject;
import org.json.JSONArray;
import org.json.JSONException;

import java.lang.reflect.Array;
import java.lang.reflect.Field;
import java.util.Iterator;
import android.util.Base64;

public class TdApiConverter {

    public static TdApi.Function fromJson(JSONObject obj) throws Exception {
        String type = obj.getString("@type");
        String className = "org.drinkless.tdlib.TdApi$" + capitalizeType(type);
        Class<?> clazz = Class.forName(className);
        TdApi.Function instance = (TdApi.Function) clazz.getDeclaredConstructor().newInstance();

        Iterator<String> keys = obj.keys();
        while (keys.hasNext()) {
            String key = keys.next();
            if (key.equals("@type")) continue;

            try {
                Field field = clazz.getField(key);
                Object value = obj.get(key);

                if (value instanceof JSONObject) {
                    field.set(instance, parseObject((JSONObject) value));
                } else if (value instanceof JSONArray) {
                    field.set(instance, parseArray((JSONArray) value, field.getType().getComponentType()));
                } else if (field.getType() == String.class) {
                    field.set(instance, value.toString());
                } else if (field.getType() == int.class) {
                    field.setInt(instance, ((Number) value).intValue());
                } else if (field.getType() == long.class) {
                    field.setLong(instance, ((Number) value).longValue());
                } else if (field.getType() == boolean.class) {
                    field.setBoolean(instance, (Boolean) value);
                } else if (field.getType() == byte[].class) {
                    if (value instanceof String) {
                        field.set(instance, Base64.decode((String) value, Base64.NO_WRAP));
                    }
                } else {
                    field.set(instance, value);
                }
            } catch (Exception e) {
                throw new Exception("Error processing field: " + key, e);
            }
        }

        return instance;
    }

    private static Object parseObject(JSONObject obj) throws Exception {
        String type = obj.getString("@type");
        String className = "org.drinkless.tdlib.TdApi$" + capitalizeType(type);
        Class<?> clazz = Class.forName(className);
        Object instance = clazz.getDeclaredConstructor().newInstance();

        Iterator<String> keys = obj.keys();
        while (keys.hasNext()) {
            String key = keys.next();
            if (key.equals("@type")) continue;

            try {
                Field field = clazz.getField(key);
                Object value = obj.get(key);

                if (value instanceof JSONObject) {
                    field.set(instance, parseObject((JSONObject) value));
                } else if (value instanceof JSONArray) {
                    field.set(instance, parseArray((JSONArray) value, field.getType().getComponentType()));
                } else if (field.getType() == String.class) {
                    field.set(instance, value.toString());
                } else if (field.getType() == int.class) {
                    field.setInt(instance, ((Number) value).intValue());
                } else if (field.getType() == long.class) {
                    field.setLong(instance, ((Number) value).longValue());
                } else if (field.getType() == boolean.class) {
                    field.setBoolean(instance, (Boolean) value);
                } else if (field.getType() == byte[].class) {
                    if (value instanceof String) {
                        field.set(instance, Base64.decode((String) value, Base64.NO_WRAP));
                    }
                } else {
                    field.set(instance, value);
                }
            } catch (Exception e) {
                throw new Exception("Error processing field: " + key, e);
            }
        }

        return instance;
    }

    private static Object parseArray(JSONArray array, Class<?> componentType) throws Exception {
        int length = array.length();
        Object result = Array.newInstance(componentType, length);

        for (int i = 0; i < length; i++) {
            Object item = array.get(i);

            if (item instanceof JSONObject) {
                Array.set(result, i, parseObject((JSONObject) item));
            } else if (item instanceof JSONArray) {
                Array.set(result, i, parseArray((JSONArray) item, componentType.getComponentType()));
            } else if (componentType == int.class) {
                Array.setInt(result, i, ((Number) item).intValue());
            } else if (componentType == long.class) {
                Array.setLong(result, i, ((Number) item).longValue());
            } else if (componentType == boolean.class) {
                Array.setBoolean(result, i, (Boolean) item);
            } else if (componentType == String.class) {
                Array.set(result, i, item.toString());
            } else {
                Array.set(result, i, item);
            }
        }

        return result;
    }

    public static JSONObject toJson(TdApi.Object object) throws IllegalAccessException, JSONException {
        JSONObject json = new JSONObject();
        json.put("@type", object.getClass().getSimpleName());

        Field[] fields = object.getClass().getFields();
        for (Field field : fields) {
            Object value = field.get(object);
            if (value == null) continue;

            String fieldName = field.getName();

            if (value instanceof TdApi.Object) {
                json.put(fieldName, toJson((TdApi.Object) value));
            } else if (value.getClass().isArray()) {
                json.put(fieldName, arrayToJson(value));
            } else if (value instanceof byte[]) {
                json.put(fieldName, Base64.encodeToString((byte[]) value, Base64.NO_WRAP));
            } else {
                json.put(fieldName, value);
            }
        }

        return json;
    }

    private static JSONArray arrayToJson(Object array) throws IllegalAccessException, JSONException {
        JSONArray jsonArray = new JSONArray();
        int length = Array.getLength(array);

        for (int i = 0; i < length; i++) {
            Object item = Array.get(array, i);

            if (item == null) {
                jsonArray.put(JSONObject.NULL);
            } else if (item instanceof TdApi.Object) {
                jsonArray.put(toJson((TdApi.Object) item));
            } else if (item.getClass().isArray()) {
                jsonArray.put(arrayToJson(item));
            } else {
                jsonArray.put(item);
            }
        }

        return jsonArray;
    }

    private static String capitalizeType(String str) {
        if (str == null || str.isEmpty()) return str;
        return Character.toUpperCase(str.charAt(0)) + str.substring(1);
    }
}
