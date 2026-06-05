import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

/// A premium, custom onboarding and user guide wizard.
///
/// It can be auto-triggered for first-time users or manually launched from settings.
class UserGuideDialog extends StatefulWidget {
  final bool isFirstTime;

  const UserGuideDialog({
    super.key,
    required this.isFirstTime,
  });

  @override
  State<UserGuideDialog> createState() => _UserGuideDialogState();
}

class _UserGuideDialogState extends State<UserGuideDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _numPages = 6;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _numPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_user_guide_v1', true);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 660),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      theme.colorScheme.surface.withOpacity(0.9),
                      theme.colorScheme.surfaceContainerHighest.withOpacity(0.95),
                    ]
                  : [
                      theme.colorScheme.surface.withOpacity(0.95),
                      theme.colorScheme.surfaceContainerHighest.withOpacity(0.98),
                    ],
            ),
          ),
          child: Column(
            children: [
              // Header with Title and Page Indicator
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'MedScan Guide',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentPage + 1} / $_numPages',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // PageView Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  children: [
                    _buildPage(
                      index: 0,
                      icon: Icons.document_scanner_rounded,
                      iconColor: Colors.blue,
                      title: '1. Scan & Clean Up',
                      description: 'Take a picture of your health report or upload it from your phone. Our app automatically cleans up the image to make it easy to read:',
                      bullets: [
                        'Photo Tips: Keep the paper flat, straight, and under bright light.',
                        'Remove Shadows: Dark patches or uneven lighting are automatically cleared.',
                        'Smart Trim: Cut out blank spaces between rows to focus on the numbers.',
                        'Combine Pages: Multi-page reports are saved together as one record.',
                      ],
                      visualWidget: const ScanVisualWidget(),
                    ),
                    _buildPage(
                      index: 1,
                      icon: Icons.fact_check_rounded,
                      iconColor: Colors.teal,
                      title: '2. Check & Fix',
                      description: 'Take a quick look at the numbers our app read from your report before saving it:',
                      bullets: [
                        'Report Details: Double-check things like the lab number or test date.',
                        'Standard Time: Automatically converts times like "3 PM" into clinical 24-hour time.',
                        'Quick Edits: Just tap any name, number, or unit to correct it yourself.',
                      ],
                      visualWidget: const VerifyVisualWidget(),
                    ),
                    _buildPage(
                      index: 2,
                      icon: Icons.auto_awesome_rounded,
                      iconColor: Colors.amber.shade600,
                      title: '3. AI Health Summary',
                      description: 'Get a simple, easy-to-read summary of your test results at the top of your screen:',
                      bullets: [
                        'Simple Insights: Tells you if any of your health numbers look high or low.',
                        'Connecting the Dots: Shows how different test results might relate to one another.',
                        'Ask Questions: Tap the chat link next to the summary to ask the AI assistant about your results.',
                      ],
                      visualWidget: const SummaryVisualWidget(),
                    ),
                    _buildPage(
                      index: 3,
                      icon: Icons.trending_up_rounded,
                      iconColor: Colors.purple,
                      title: '4. Track Your Progress',
                      description: 'Watch how your health changes over time using interactive graphs:',
                      bullets: [
                        'Compare Numbers: Show different markers (like good and bad cholesterol) on the same chart.',
                        'Filter Dates: Choose specific dates to see how you were doing then.',
                        'Easy Categories: Your health markers are sorted into simple groups (like Heart, Liver, Kidney, and blood tests).',
                      ],
                      visualWidget: const TrendsVisualWidget(),
                    ),
                    _buildPage(
                      index: 4,
                      icon: Icons.copy_all_rounded,
                      iconColor: Colors.deepOrange,
                      title: '5. Block Duplicates',
                      description: 'Keep your history neat and clean by automatically ignoring duplicate uploads:',
                      bullets: [
                        'Matching Lab Numbers: Detects if the same lab test is uploaded twice.',
                        'Similar Readings: Flags reports with nearly identical values to avoid repeats.',
                        'Date Check: Prevents saving the same test if it was uploaded within a few days.',
                      ],
                      visualWidget: const DeduplicationVisualWidget(),
                    ),
                    _buildPage(
                      index: 5,
                      icon: Icons.psychology_rounded,
                      iconColor: Colors.pink,
                      title: '6. Chat with AI Assistant',
                      description: 'Talk to a private helper that explains complicated medical terms in plain language:',
                      bullets: [
                        'Personal Health Context: The AI looks at all your uploaded reports to understand your history.',
                        'Practical Tips: Ask for wellness ideas, food suggestions, or help understanding your trends.',
                        'Start Chatting: Ask things like "What is good cholesterol?" or "Explain my kidney test results."',
                      ],
                      visualWidget: const ChatVisualWidget(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Bottom Navigation / Action Row
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left Action (Back or Skip)
                    if (_currentPage > 0)
                      TextButton(
                        onPressed: _prevPage,
                        child: Text(
                          'Back',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    // Center Dot Indicators
                    Row(
                      children: List.generate(
                        _numPages,
                        (index) => _buildDot(index, theme),
                      ),
                    ),

                    // Right Action (Next or Finish)
                    ElevatedButton(
                      onPressed: _currentPage == _numPages - 1
                          ? _completeOnboarding
                          : _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        _currentPage == _numPages - 1
                            ? (widget.isFirstTime ? 'Get Started' : 'Got it!')
                            : 'Next',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index, ThemeData theme) {
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 6,
      width: isActive ? 16 : 6,
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildPage({
    required int index,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required List<String> bullets,
    required Widget visualWidget,
  }) {
    final isActive = _currentPage == index;

    if (!isActive) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual Mockup / Animation Container (Comprehensiveness & Intuitiveness)
          Center(
            child: FadeIn(
              duration: const Duration(milliseconds: 600),
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: iconColor.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Center(child: visualWidget),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title & Icon Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Description Text
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),

          // Detailed Bullet points
          ...bullets.map((bullet) {
            final parts = bullet.split(':');
            final hasTitle = parts.length > 1;
            final bulletTitle = hasTitle ? parts[0] : '';
            final bulletBody = hasTitle ? parts.sublist(1).join(':') : bullet;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0, right: 8.0),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withOpacity(0.85),
                          height: 1.4,
                          fontFamily: 'Helvetica Neue',
                        ),
                        children: [
                          if (hasTitle)
                            TextSpan(
                              text: '$bulletTitle: ',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          TextSpan(text: bulletBody),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── 1. SCAN & ENHANCE VISUAL ──────────────────────────────────────────────
class ScanVisualWidget extends StatefulWidget {
  const ScanVisualWidget({super.key});

  @override
  State<ScanVisualWidget> createState() => _ScanVisualWidgetState();
}

class _ScanVisualWidgetState extends State<ScanVisualWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        // Camera Framing Guide Box
        Center(
          child: Container(
            width: 180,
            height: 110,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(height: 8, width: 60, decoration: BoxDecoration(color: Colors.blue.withOpacity(0.3), borderRadius: BorderRadius.circular(4))),
                    Container(height: 8, width: 25, decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(4))),
                  ],
                ),
                Container(height: 6, width: 140, decoration: BoxDecoration(color: theme.colorScheme.onSurface.withOpacity(0.1), borderRadius: BorderRadius.circular(3))),
                Container(height: 6, width: 120, decoration: BoxDecoration(color: theme.colorScheme.onSurface.withOpacity(0.1), borderRadius: BorderRadius.circular(3))),
                Row(
                  children: [
                    Container(height: 8, width: 40, decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(4))),
                    const Spacer(),
                    Container(height: 8, width: 30, decoration: BoxDecoration(color: Colors.blue.withOpacity(0.3), borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Photo Corner Viewfinder Targets
        Center(
          child: SizedBox(
            width: 196,
            height: 126,
            child: CustomPaint(
              painter: _ViewfinderPainter(color: Colors.blue),
            ),
          ),
        ),

        // Animated Laser Beam
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double offset = 10 + (_controller.value * 110);
            return Positioned(
              top: offset,
              left: (MediaQuery.of(context).size.width - 240) / 2 > 0
                  ? (MediaQuery.of(context).size.width - 240) / 2
                  : 80,
              right: (MediaQuery.of(context).size.width - 240) / 2 > 0
                  ? (MediaQuery.of(context).size.width - 240) / 2
                  : 80,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.withOpacity(0),
                      Colors.blue,
                      Colors.blue,
                      Colors.blue.withOpacity(0),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.8),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  final Color color;
  _ViewfinderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    const len = 12.0;

    // Top-Left corner
    canvas.drawLine(Offset.zero, const Offset(len, 0), paint);
    canvas.drawLine(Offset.zero, const Offset(0, len), paint);

    // Top-Right corner
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);

    // Bottom-Left corner
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - len), paint);

    // Bottom-Right corner
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - len, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - len), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── 2. VERIFY & CORRECT VISUAL ─────────────────────────────────────────────
class VerifyVisualWidget extends StatefulWidget {
  const VerifyVisualWidget({super.key});

  @override
  State<VerifyVisualWidget> createState() => _VerifyVisualWidgetState();
}

class _VerifyVisualWidgetState extends State<VerifyVisualWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _cursorOpacity;
  bool _showMockKeyboard = false;
  String _currentVal = "12.5";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _cursorOpacity = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 50),
    ]).animate(_controller);

    _controller.addListener(() {
      // Simulate user editing:
      // at 1.5s switch value, show mock typing
      if (_controller.value > 0.35 && _controller.value < 0.75) {
        if (!_showMockKeyboard) {
          setState(() {
            _showMockKeyboard = true;
            _currentVal = "12.0";
          });
        }
      } else {
        if (_showMockKeyboard) {
          setState(() {
            _showMockKeyboard = false;
            _currentVal = "12.5";
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Verify Screen Mini Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                'Verify & Edit Data',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Simulated Row from VerifyScreen
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'LDL Cholesterol',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface.withOpacity(0.55),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _currentVal,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_showMockKeyboard)
                            FadeTransition(
                              opacity: _cursorOpacity,
                              child: Container(
                                width: 2,
                                height: 14,
                                color: cs.primary,
                              ),
                            ),
                          const SizedBox(width: 6),
                          Text(
                            'mmol/L',
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurface.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _showMockKeyboard
                        ? Colors.orange.withOpacity(0.12)
                        : Colors.teal.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _showMockKeyboard ? Icons.edit_rounded : Icons.check_circle_outline_rounded,
                    size: 16,
                    color: _showMockKeyboard ? Colors.orange : Colors.teal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          AnimatedOpacity(
            opacity: _showMockKeyboard ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.keyboard_outlined, size: 12, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  'Correcting value...',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 3. AI HEALTH SUMMARY VISUAL ────────────────────────────────────────────
class SummaryVisualWidget extends StatelessWidget {
  const SummaryVisualWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => AppTheme.primaryGradient(context).createShader(bounds),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'AI Health Summary',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient(context),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'AI ASSISTED',
                  style: TextStyle(
                    fontSize: 6,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your cholesterol is high, but your kidney function is normal.',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.4,
                    color: cs.onSurface.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildSummaryPill(context, 'LDL Cholesterol', Colors.red, true),
                        const SizedBox(width: 6),
                        _buildSummaryPill(context, 'Creatinine', Colors.green, false),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient(context),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 8, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Ask AI',
                            style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPill(BuildContext context, String text, Color color, bool isWarn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (isWarn) ...[
            const SizedBox(width: 3),
            Icon(Icons.warning_amber_rounded, size: 8, color: color),
          ],
        ],
      ),
    );
  }
}

// ─── 4. TRACK YOUR TRENDS VISUAL ───────────────────────────────────────────
class TrendsVisualWidget extends StatelessWidget {
  const TrendsVisualWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Header mimicking dashboard mini chart
            Row(
              children: [
                Expanded(
                  child: Text(
                    'HDL Cholesterol (mmol/L)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Icon(Icons.fullscreen_rounded, size: 14, color: cs.onSurface.withOpacity(0.3)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // Graphic Trends Box
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 80,
                    child: CustomPaint(
                      painter: _MiniGraphPainter(
                        strokeColor: Colors.purple,
                        gridColor: cs.outline.withOpacity(0.3),
                        referenceColor: Colors.teal.withOpacity(0.12),
                        onSurfaceColor: cs.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Legend / Overlay Information
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.purple, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          const Text('HDL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          const Text('Ref Range', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Rising 📈',
                          style: TextStyle(fontSize: 8, color: Colors.purple, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniGraphPainter extends CustomPainter {
  final Color strokeColor;
  final Color gridColor;
  final Color referenceColor;
  final Color onSurfaceColor;

  _MiniGraphPainter({
    required this.strokeColor,
    required this.gridColor,
    required this.referenceColor,
    required this.onSurfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final Paint fillPaint = Paint()
      ..color = strokeColor.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final Paint dotPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = onSurfaceColor.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final Paint gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final Paint refPaint = Paint()
      ..color = referenceColor
      ..style = PaintingStyle.fill;

    // Draw grid lines
    for (double i = 0; i <= size.width; i += size.width / 4) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i <= size.height; i += size.height / 3) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // Draw Reference Range Box (Green Zone)
    canvas.drawRect(
      Rect.fromLTRB(0, size.height * 0.4, size.width, size.height * 0.8),
      refPaint,
    );

    // Points representing biological changes (e.g. rising health trends)
    final points = [
      Offset(size.width * 0.05, size.height * 0.85),
      Offset(size.width * 0.3, size.height * 0.72),
      Offset(size.width * 0.55, size.height * 0.55),
      Offset(size.width * 0.8, size.height * 0.50),
      Offset(size.width * 0.95, size.height * 0.28),
    ];

    // Spline path
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final pPrev = points[i - 1];
      final pCurr = points[i];
      final cp1 = Offset(pPrev.dx + (pCurr.dx - pPrev.dx) / 2, pPrev.dy);
      final cp2 = Offset(pPrev.dx + (pCurr.dx - pPrev.dx) / 2, pCurr.dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pCurr.dx, pCurr.dy);
    }

    // Graph filling below line
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Draw nodes/dots
    for (var p in points) {
      canvas.drawCircle(p, 4.0, dotPaint);
      canvas.drawCircle(p, 6.0, Paint()..color = Colors.white.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 2);
    }

    // Border
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(8)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── 5. SMART DEDUPLICATION VISUAL ──────────────────────────────────────────
class DeduplicationVisualWidget extends StatefulWidget {
  const DeduplicationVisualWidget({super.key});

  @override
  State<DeduplicationVisualWidget> createState() => _DeduplicationVisualWidgetState();
}

class _DeduplicationVisualWidgetState extends State<DeduplicationVisualWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _overlap;
  late Animation<double> _shieldScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _overlap = TweenSequence([
      // Stage 1: Stacked reports separate slightly
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
      // Stage 2: Hold separation
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
      // Stage 3: Merge closer together and trigger block shield
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 40),
    ]).animate(_controller);

    _shieldScale = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 25),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 15),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shift = _overlap.value * 28.0;
        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Left / Back Report
              Transform.translate(
                offset: Offset(-24 - shift, 0),
                child: Transform.rotate(
                  angle: -0.05,
                  child: _buildMiniReport(theme, 'Ref: #9822', cs.primary),
                ),
              ),

              // Right / Front Report
              Transform.translate(
                offset: Offset(24 + shift, 0),
                child: Transform.rotate(
                  angle: 0.05,
                  child: _buildMiniReport(theme, 'Ref: #9822', Colors.red),
                ),
              ),

              // Block Shield
              ScaleTransition(
                scale: _shieldScale,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Duplicate Blocked',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniReport(ThemeData theme, String titleText, Color statusColor) {
    final cs = theme.colorScheme;
    return SizedBox(
      width: 110,
      height: 110,
      child: GlassCard(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    titleText,
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: cs.onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.delete_outline, size: 10, color: cs.onSurfaceVariant.withOpacity(0.4)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 8, color: cs.secondary.withOpacity(0.7)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '12-May-2026',
                    style: TextStyle(fontSize: 7, fontWeight: FontWeight.w600, color: cs.onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.science_outlined, size: 8, color: cs.onSurface.withOpacity(0.7)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Lipid Profile',
                    style: TextStyle(fontSize: 7, color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(width: 70, height: 3, decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.08), borderRadius: BorderRadius.circular(1.5))),
            const SizedBox(height: 3),
            Container(width: 50, height: 3, decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.08), borderRadius: BorderRadius.circular(1.5))),
          ],
        ),
      ),
    );
  }
}

// ─── 6. CONSULT AI ASSISTANT VISUAL ─────────────────────────────────────────
class ChatVisualWidget extends StatefulWidget {
  const ChatVisualWidget({super.key});

  @override
  State<ChatVisualWidget> createState() => _ChatVisualWidgetState();
}

class _ChatVisualWidgetState extends State<ChatVisualWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _typingDotsCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _controller.addListener(() {
      final count = (_controller.value * 4).floor() % 4;
      if (count != _typingDotsCount) {
        setState(() {
          _typingDotsCount = count;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // User Bubble Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  margin: const EdgeInsets.only(left: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withOpacity(0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Explain my hemoglobin test.',
                    style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_rounded, color: cs.primary, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // AI Response Bubble Row
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient(context),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: cs.primary.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 12),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  margin: const EdgeInsets.only(right: 30),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.6),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: cs.outline.withOpacity(0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          'Your value is 12.0 g/dL. This is slightly low, which is commonly associated with...',
                          style: TextStyle(
                            fontSize: 9,
                            height: 1.3,
                            color: cs.onSurface.withOpacity(0.9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Typist dots indicator
                      Text(
                        '.' * _typingDotsCount,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 7. SETTINGS VISUAL WIDGET ──────────────────────────────────────────────
class SettingsVisualWidget extends StatelessWidget {
  const SettingsVisualWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.settings_rounded, color: cs.primary, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                'Settings & Preferences',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.straighten_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Biomarker Units',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.onSurface),
                      ),
                      Text(
                        'Convert automatically to mmol/L',
                        style: TextStyle(fontSize: 8, color: cs.onSurface.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.primary.withOpacity(0.3)),
                  ),
                  child: Text(
                    'mmol/L',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: cs.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 7. FILTER & REFRESH VISUAL ──────────────────────────────────────────────
class FilterRefreshVisualWidget extends StatelessWidget {
  const FilterRefreshVisualWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mock Date Filter Button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.primary, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.date_range_rounded, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Last 6 Months',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Mock Refresh Button
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.refresh_rounded, size: 18, color: cs.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Use these top dashboard controls to filter date ranges or pull the latest medical reports instantly.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.4,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

