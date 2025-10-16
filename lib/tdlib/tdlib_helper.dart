import 'package:nullgram/tdlib/tdlib_client.dart';

class TDLibHelper {
  static Future<bool> isAuthorized() async {
    final state = await TDLibClient.getAuthorizationState();
    return state == 'AuthorizationStateReady';
  }
}