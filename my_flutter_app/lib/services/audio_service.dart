import 'package:flutter_webrtc/flutter_webrtc.dart';

class AudioService {
  bool _speakerOn = false;

  bool get speakerOn => _speakerOn;

  Future<void> setSpeaker(bool enabled) async {
    _speakerOn = enabled;
    await Helper.setSpeakerphoneOn(enabled);
  }

  Future<void> reset() async {
    await setSpeaker(false);
  }
}
