import 'package:flutter/material.dart';
import 'app.dart';
import 'services/sip_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SipService.instance.initialize();
  runApp(const SipApp());
}
