import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import 'main_screen.dart';

/// Premium dark-themed Login / Register screen.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;
  String _selectedGender = 'Male';

  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _icCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  bool _preferNotToSayIc = false;
  bool _preferNotToSayDob = false;
  late AnimationController _pulseController;

  void _onPasswordChanged() {
    if (!_isLogin) {
      setState(() {});
    }
  }

  bool _isPasswordStrong(String password) {
    if (password.length < 8) return false;
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasDigits = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    return hasUppercase && hasDigits && hasSpecial;
  }

  String? get _passwordErrorText {
    if (_isLogin) return null;
    final text = _passwordCtrl.text;
    if (text.isEmpty) return null;
    if (!_isPasswordStrong(text)) {
      return 'Password must be >= 8 chars and include capital, number, and symbol';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _passwordCtrl.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _passwordCtrl.removeListener(_onPasswordChanged);
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    _icCtrl.dispose();
    _dobCtrl.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Extract DOB (YYYY-MM-DD) from Malaysian IC number (YYMMDD-XX-XXXX).
  String? _extractDobFromIc(String ic) {
    final cleaned = ic.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length < 6) return null;
    final yy = int.tryParse(cleaned.substring(0, 2));
    final mm = int.tryParse(cleaned.substring(2, 4));
    final dd = int.tryParse(cleaned.substring(4, 6));
    if (yy == null || mm == null || dd == null) return null;
    if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;
    final nowYear = DateTime.now().year;
    final century = (nowYear ~/ 100) * 100;
    int fullYear = century + yy;
    if (fullYear > nowYear) fullYear -= 100;
    return '$fullYear-${mm.toString().padLeft(2, '0')}-${dd.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final icNumber = _preferNotToSayIc ? '' : _icCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email and password are required');
      return;
    }
    if (!_isLogin && name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }

    if (!_isLogin) {
      // Strong password validation for registration
      if (password.length < 8) {
        setState(() => _error = 'Password must be at least 8 characters long');
        return;
      }
      final hasUppercase = password.contains(RegExp(r'[A-Z]'));
      final hasDigits = password.contains(RegExp(r'[0-9]'));
      final hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      if (!hasUppercase || !hasDigits || !hasSpecial) {
        setState(() => _error = 'Password must include at least one capital letter, one number, and one symbol');
        return;
      }
    }

    // IC validation (only if user didn't skip it)
    if (!_isLogin && !_preferNotToSayIc && icNumber.isEmpty) {
      setState(() => _error = 'Identity Number (eg:NRIC) is required (or choose "Prefer not to provide")');
      return;
    }

    String dob = '';
    if (!_isLogin) {
      if (!_preferNotToSayIc && icNumber.isNotEmpty) {
        // Auto-extract DOB from IC
        final extracted = _extractDobFromIc(icNumber);
        if (extracted == null) {
          setState(() => _error = 'Invalid Identity Number. First 6 digits must be YYMMDD.');
          return;
        }
        dob = extracted;
      } else if (!_preferNotToSayDob) {
        // Manual DOB entry
        final manualDob = _dobCtrl.text.trim();
        if (manualDob.isEmpty) {
          setState(() => _error = 'Birthdate is required (or choose "Prefer not to provide")');
          return;
        }
        // Validate the format YYYY-MM-DD
        final dobRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
        if (!dobRegex.hasMatch(manualDob)) {
          setState(() => _error = 'Invalid DOB format. Please use YYYY-MM-DD.');
          return;
        }
        final parsedDob = DateTime.tryParse(manualDob);
        if (parsedDob == null || parsedDob.isAfter(DateTime.now())) {
          setState(() => _error = 'Invalid Date of Birth.');
          return;
        }
        dob = manualDob;
      }
      // If both are "prefer not to say", dob stays empty
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        await AuthService.login(email, password);
      } else {
        await AuthService.register(email, name, password, _selectedGender, dob, icNumber);
      }
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _error = null;
    });
  }

  void _showServerSettings() {
    final controller = TextEditingController(text: ApiService.baseUrl);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Server URL',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 4),
            const Text('Paste your localtunnel URL here',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: const InputDecoration(
                hintText: 'https://your-tunnel.loca.lt',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ApiService.setBaseUrl(controller.text.trim());
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: Theme.of(context).colorScheme.primary, content: const Text('Server URL updated')),
                  );
                },
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Logo ──
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_pulseController.value * 0.05),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient(context),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.25 * _pulseController.value),
                                blurRadius: 40,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.document_scanner_outlined,
                              color: Colors.white, size: 44),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  Text(
                    'MedScan',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isLogin ? 'Welcome back' : 'Create your account',
                    style: TextStyle(fontSize: 15),
                  ),

                  const SizedBox(height: 36),

                  // ── Form Card ──
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Error banner
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              border: Border.all(color: Theme.of(context).colorScheme.error.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(_error!,
                                      style: const TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Email field
                        _buildTextField(
                          controller: _emailCtrl,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),

                        // Name field (register only)
                        if (!_isLogin) ...[
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _nameCtrl,
                            label: 'Full Name',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 14),
                          _buildGenderDropdown(),

                          // Identity Number section
                          const SizedBox(height: 18),
                          if (!_preferNotToSayIc) ...[
                            _buildTextField(
                              controller: _icCtrl,
                              label: 'Identity Number (eg:NRIC)',
                              icon: Icons.badge_outlined,
                              hintText: 'e.g., 860101-08-1234',
                              keyboardType: TextInputType.number,
                              inputFormatters: [IcNumberInputFormatter()],
                            ),
                            const SizedBox(height: 8),
                          ],
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              'Identity Number (eg:NRIC) is only for verification of report ownership. You can choose not to provide it.',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: Checkbox(
                                  value: _preferNotToSayIc,
                                  onChanged: (val) {
                                    setState(() {
                                      _preferNotToSayIc = val ?? false;
                                      if (_preferNotToSayIc) _icCtrl.clear();
                                    });
                                  },
                                  activeColor: Theme.of(context).colorScheme.primary,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _preferNotToSayIc = !_preferNotToSayIc;
                                      if (_preferNotToSayIc) _icCtrl.clear();
                                    });
                                  },
                                  child: const Text(
                                    'Prefer not to provide Identity Number (eg:NRIC)',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Birthdate section with toggle (shown when Identity Number is skipped)
                          if (_preferNotToSayIc) ...[
                            const SizedBox(height: 18),
                            if (!_preferNotToSayDob) ...[
                              _buildTextField(
                                controller: _dobCtrl,
                                label: 'Birthdate',
                                icon: Icons.cake_outlined,
                                hintText: 'YYYY-MM-DD',
                                keyboardType: TextInputType.datetime,
                              ),
                              const SizedBox(height: 8),
                            ],
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                'Birthdate is only for verification of report ownership. You can choose not to provide it.',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: _preferNotToSayDob,
                                    onChanged: (val) {
                                      setState(() {
                                        _preferNotToSayDob = val ?? false;
                                        if (_preferNotToSayDob) _dobCtrl.clear();
                                      });
                                    },
                                    activeColor: Theme.of(context).colorScheme.primary,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _preferNotToSayDob = !_preferNotToSayDob;
                                        if (_preferNotToSayDob) _dobCtrl.clear();
                                      });
                                    },
                                    child: const Text(
                                      'Prefer not to provide Birthdate',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],

                        const SizedBox(height: 14),

                        // Password field
                        _buildTextField(
                          controller: _passwordCtrl,
                          label: 'Password',
                          icon: Icons.lock_outline,
                          obscure: _obscurePassword,
                          errorText: _passwordErrorText,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Submit button
                        _buildSubmitButton(),

                        const SizedBox(height: 16),

                        // Toggle login/register
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isLogin ? "Don't have an account? " : 'Already have an account? ',
                              style: const TextStyle(fontSize: 13),
                            ),
                            GestureDetector(
                              onTap: _isLoading ? null : _toggleMode,
                              child: Text(
                                _isLogin ? 'Register' : 'Login',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Server settings link
                  GestureDetector(
                    onTap: _showServerSettings,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.settings, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text('Server Settings',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),


                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    String? hintText,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      inputFormatters: inputFormatters,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffixIcon,
        hintText: hintText,
        errorText: errorText,
      ),
      onSubmitted: (_) => _submit(),
    );
  }

  Widget _buildSubmitButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient(context),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.primaryShadow(context),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _submit,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading)
                  const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                else ...[
                  Icon(_isLogin ? Icons.login_rounded : Icons.person_add_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    _isLogin ? 'Login' : 'Create Account',
                    style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      dropdownColor: Theme.of(context).colorScheme.surface,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15),
      decoration: const InputDecoration(
        labelText: 'Gender',
        prefixIcon: Icon(Icons.wc_outlined, size: 20),
      ),
      items: const [
        DropdownMenuItem(value: 'Male', child: Text('Male')),
        DropdownMenuItem(value: 'Female', child: Text('Female')),
      ],
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _selectedGender = val;
          });
        }
      },
    );
  }


}

/// Auto-formats IC input as YYMMDD-XX-XXXX by inserting dashes at positions 6 and 8.
class IcNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Strip all non-digits
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    // Cap at 12 digits
    final capped = digitsOnly.length > 12 ? digitsOnly.substring(0, 12) : digitsOnly;

    final buffer = StringBuffer();
    for (int i = 0; i < capped.length; i++) {
      if (i == 6 || i == 8) buffer.write('-');
      buffer.write(capped[i]);
    }
    final formatted = buffer.toString();

    // Calculate new cursor position
    int cursorOffset = newValue.selection.baseOffset;
    int digitsBeforeCursor = newValue.text
        .substring(0, cursorOffset.clamp(0, newValue.text.length))
        .replaceAll(RegExp(r'\D'), '')
        .length;
    int formattedPos = 0;
    int digitCount = 0;
    while (formattedPos < formatted.length && digitCount < digitsBeforeCursor) {
      if (formatted[formattedPos] != '-') digitCount++;
      formattedPos++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formattedPos),
    );
  }
}
