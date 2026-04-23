import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sip_ua/sip_ua.dart';

import 'audio_service.dart';
import 'models.dart';
import 'storage_service.dart';

class SipService extends ChangeNotifier implements SipUaHelperListener {
  SipService._();

  static final SipService instance = SipService._();

  final SIPUAHelper _helper = SIPUAHelper();
  final StorageService _storageService = StorageService();
  final AudioService _audioService = AudioService();

  SipCredentials _credentials = SipCredentials.defaults;
  SipCredentials get credentials => _credentials;

  SipRegistrationStatus _registrationStatus = SipRegistrationStatus.idle;
  SipRegistrationStatus get registrationStatus => _registrationStatus;

  ActiveCallStatus _callStatus = ActiveCallStatus.idle;
  ActiveCallStatus get callStatus => _callStatus;

  String _statusMessage = 'Idle';
  String get statusMessage => _statusMessage;

  Call? _activeCall;
  Call? get activeCall => _activeCall;

  String _activeNumber = '';
  String get activeNumber => _activeNumber;

  bool _isIncomingActiveCall = false;
  bool get isIncomingActiveCall => _isIncomingActiveCall;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  bool get isSpeakerOn => _audioService.speakerOn;

  bool _incomingNavigationPending = false;
  bool get incomingNavigationPending => _incomingNavigationPending;

  DateTime? _callStartedAt;
  DateTime? _callEndedAt;
  bool _callWasConnected = false;

  String _lastError = '';
  String get lastError => _lastError;

  bool _pendingRegister = false;

  Future<void> initialize() async {
    _helper.addSipUaHelperListener(this);
    await _storageService.init();
    _credentials = await _storageService.loadCredentials();

    if (Platform.isAndroid &&
        _credentials.server.trim().toLowerCase() != 'localhost') {
      _credentials = _credentials.copyWith(server: 'localhost', port: 5060);
      await _storageService.saveCredentials(_credentials);
    }

    notifyListeners();
  }

  Future<void> saveCredentials(SipCredentials newCredentials) async {
    final normalized = _normalizeForPlatform(newCredentials);
    _credentials = normalized;
    await _storageService.saveCredentials(normalized);
    _statusMessage = 'Settings saved';
    notifyListeners();
  }

  Future<void> register() async {
    _lastError = '';
    if (!_credentials.isValid) {
      _lastError = 'Please enter valid SIP credentials.';
      _registrationStatus = SipRegistrationStatus.failed;
      _statusMessage = _lastError;
      notifyListeners();
      return;
    }

    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      _lastError = 'Microphone permission is required for calls.';
      _registrationStatus = SipRegistrationStatus.failed;
      _statusMessage = _lastError;
      notifyListeners();
      return;
    }

    _registrationStatus = SipRegistrationStatus.registering;
    _statusMessage = 'Registering...';
    _pendingRegister = true;
    notifyListeners();

    try {
      final effective = _normalizeForPlatform(_credentials);
      final transport = effective.transport.trim().toUpperCase();
      final transportType = _resolveTransport(transport);
      final isWs = transportType == TransportType.WS;
      final signalPort = effective.port;
      final wsPort = signalPort == 5060 ? 8088 : signalPort;
      final sipUri = isWs
        ? 'sip:${effective.username}@${effective.server}'
        : 'sip:${effective.username}@${effective.server}:$signalPort';
      final registrar = isWs
        ? 'sip:${effective.server}'
        : 'sip:${effective.server}:$signalPort';

      final uaSettings = UaSettings()
        ..host = effective.server
      ..port = signalPort.toString()
      ..uri = sipUri
        ..authorizationUser = effective.username
        ..password = effective.password
        ..displayName = effective.username
        ..register = false
      ..registrarServer = registrar
      ..transportType = transportType
      ..webSocketUrl = 'ws://${effective.server}:$wsPort/ws';

      await _helper.start(uaSettings);
    } catch (error) {
      _pendingRegister = false;
      _registrationStatus = SipRegistrationStatus.failed;
      _statusMessage = 'Registration failed';
      _lastError = error.toString();
      notifyListeners();
    }
  }

  SipCredentials _normalizeForPlatform(SipCredentials input) {
    if (Platform.isAndroid) {
      return input.copyWith(
        server: 'localhost',
        port: 5060,
        transport: 'TCP',
      );
    }
    return input;
  }

  Future<void> unregister() async {
    _pendingRegister = false;
    try {
      await _helper.unregister(true);
      _helper.stop();
      _registrationStatus = SipRegistrationStatus.unregistered;
      _statusMessage = 'Unregistered';
      notifyListeners();
    } catch (_) {
      _helper.stop();
      _registrationStatus = SipRegistrationStatus.unregistered;
      _statusMessage = 'Unregistered';
      notifyListeners();
    }
  }

  Future<bool> makeCall(String destination) async {
    _lastError = '';
    if (_registrationStatus != SipRegistrationStatus.registered) {
      _lastError = 'Register first before placing a call.';
      notifyListeners();
      return false;
    }

    final target = destination.trim();
    if (target.isEmpty) {
      _lastError = 'Enter a phone number or extension.';
      notifyListeners();
      return false;
    }

    final callTarget = 'sip:$target@${_credentials.server}:${_credentials.port}';
    final placed = await _helper.call(callTarget, voiceOnly: true);
    if (!placed) {
      _lastError = 'Failed to place call. Check SIP registration/network.';
      notifyListeners();
      return false;
    }

    _activeNumber = target;
    _callStartedAt = null;
    _callEndedAt = null;
    _callWasConnected = false;
    _callStatus = ActiveCallStatus.connecting;
    _isIncomingActiveCall = false;
    _statusMessage = 'Calling $target';
    notifyListeners();
    return true;
  }

  Future<void> answerIncomingCall() async {
    final call = _activeCall;
    if (call == null) {
      return;
    }

    call.answer(_helper.buildCallOptions(true));
    _statusMessage = 'Answering...';
    notifyListeners();
  }

  Future<void> rejectIncomingCall() async {
    _activeCall?.hangup();
  }

  Future<void> hangup() async {
    _activeCall?.hangup();
  }

  Future<void> toggleMute() async {
    final call = _activeCall;
    if (call == null) {
      return;
    }

    if (_isMuted) {
      call.unmute(true, false);
      _isMuted = false;
    } else {
      call.mute(true, false);
      _isMuted = true;
    }
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    final next = !_audioService.speakerOn;
    await _audioService.setSpeaker(next);
    notifyListeners();
  }

  Future<List<CallLogEntry>> fetchCallLogs() {
    return _storageService.fetchCallLogs();
  }

  String get formattedCallDuration {
    final startedAt = _callStartedAt;
    if (startedAt == null) {
      return '00:00';
    }

    final endTime = _callEndedAt ?? DateTime.now();
    final duration = endTime.difference(startedAt);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void markIncomingNavigationHandled() {
    if (_incomingNavigationPending) {
      _incomingNavigationPending = false;
      notifyListeners();
    }
  }

  TransportType _resolveTransport(String transport) {
    switch (transport) {
      case 'TCP':
        return TransportType.TCP;
      case 'WS':
        return TransportType.WS;
      default:
        return TransportType.WS;
    }
  }

  bool _isIncoming(Call call) {
    return call.direction.toString().contains('incoming');
  }

  Future<void> _persistCallLog({
    required String number,
    required bool isIncoming,
    required bool wasConnected,
    required DateTime? startedAt,
    required DateTime endedAt,
  }) async {
    if (number.trim().isEmpty) {
      return;
    }

    final durationSeconds = startedAt == null ? 0 : endedAt.difference(startedAt).inSeconds;

    final type = isIncoming
        ? (wasConnected ? CallLogType.incoming : CallLogType.missed)
        : CallLogType.outgoing;

    final entry = CallLogEntry(
      number: number,
      type: type,
      timestamp: endedAt,
      durationSeconds: durationSeconds,
    );

    await _storageService.saveCallLog(entry);
  }

  @override
  void callStateChanged(Call call, CallState state) {
    _activeCall = call;

    if (_activeNumber.isEmpty) {
      _activeNumber = call.remote_identity?.trim().isNotEmpty == true
          ? call.remote_identity!.trim()
          : 'Unknown';
    }

    if (_isIncoming(call)) {
      _isIncomingActiveCall = true;
    }

    switch (state.state) {
      case CallStateEnum.CALL_INITIATION:
        _callStartedAt = null;
        _callEndedAt = null;
        _callWasConnected = false;
        if (_isIncoming(call)) {
          _callStatus = ActiveCallStatus.ringing;
          _statusMessage = 'Incoming call from $_activeNumber';
          _incomingNavigationPending = true;
        } else {
          _callStatus = ActiveCallStatus.connecting;
          _statusMessage = 'Dialing $_activeNumber';
        }
        break;
      case CallStateEnum.CONNECTING:
      case CallStateEnum.PROGRESS:
      case CallStateEnum.ACCEPTED:
        _callStatus = ActiveCallStatus.connecting;
        _statusMessage = 'Connecting...';
        break;
      case CallStateEnum.CONFIRMED:
        _callStatus = ActiveCallStatus.inCall;
        _statusMessage = 'In call';
        _callStartedAt ??= DateTime.now();
        _callWasConnected = true;
        break;
      case CallStateEnum.MUTED:
        _isMuted = true;
        break;
      case CallStateEnum.UNMUTED:
        _isMuted = false;
        break;
      case CallStateEnum.ENDED:
        final number = _activeNumber;
        final startedAt = _callStartedAt;
        final endedAt = DateTime.now();
        final wasIncoming = _isIncomingActiveCall;
        final wasConnected = _callWasConnected;
        _callStatus = ActiveCallStatus.ended;
        _statusMessage = 'Call ended';
        _callEndedAt = endedAt;
        unawaited(
          _persistCallLog(
            number: number,
            isIncoming: wasIncoming,
            wasConnected: wasConnected,
            startedAt: startedAt,
            endedAt: endedAt,
          ),
        );
        _activeCall = null;
        break;
      case CallStateEnum.FAILED:
        final number = _activeNumber;
        final startedAt = _callStartedAt;
        final endedAt = DateTime.now();
        final wasIncoming = _isIncomingActiveCall;
        final wasConnected = _callWasConnected;
        _callStatus = ActiveCallStatus.failed;
        _statusMessage = 'Call failed';
        _callEndedAt = endedAt;
        unawaited(
          _persistCallLog(
            number: number,
            isIncoming: wasIncoming,
            wasConnected: wasConnected,
            startedAt: startedAt,
            endedAt: endedAt,
          ),
        );
        _activeCall = null;
        break;
      case CallStateEnum.NONE:
      case CallStateEnum.STREAM:
      case CallStateEnum.REFER:
      case CallStateEnum.HOLD:
      case CallStateEnum.UNHOLD:
        break;
    }

    if (_callStatus == ActiveCallStatus.ended ||
        _callStatus == ActiveCallStatus.failed) {
      _resetCallUiState();
    }

    notifyListeners();
  }

  void _resetCallUiState() {
    unawaited(_audioService.reset());
    _isMuted = false;
    _incomingNavigationPending = false;
    _isIncomingActiveCall = false;
    _callWasConnected = false;
    _activeNumber = '';
    _callStartedAt = null;
    _callEndedAt = null;
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    switch (state.state) {
      case RegistrationStateEnum.REGISTERED:
        _pendingRegister = false;
        _registrationStatus = SipRegistrationStatus.registered;
        _statusMessage = 'Registered';
        _lastError = '';
        break;
      case RegistrationStateEnum.REGISTRATION_FAILED:
        _pendingRegister = false;
        _registrationStatus = SipRegistrationStatus.failed;
        _statusMessage = 'Registration failed';
        _lastError = state.cause.toString();
        break;
      case RegistrationStateEnum.UNREGISTERED:
        _pendingRegister = false;
        _registrationStatus = SipRegistrationStatus.unregistered;
        _statusMessage = 'Unregistered';
        break;
      case RegistrationStateEnum.NONE:
      case null:
        _pendingRegister = false;
        _registrationStatus = SipRegistrationStatus.idle;
        _statusMessage = 'Idle';
        break;
    }
    notifyListeners();
  }

  @override
  void transportStateChanged(TransportState state) {
    if (state.state == TransportStateEnum.CONNECTED &&
        _pendingRegister &&
        _registrationStatus == SipRegistrationStatus.registering) {
      _statusMessage = 'Transport connected, registering...';
      notifyListeners();
      _helper.register();
      return;
    }

    if (state.state == TransportStateEnum.DISCONNECTED &&
        _registrationStatus == SipRegistrationStatus.registered) {
      _statusMessage = 'Transport disconnected';
      notifyListeners();
    }
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void onNewNotify(Notify ntf) {}

  @override
  void onNewReinvite(ReInvite event) {}
}
