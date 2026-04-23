import 'package:flutter/material.dart';

import '../app.dart';
import '../services/models.dart';
import '../services/sip_service.dart';

class DialpadScreen extends StatefulWidget {
  const DialpadScreen({super.key});

  @override
  State<DialpadScreen> createState() => _DialpadScreenState();
}

class _DialpadScreenState extends State<DialpadScreen> {
  final SipService _sipService = SipService.instance;
  final TextEditingController _numberController = TextEditingController();

  final List<String> _digits = const [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '*',
    '0',
    '#',
  ];

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  void _appendDigit(String digit) {
    _numberController.text = '${_numberController.text}$digit';
    _numberController.selection = TextSelection.fromPosition(
      TextPosition(offset: _numberController.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dialpad'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.callLog),
            icon: const Icon(Icons.history),
            tooltip: 'Call Logs',
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _sipService,
        builder: (context, _) {
          final canCall =
              _sipService.registrationStatus == SipRegistrationStatus.registered;

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
              child: Column(
                children: [
                  TextField(
                    controller: _numberController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number / Extension',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          final current = _numberController.text;
                          if (current.isEmpty) {
                            return;
                          }
                          _numberController.text =
                              current.substring(0, current.length - 1);
                        },
                        icon: const Icon(Icons.backspace_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Status: ${_sipService.statusMessage}'),
                  ),
                  if (_sipService.lastError.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _sipService.lastError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      itemCount: _digits.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemBuilder: (context, index) {
                        final digit = _digits[index];
                        return OutlinedButton(
                          onPressed: () => _appendDigit(digit),
                          child: Text(
                            digit,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _numberController,
                      builder: (context, value, _) {
                        final destination = value.text.trim();
                        return FilledButton.icon(
                          onPressed: (!canCall || destination.isEmpty)
                              ? null
                              : () async {
                                  final ok = await _sipService.makeCall(destination);
                                  if (!ok) {
                                    if (!context.mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(_sipService.lastError)),
                                    );
                                    return;
                                  }
                                  if (!context.mounted) {
                                    return;
                                  }
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.call,
                                    arguments: destination,
                                  );
                                },
                          icon: const Icon(Icons.call),
                          label: Text(
                            canCall ? 'Call' : 'Register from Settings first',
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
