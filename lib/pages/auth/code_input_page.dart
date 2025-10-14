import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nullgram/tdlib/tdlib_client.dart';

class CodeInputPage extends StatefulWidget {
  const CodeInputPage({super.key});

  @override
  State<CodeInputPage> createState() => _CodeInputPageState();
}

class _CodeInputPageState extends State<CodeInputPage> {
  final isLoading = ValueNotifier<bool>(false);
  final TextEditingController _codeController = TextEditingController();
  final hasError = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Input the code')),
      );
      return;
    }

    isLoading.value = true;
    hasError.value = false;

    try {
      var result = await TDLibClient.checkAuthenticationCode(code: code);

      if (result == "PHONE_CODE_INVALID") {
        hasError.value = true;

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid code'),
            backgroundColor: Colors.red,
          ),
        );
        _codeController.clear();
      }
    } catch (e) {
      hasError.value = true;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(theme),
              const SizedBox(height: 32),
              _buildCodeInput(theme, isDark),
              const SizedBox(height: 24),
              _buildVerifyButton(theme),
              const SizedBox(height: 16),
              Text(
                'The code was sent to your phone number',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) => Column(
    children: [
      Icon(
        Icons.message,
        size: 64,
        color: theme.colorScheme.primary,
      ),
      const SizedBox(height: 16),
      Text(
        'Input Code',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
    ],
  );

  Widget _buildCodeInput(ThemeData theme, bool isDark) => ValueListenableBuilder<bool>(
    valueListenable: hasError,
    builder: (context, error, _) => Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: error
            ? Border.all(color: Colors.red, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: error
                ? Colors.red.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 5,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(5),
        ],
        style: theme.textTheme.headlineMedium?.copyWith(
          letterSpacing: 8,
          fontWeight: FontWeight.bold,
          color: error ? Colors.red : null,
        ),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          hintText: '• • • • •',
          counterText: '',
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 20,
            horizontal: 16,
          ),
        ),
        onChanged: (_) {
          if (hasError.value) {
            hasError.value = false;
          }
        },
      ),
    ),
  );

  Widget _buildVerifyButton(ThemeData theme) => ValueListenableBuilder<bool>(
    valueListenable: isLoading,
    builder: (context, loading, _) => SizedBox(
      width: double.infinity,
      height: 50,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : ElevatedButton(
        onPressed: _verifyCode,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: theme.colorScheme.primary,
        ),
        child: const Text(
          'Verify',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ),
  );
}
