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
                      visualWidget: const _ScanVisualWidget(),
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
                      visualWidget: const _VerifyVisualWidget(),
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
                      visualWidget: const _SummaryVisualWidget(),
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
                      visualWidget: const _TrendsVisualWidget(),
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
                      visualWidget: const _DeduplicationVisualWidget(),
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
                      visualWidget: const _ChatVisualWidget(),
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
                    child: RichText(
                      text: TextSpan(
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
class _ScanVisualWidget extends StatefulWidget {
  const _ScanVisualWidget();

  @override
  State<_ScanVisualWidget> createState() => _ScanVisualWidgetState();
}

class _ScanVisualWidgetState extends State<_ScanVisualWidget> with SingleTickerProviderStateMixin {
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
class _VerifyVisualWidget extends StatefulWidget {
  const _VerifyVisualWidget();

  @override
  State<_VerifyVisualWidget> createState() => _VerifyVisualWidgetState();
}

class _VerifyVisualWidgetState extends State<_VerifyVisualWidget> with SingleTickerProviderStateMixin {
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showMockKeyboard ? theme.colorScheme.primary : theme.colorScheme.outline,
                width: _showMockKeyboard ? 1.5 : 1,
              ),
              boxShadow: [
                if (_showMockKeyboard)
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    blurRadius: 8,
                  ),
              ],
            ),
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
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _currentVal,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_showMockKeyboard)
                            FadeTransition(
                              opacity: _cursorOpacity,
                              child: Container(
                                width: 2,
                                height: 16,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            'mmol/L',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withOpacity(0.4),
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
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.teal.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _showMockKeyboard ? Icons.edit_rounded : Icons.check_circle_outline_rounded,
                    size: 18,
                    color: _showMockKeyboard ? Colors.orange : Colors.teal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AnimatedOpacity(
            opacity: _showMockKeyboard ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.keyboard_outlined, size: 12, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  const Text(
                    'Correcting value...',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 3. AI HEALTH SUMMARY VISUAL ────────────────────────────────────────────
class _SummaryVisualWidget extends StatelessWidget {
  const _SummaryVisualWidget();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology_alt_rounded, size: 16, color: Colors.amber),
              ),
              const SizedBox(width: 8),
              Text(
                'AI Summary',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check, size: 10, color: Colors.teal),
                    SizedBox(width: 2),
                    Text('Stable', style: TextStyle(fontSize: 9, color: Colors.teal, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your cholesterol is high, but your kidney function is normal.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildSummaryPill(context, 'LDL Cholesterol', Colors.red, true),
                    const SizedBox(width: 6),
                    _buildSummaryPill(context, 'Creatinine', Colors.green, false),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (isWarn) ...[
            const SizedBox(width: 3),
            Icon(Icons.warning_amber_rounded, size: 9, color: color),
          ],
        ],
      ),
    );
  }
}

// ─── 4. TRACK YOUR TRENDS VISUAL ───────────────────────────────────────────
class _TrendsVisualWidget extends StatelessWidget {
  const _TrendsVisualWidget();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Graphic Trends Box
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 110,
              child: CustomPaint(
                painter: _MiniGraphPainter(
                  strokeColor: Colors.purple,
                  gridColor: theme.colorScheme.outline.withOpacity(0.3),
                  referenceColor: Colors.teal.withOpacity(0.12),
                  onSurfaceColor: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Legend / Overlay Information
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.purple, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text('HDL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text('Ref Range', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Trends: Rising 📈',
                    style: TextStyle(fontSize: 9, color: Colors.purple, fontWeight: FontWeight.bold),
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
class _DeduplicationVisualWidget extends StatefulWidget {
  const _DeduplicationVisualWidget();

  @override
  State<_DeduplicationVisualWidget> createState() => _DeduplicationVisualWidgetState();
}

class _DeduplicationVisualWidgetState extends State<_DeduplicationVisualWidget> with SingleTickerProviderStateMixin {
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
                  child: _buildMiniReport(theme, 'Report 1\nSpecimen #9822', Colors.blue),
                ),
              ),

              // Right / Front Report
              Transform.translate(
                offset: Offset(24 + shift, 0),
                child: Transform.rotate(
                  angle: 0.05,
                  child: _buildMiniReport(theme, 'Report 2\nSpecimen #9822', Colors.teal),
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

  Widget _buildMiniReport(ThemeData theme, String text, Color color) {
    return Container(
      width: 90,
      height: 110,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.description_rounded, size: 10, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, height: 1.2),
          ),
          const Spacer(),
          Container(width: 70, height: 4, decoration: BoxDecoration(color: theme.colorScheme.onSurface.withOpacity(0.1), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 3),
          Container(width: 50, height: 4, decoration: BoxDecoration(color: theme.colorScheme.onSurface.withOpacity(0.1), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 3),
          Container(width: 60, height: 4, decoration: BoxDecoration(color: theme.colorScheme.onSurface.withOpacity(0.1), borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
  }
}

// ─── 6. CONSULT AI ASSISTANT VISUAL ─────────────────────────────────────────
class _ChatVisualWidget extends StatefulWidget {
  const _ChatVisualWidget();

  @override
  State<_ChatVisualWidget> createState() => _ChatVisualWidgetState();
}

class _ChatVisualWidgetState extends State<_ChatVisualWidget> with SingleTickerProviderStateMixin {
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
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // User Bubble
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.only(left: 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: const Text(
                'Explain my hemoglobin test.',
                style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // AI Response Bubble
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(right: 30),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(Icons.psychology_rounded, size: 12, color: Colors.pink),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Your value is 12.0 g/dL. This is slightly low, which is commonly associated with...',
                      style: TextStyle(
                        fontSize: 9,
                        height: 1.3,
                        color: theme.colorScheme.onSurface.withOpacity(0.9),
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
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
