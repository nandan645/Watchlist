import 'package:flutter/material.dart';
import '../services/settings.dart';

Future<void> showSupabaseSettingsDialog(
  BuildContext context,
  VoidCallback onSave,
) async {
  final currentUrl = await Settings.supabaseUrl;
  final currentKey = await Settings.supabaseKey;

  final urlController = TextEditingController(text: currentUrl);
  final keyController = TextEditingController(text: currentKey);

  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final dialogBgColor = isDark ? const Color(0xFF121212) : Colors.white;
      final headerBorderColor = isDark ? const Color(0xFF242424) : const Color(0xFFE3E7EE);
      final iconBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);
      final iconColor = const Color(0xFF2563EB);
      final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF18212F);
      final mutedTextColor = isDark ? const Color(0xFF888888) : const Color(0xFF5A6474);
      final fieldBorderColor = isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE3E7EE);
      final fieldFillColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFBFCFE);
      final footerBgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFC);
      final cancelButtonBgColor = isDark ? const Color(0xFF2E2E2E) : Colors.white;
      final cancelButtonTextColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF5A6474);
      final cancelButtonBorderColor = isDark ? const Color(0xFF424242) : const Color(0xFFCBD5E1);
      final hintColor = isDark ? const Color(0xFF5A6474) : const Color(0xFF94A3B8);

      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: dialogBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: headerBorderColor),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.5) : const Color.fromRGBO(0, 0, 0, 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: headerBorderColor),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.cloud_outlined,
                        color: iconColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Supabase Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Dialog Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Supabase Project URL',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: urlController,
                        style: TextStyle(color: primaryTextColor),
                        decoration: InputDecoration(
                          hintText: 'https://your-project.supabase.co',
                          hintStyle: TextStyle(color: hintColor),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: fieldBorderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: fieldBorderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD), width: 1.5),
                          ),
                          filled: true,
                          fillColor: fieldFillColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Supabase Anon / Publishable Key',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: keyController,
                        style: TextStyle(color: primaryTextColor),
                        decoration: InputDecoration(
                          hintText: 'your-anon-publishable-key',
                          hintStyle: TextStyle(color: hintColor),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: fieldBorderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: fieldBorderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD), width: 1.5),
                          ),
                          filled: true,
                          fillColor: fieldFillColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Configure your custom Supabase instance credentials. Leave these fields empty to reset back to the default developer fallback key.\n\nNote: Changes require you to restart the application to apply.',
                        style: TextStyle(
                          fontSize: 13,
                          color: mutedTextColor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2D1F0E) : const Color(0xFFFFFBEB),
                          border: Border.all(color: isDark ? const Color(0xFF6B4B18) : const Color(0xFFFDE68A)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Warning: Modifying credentials shifts database connections. Ensure your new database contains a fully configured "watchlist" table, or app synchronization will fail.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Dialog Footer / Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: footerBgColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border(
                    top: BorderSide(color: headerBorderColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cancelButtonBorderColor, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        backgroundColor: cancelButtonBgColor,
                        foregroundColor: cancelButtonTextColor,
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        final url = urlController.text.trim();
                        final key = keyController.text.trim();
                        await Settings.setSupabaseUrl(url);
                        await Settings.setSupabaseKey(key);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Supabase settings saved. Please restart the app to apply changes.'),
                              backgroundColor: Color(0xFF2563EB),
                            ),
                          );
                        }
                        onSave();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      child: const Text(
                        'Save & Restart Info',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showApiKeyDialog(
  BuildContext context,
  VoidCallback onSave,
) async {
  final currentApiKey = await Settings.apiKey;
  final apiKeyController = TextEditingController(text: currentApiKey);

  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final dialogBgColor = isDark ? const Color(0xFF121212) : Colors.white;
      final headerBorderColor = isDark ? const Color(0xFF242424) : const Color(0xFFE3E7EE);
      final iconBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);
      final iconColor = const Color(0xFF2563EB);
      final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF18212F);
      final mutedTextColor = isDark ? const Color(0xFF888888) : const Color(0xFF5A6474);
      final fieldBorderColor = isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE3E7EE);
      final fieldFillColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFBFCFE);
      final footerBgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFC);
      final cancelButtonBgColor = isDark ? const Color(0xFF2E2E2E) : Colors.white;
      final cancelButtonTextColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF5A6474);
      final cancelButtonBorderColor = isDark ? const Color(0xFF424242) : const Color(0xFFCBD5E1);
      final hintColor = isDark ? const Color(0xFF5A6474) : const Color(0xFF94A3B8);

      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: BoxDecoration(
            color: dialogBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: headerBorderColor),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.5) : const Color.fromRGBO(0, 0, 0, 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: headerBorderColor),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.key_rounded,
                        color: iconColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'TMDB API Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Dialog Content
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'API Key',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: apiKeyController,
                      style: TextStyle(color: primaryTextColor),
                      decoration: InputDecoration(
                        hintText: 'Enter your TMDB API Key',
                        hintStyle: TextStyle(color: hintColor),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: fieldBorderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: fieldBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD), width: 1.5),
                        ),
                        filled: true,
                        fillColor: fieldFillColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Configure your custom TMDB API Key to fetch movies and TV shows from TMDB. Leave empty to fallback to the default TMDB API Key.',
                      style: TextStyle(
                        fontSize: 13,
                        color: mutedTextColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              // Dialog Footer / Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: footerBgColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border(
                    top: BorderSide(color: headerBorderColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cancelButtonBorderColor, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        backgroundColor: cancelButtonBgColor,
                        foregroundColor: cancelButtonTextColor,
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        await Settings.setApiKey(apiKeyController.text);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                        onSave();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      child: const Text(
                        'Save Key',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
