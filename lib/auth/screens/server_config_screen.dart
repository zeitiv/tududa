import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../session/auth_messages.dart';
import '../session/server_config.dart';
import '../session/session_controller.dart';
import '../../l10n/strings.dart';

/// Server configuration screen - first-time setup.
class ServerConfigScreen extends ConsumerStatefulWidget {
  const ServerConfigScreen({super.key});

  @override
  ConsumerState<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends ConsumerState<ServerConfigScreen>
    with SingleTickerProviderStateMixin {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await _configure(allowInsecure: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _configure({required bool allowInsecure}) async {
    final controller = ref.read(sessionControllerProvider.notifier);
    try {
      await controller.configureServer(
        _urlController.text,
        allowInsecure: allowInsecure,
      );
    } on InsecureServerError {
      if (!mounted) return;
      if (await _confirmInsecure()) await _configure(allowInsecure: true);
    } on ServerConfigError catch (e) {
      _showError(describeAuthError(e));
    } on ApiError catch (e) {
      _showError(describeAuthError(e));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<bool> _confirmInsecure() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use insecure HTTP?'),
        content: const Text(
          'This address does not use HTTPS. Your password and tasks would be '
          'sent without encryption and could be read on the network. Only '
          'continue on a network you trust.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Use insecure HTTP'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo / Icon
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.tertiary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),

                    Text(
                      'Welcome to Tududa',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connect to your self-hosted Tududa server',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Server URL input
                    TextFormField(
                      controller: _urlController,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: strings.serverUrl,
                        hintText: 'https://tududi.example.com',
                        prefixIcon: const Icon(Icons.dns_outlined),
                        helperText: 'Enter your Tududa server address',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a server URL';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _connect(),
                    ),
                    const SizedBox(height: 24),

                    // Connect button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _connect,
                        icon: _busy
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                          _busy ? 'Connecting...' : 'Connect',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
