import 'package:flutter/material.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

class PhoneInputPage extends StatefulWidget {
  const PhoneInputPage({super.key});

  @override
  State<PhoneInputPage> createState() => _PhoneInputPageState();
}

class _PhoneInputPageState extends State<PhoneInputPage> {
  final isLoading = ValueNotifier<bool>(false);
  final TextEditingController _phoneController = TextEditingController();

  void _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    isLoading.value = true;

    try {
      await TDLibClient.setAuthenticationPhoneNumber(phoneNumber: phone);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _navigateToQrLogin() async {
    await TDLibClient.requestQrCodeAuthentication();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(theme),
              const SizedBox(height: 32),
              _buildPhoneInput(theme, isDark),
              const SizedBox(height: 24),
              _buildSendButton(theme),
              const SizedBox(height: 16),
              Text(
                'The code was sent to your phone number',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: _navigateToQrLogin,
                child: Text(
                  'Login with QR Code',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) => Column(
    children: [
      Text(
        'Welcome to Nullgram',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(
        'Please enter your phone number to continue',
        style: theme.textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    ],
  );

  Widget _buildPhoneInput(ThemeData theme, bool isDark) => Container(
    decoration: BoxDecoration(
      color: isDark ? Colors.grey[900] : Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: TextField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.phone),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        // TODO: Add country code selector and phone hint
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
      ),
    ),
  );

  Widget _buildSendButton(ThemeData theme) => ValueListenableBuilder<bool>(
    valueListenable: isLoading,
    builder: (context, loading, _) => SizedBox(
      width: double.infinity,
      height: 50,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : ElevatedButton(
        onPressed: _sendCode,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: theme.colorScheme.primary,
        ),
        child: const Text(
          'Send Code',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ),
  );
}
