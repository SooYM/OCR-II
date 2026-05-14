import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

/// A single chat message in the conversation.
class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ChatMessage({required this.role, required this.content, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

/// Dedicated AI Clinical Chatbot screen with threaded conversation.
class AiChatScreen extends StatefulWidget {
  final DateTimeRange? dateRange;
  const AiChatScreen({super.key, this.dateRange});

  @override
  State<AiChatScreen> createState() => AiChatScreenState();
}

class AiChatScreenState extends State<AiChatScreen> with TickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  bool _isTyping = false;
  DateTimeRange? _activeDateRange;

  @override
  void initState() {
    super.initState();
    _activeDateRange = widget.dateRange;
    // Welcome message
    _messages.add(ChatMessage(
      role: 'assistant',
      content: "Hello! I'm your **AI Clinical Consultant**. I have access to your medical reports and can help you understand your health trends.\n\nYou can ask me things like:\n- *\"How is my cholesterol trending?\"*\n- *\"Are any of my values outside normal range?\"*\n- *\"What should I do about my iron levels?\"*\n\nWhat would you like to know?",
    ));
  }

  /// Called externally when dashboard date range changes.
  void updateDateRange(DateTimeRange? range) {
    setState(() => _activeDateRange = range);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isTyping) return;

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _isTyping = true;
    });
    _inputCtrl.clear();
    _scrollToBottom();

    try {
      String? startDate;
      String? endDate;
      if (_activeDateRange != null) {
        startDate = _activeDateRange!.start.toIso8601String();
        endDate = _activeDateRange!.end.toIso8601String();
      }

      final response = await ApiService.analyzeHealthTrends(
        query: text,
        startDate: startDate,
        endDate: endDate,
      );

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(role: 'assistant', content: response));
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: "I'm sorry, I encountered an error while analyzing your data. Please try again.\n\n*Error: $e*",
          ));
          _isTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ─── Header ───────────────────────────────────────────
        _buildHeader(cs),
        // ─── Date Range Chip ──────────────────────────────────
        if (_activeDateRange != null) _buildDateRangeChip(cs),
        // ─── Message List ─────────────────────────────────────
        Expanded(child: _buildMessageList(cs)),
        // ─── Input Bar ────────────────────────────────────────
        _buildInputBar(cs),
      ],
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient(context),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: cs.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Clinical Consultant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('Based on your medical reports', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          // Clear chat button
          if (_messages.length > 1)
            GestureDetector(
              onTap: () {
                setState(() {
                  _messages.removeRange(1, _messages.length); // Keep welcome message
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_sweep_rounded, size: 20, color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateRangeChip(ColorScheme cs) {
    final fmt = (DateTime d) => '${d.day}/${d.month}/${d.year}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: cs.primary.withValues(alpha: 0.06),
      child: Row(
        children: [
          Icon(Icons.date_range_rounded, size: 15, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            'Analyzing: ${fmt(_activeDateRange!.start)} – ${fmt(_activeDateRange!.end)}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ColorScheme cs) {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        // Typing indicator
        if (index == _messages.length && _isTyping) {
          return _buildTypingIndicator(cs);
        }

        final msg = _messages[index];
        final isUser = msg.role == 'user';

        return FadeInUp(
          duration: const Duration(milliseconds: 350),
          from: 20,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Assistant avatar
                if (!isUser) ...[
                  Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient(context),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                ],
                // Message bubble
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isUser
                          ? cs.primary
                          : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isUser ? 20 : 6),
                        bottomRight: Radius.circular(isUser ? 6 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isUser ? cs.primary : Colors.black).withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: isUser
                        ? Text(msg.content, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5, fontWeight: FontWeight.w500))
                        : MarkdownBody(
                            data: msg.content,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(color: cs.onSurface, fontSize: 14, height: 1.6),
                              strong: TextStyle(color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w700, height: 1.6),
                              em: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, fontStyle: FontStyle.italic, height: 1.6),
                              h1: TextStyle(color: cs.onSurface, fontSize: 17, fontWeight: FontWeight.w800, height: 1.5),
                              h2: TextStyle(color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w700, height: 1.5),
                              h3: TextStyle(color: cs.primary, fontSize: 15, fontWeight: FontWeight.w700, height: 1.5),
                              listBullet: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                              blockSpacing: 10,
                            ),
                          ),
                  ),
                ),
                // User avatar
                if (isUser) ...[
                  const SizedBox(width: 10),
                  Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.person_rounded, color: cs.primary, size: 18),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypingIndicator(ColorScheme cs) {
    return FadeInUp(
      duration: const Duration(milliseconds: 300),
      from: 15,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 600 + (i * 200)),
                    builder: (context, value, child) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.3 + (0.4 * value)),
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(ColorScheme cs) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.12))),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        children: [
          // Input field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _inputCtrl,
                focusNode: _inputFocus,
                style: TextStyle(fontSize: 14, color: cs.onSurface),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Ask about your health data...',
                  hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Send button
          GestureDetector(
            onTap: _isTyping ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: _isTyping ? null : AppTheme.primaryGradient(context),
                color: _isTyping ? cs.surfaceContainerHighest : null,
                borderRadius: BorderRadius.circular(23),
                boxShadow: _isTyping
                    ? null
                    : [BoxShadow(color: cs.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Icon(
                _isTyping ? Icons.hourglass_top_rounded : Icons.send_rounded,
                color: _isTyping ? cs.onSurfaceVariant : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
