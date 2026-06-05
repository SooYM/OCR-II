import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import '../widgets/user_guide_dialog.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import 'auth_screen.dart';
import 'dictionary_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onTriggerGuide;

  const SettingsScreen({
    super.key,
    this.onTriggerGuide,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  bool _isLoading = false;
  final Set<String> _expandedSections = {};
  bool _isNameEditable = false;
  bool _isEmailEditable = false;

  Future<bool?> _showEditConfirmation(String label) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: Text('Edit $label?'),
        content: Text('Are you sure you want to edit your $label?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _nameController.text = AuthService.currentUser?['name'] ?? '';
    _emailController.text = AuthService.currentUser?['email'] ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty || _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and email cannot be empty')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.updateProfile(
        _nameController.text.trim(),
        _emailController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _isNameEditable = false;
          _isEmailEditable = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to log out of MedScan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Logout', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _deactivateAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Text('Deactivate Account?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will mark your account as inactive and log you out.'),
            SizedBox(height: 12),
            Text('WARNING: You will not be able to log back in without contacting support.',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Deactivate', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await AuthService.deactivateAccount();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AuthScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deactivation failed: $e')),
          );
        }
      }
    }
  }



  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isChanging = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password', prefixIcon: Icon(Icons.lock_outline_rounded)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password', prefixIcon: Icon(Icons.password_rounded)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm New Password', prefixIcon: Icon(Icons.check_circle_outline_rounded)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: isChanging ? null : () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
                  return;
                }
                if (newPasswordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
                  return;
                }

                setDialogState(() => isChanging = true);
                try {
                  await AuthService.changePassword(
                    currentPasswordController.text,
                    newPasswordController.text,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully')));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                } finally {
                  setDialogState(() => isChanging = false);
                }
              },
              child: isChanging ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserGuide() {
    if (widget.onTriggerGuide != null) {
      widget.onTriggerGuide!();
    } else {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => const UserGuideDialog(isFirstTime: false),
      );
    }
  }

  void _showTermsAndConditions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.gavel_rounded, color: Colors.indigo, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Terms & Conditions of Usage',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  _buildTermsSection(
                    '1. Acceptance of Terms',
                    'By creating an account and using MedScan, you agree to be bound by these Terms & Conditions. If you do not agree, please discontinue use immediately.',
                  ),
                  _buildTermsSection(
                    '2. Medical Disclaimer',
                    'MedScan is a health data management tool only. It is NOT a substitute for professional medical advice, diagnosis, or treatment. Always seek the advice of your physician or other qualified health provider with any questions regarding a medical condition. Never disregard professional medical advice or delay in seeking it because of information presented by MedScan.',
                  ),
                  _buildTermsSection(
                    '3. Data Collection & Privacy',
                    'MedScan collects and stores your medical report data (biomarkers, lab values, patient information) securely. Your data is used solely for:\n• Displaying your health history and trends\n• Generating AI-powered health summaries\n• Verifying report ownership via identity matching\n\nWe do not sell, share, or distribute your medical data to third parties.',
                  ),
                  _buildTermsSection(
                    '4. Identity Number (eg:NRIC) & Date of Birth Optionality',
                    'Your Identity Number (eg:NRIC) and Date of Birth are requested solely for the purpose of verifying that uploaded medical reports belong to you. You have the right to decline providing either or both of these fields during registration by selecting "Prefer not to say". Choosing not to provide this information may reduce the accuracy of report ownership verification but will not prevent you from using the application.',
                  ),
                  _buildTermsSection(
                    '5. Report Verification & Mismatch Handling',
                    'MedScan performs identity verification checks when reports are uploaded, including name, gender, date of birth, and Identity Number (eg:NRIC) matching. If a mismatch or potential duplicate is detected, you will be notified with a justification explaining the flag. You may choose to proceed with the upload at your own discretion after confirming twice.',
                  ),
                  _buildTermsSection(
                    '6. AI-Generated Content',
                    'Health summaries and AI chat responses are generated by artificial intelligence models. While we strive for accuracy, AI-generated content may contain errors, omissions, or misinterpretations. These outputs should be used for informational purposes only and should not replace consultation with a healthcare professional.',
                  ),
                  _buildTermsSection(
                    '7. User Responsibilities',
                    '• You are responsible for the accuracy of data you submit and verify.\n• You must not upload reports belonging to other individuals without their consent.\n• You must keep your account credentials secure.\n• You agree not to misuse the application for any unlawful purpose.',
                  ),
                  _buildTermsSection(
                    '8. Data Retention',
                    'Your medical data is retained as long as your account is active. Upon account deactivation, your data may be retained for a reasonable period for backup and compliance purposes before permanent deletion.',
                  ),
                  _buildTermsSection(
                    '9. Limitation of Liability',
                    'MedScan and its developers shall not be held liable for any direct, indirect, incidental, or consequential damages arising from the use of this application, including but not limited to medical decisions made based on data or AI-generated summaries provided by the application.',
                  ),
                  _buildTermsSection(
                    '10. Changes to Terms',
                    'We reserve the right to modify these Terms & Conditions at any time. Continued use of MedScan after changes constitutes acceptance of the updated terms.',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Last updated: May 2026',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
                border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outline, width: 1)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: const Icon(Icons.settings_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Text('Settings',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface, letterSpacing: -0.3)),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Profile Section
                    _buildSection(
                      title: 'Profile Settings',
                      icon: Icons.person_outline_rounded,
                      children: [
                        _buildTextField(
                          label: 'Full Name',
                          controller: _nameController,
                          icon: Icons.person_outline_rounded,
                          isEditable: _isNameEditable,
                          focusNode: _nameFocusNode,
                          onEditRequested: () async {
                            final confirm = await _showEditConfirmation('Full Name');
                            if (confirm == true) {
                              setState(() => _isNameEditable = true);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _nameFocusNode.requestFocus();
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Email Address',
                          controller: _emailController,
                          icon: Icons.email_outlined,
                          isEditable: _isEmailEditable,
                          focusNode: _emailFocusNode,
                          onEditRequested: () async {
                            final confirm = await _showEditConfirmation('Email Address');
                            if (confirm == true) {
                              setState(() => _isEmailEditable = true);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _emailFocusNode.requestFocus();
                              });
                            }
                          },
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),
                        // Read-only identity fields
                        _buildReadOnlyField(
                          label: 'Identity Number (eg:NRIC)',
                          value: AuthService.currentUser?['ic_number'] ?? '—',
                          icon: Icons.badge_outlined,
                        ),
                        const SizedBox(height: 12),
                        _buildReadOnlyField(
                          label: 'Date of Birth',
                          value: AuthService.currentUser?['dob'] ?? '—',
                          icon: Icons.cake_outlined,
                        ),
                        const SizedBox(height: 12),
                        _buildReadOnlyField(
                          label: 'Gender',
                          value: AuthService.currentUser?['gender'] ?? '—',
                          icon: Icons.wc_outlined,
                        ),
                        const SizedBox(height: 24),
                        GradientButton(
                          label: 'Save Profile Changes',
                          onPressed: _updateProfile,
                          isLoading: _isLoading,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // App Preferences
                    _buildSection(
                      title: 'App Preferences',
                      icon: Icons.palette_outlined,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(ThemeService.instance.isDarkMode ? 'Dark Mode' : 'Light Mode'),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ThemeService.instance.isDarkMode ? Colors.orangeAccent.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              ThemeService.instance.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                              color: ThemeService.instance.isDarkMode ? Colors.orangeAccent : Colors.blue,
                            ),
                          ),
                          trailing: Switch.adaptive(
                            value: ThemeService.instance.isDarkMode,
                            onChanged: (_) => setState(() => ThemeService.instance.toggleTheme()),
                            activeColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Medical Reference
                    _buildSection(
                      title: 'Medical Reference',
                      icon: Icons.menu_book_rounded,
                      children: [
                        _buildActionTile(
                          label: 'Data Dictionary & Units',
                          subtitle: 'View standard biomarkers and units',
                          icon: Icons.menu_book_rounded,
                          color: Colors.teal,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const DictionaryScreen()),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Support & Guide
                    _buildSection(
                      title: 'Support & Guide',
                      icon: Icons.help_outline_rounded,
                      children: [
                        _buildActionTile(
                          label: 'App User Guide',
                          subtitle: 'Learn how to use MedScan',
                          icon: Icons.lightbulb_outline_rounded,
                          color: Colors.amber.shade600,
                          onTap: _showUserGuide,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Terms & Conditions
                    _buildSection(
                      title: 'Terms & Conditions',
                      icon: Icons.gavel_rounded,
                      children: [
                        _buildActionTile(
                          label: 'Terms of Use',
                          subtitle: 'View terms and conditions of usage',
                          icon: Icons.description_outlined,
                          color: Colors.indigo,
                          onTap: _showTermsAndConditions,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Account Actions
                    _buildSection(
                      title: 'Account Actions',
                      icon: Icons.manage_accounts_rounded,
                      children: [
                        _buildActionTile(
                          label: 'Change Password',
                          subtitle: 'Update your login credentials',
                          icon: Icons.lock_reset_rounded,
                          color: Theme.of(context).colorScheme.secondary,
                          onTap: _showChangePasswordDialog,
                        ),
                        const Divider(height: 24),
                        _buildActionTile(
                          label: 'Logout',
                          subtitle: 'Log out of your account',
                          icon: Icons.logout_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          onTap: _handleLogout,
                        ),
                        const Divider(height: 24),
                        _buildActionTile(
                          label: 'Deactivate Account',
                          subtitle: 'Mark account as inactive',
                          icon: Icons.no_accounts_rounded,
                          color: Theme.of(context).colorScheme.error,
                          onTap: _deactivateAccount,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children, IconData? icon}) {
    final isExpanded = _expandedSections.contains(title);
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedSections.remove(title);
                } else {
                  _expandedSections.add(title);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: isExpanded ? 0.6 : 0.35),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(title,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isEditable,
    required VoidCallback onEditRequested,
    required FocusNode focusNode,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) {
              setState(() {
                if (label == 'Full Name') {
                  _isNameEditable = false;
                } else if (label == 'Email Address') {
                  _isEmailEditable = false;
                }
              });
            }
          },
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: !isEditable,
            focusNode: focusNode,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20),
              suffixIcon: !isEditable
                  ? IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: onEditRequested,
                    )
                  : null,
              hintText: 'Enter $label',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(isEditable ? 0.3 : 0.15),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
              Icon(Icons.lock_outline, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}


