import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

import '../models/chat_models.dart';

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
  bool _isStreaming = false;
  DateTimeRange? _activeDateRange;
  StreamSubscription<String>? _streamSub;
  String? _currentSessionId;
  List<ChatSession> _sessions = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _activeDateRange = widget.dateRange;
    _initNewChat();
    _loadSessions();
  }

  void _initNewChat() {
    _messages.clear();
    _currentSessionId = null;
    _messages.add(ChatMessage(
      role: 'assistant',
      content: "Hello! I'm your **AI Clinical Consultant**. I have access to your medical reports and can help you understand your health trends.\n\nYou can ask me things like:\n- *\"How is my cholesterol trending?\"*\n- *\"Are any of my values outside normal range?\"*\n- *\"What should I do about my iron levels?\"*\n\nWhat would you like to know?",
    ));
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoadingHistory = true);
    try {
      final sessions = await ApiService.getChatSessions();
      if (mounted) setState(() => _sessions = sessions);
    } catch (e) {
      debugPrint('Failed to load sessions: $e');
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _loadSessionMessages(ChatSession session) async {
    setState(() {
      _currentSessionId = session.id;
      _messages.clear();
      _isTyping = true;
    });

    try {
      final msgs = await ApiService.getChatMessages(session.id);
      if (mounted) {
        setState(() {
          _messages.addAll(msgs);
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _initNewChat();
        });
      }
    }
  }

  /// Called externally when dashboard date range changes.
  void updateDateRange(DateTimeRange? range) {
    setState(() => _activeDateRange = range);
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isStreaming) return;

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _isTyping = true;
      _isStreaming = true;
    });
    _inputCtrl.clear();
    _scrollToBottom();

    String? startDate;
    String? endDate;
    if (_activeDateRange != null) {
      startDate = _activeDateRange!.start.toIso8601String();
      endDate = _activeDateRange!.end.toIso8601String();
    }

    // Add empty assistant message that will be filled by streaming
    final assistantMsg = ChatMessage(role: 'assistant', content: '');
    setState(() {
      _messages.add(assistantMsg);
      _isTyping = false; // Hide typing indicator, show streaming bubble
    });

    // Map history to send to backend
    final history = _messages
        .where((m) => m != assistantMsg && m.content.isNotEmpty)
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    // If no session, create one
    if (_currentSessionId == null) {
      try {
        final session = await ApiService.createChatSession(
            text.length > 30 ? '${text.substring(0, 30)}...' : text);
        _currentSessionId = session.id;
        _loadSessions(); // refresh list
      } catch (e) {
        debugPrint('Failed to create session: $e');
      }
    }

    try {
      final stream = ApiService.analyzeHealthTrendsStream(
        query: text,
        startDate: startDate,
        endDate: endDate,
        messages: history.isNotEmpty ? history : null,
        sessionId: _currentSessionId,
      );

      _streamSub = stream.listen(
        (token) {
          if (mounted) {
            setState(() {
              assistantMsg.content += token;
            });
            _scrollToBottom();
          }
        },
        onDone: () {
          if (mounted) {
            setState(() => _isStreaming = false);
            if (assistantMsg.content.isEmpty) {
              assistantMsg.content = 'No analysis was returned. Please try again.';
            }
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              assistantMsg.content = "I'm sorry, I encountered an error while analyzing your data. Please try again.\n\n*Error: $e*";
              _isStreaming = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          assistantMsg.content = "I'm sorry, I encountered an error. Please try again.\n\n*Error: $e*";
          _isStreaming = false;
        });
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

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // ─── Header ───────────────────────────────────────────
          _buildHeader(cs),
          // ─── Tab Bar ──────────────────────────────────────────
          TabBar(
            indicatorColor: cs.primary,
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurfaceVariant,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            tabs: const [
              Tab(text: 'Current Chat'),
              Tab(text: 'History'),
            ],
          ),
          // ─── Tab Views ────────────────────────────────────────
          Expanded(
            child: TabBarView(
              children: [
                _buildCurrentChatTab(cs),
                _buildHistoryTab(cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentChatTab(ColorScheme cs) {
    return Column(
      children: [
        if (_activeDateRange != null) _buildDateRangeChip(cs),
        Expanded(child: _buildMessageList(cs)),
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
                  child: Column(
                    crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Container(
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
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('HH:mm').format(msg.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
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
            onTap: _isStreaming ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: _isStreaming ? null : AppTheme.primaryGradient(context),
                color: _isStreaming ? cs.surfaceContainerHighest : null,
                borderRadius: BorderRadius.circular(23),
                boxShadow: _isStreaming
                    ? null
                    : [BoxShadow(color: cs.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Icon(
                _isStreaming ? Icons.hourglass_top_rounded : Icons.send_rounded,
                color: _isStreaming ? cs.onSurfaceVariant : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(ColorScheme cs) {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('No chat history yet', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        final isCurrent = session.id == _currentSessionId;
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCurrent ? cs.primary.withValues(alpha: 0.1) : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.chat_rounded,
              size: 20,
              color: isCurrent ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
          title: Text(
            session.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent ? cs.primary : cs.onSurface,
            ),
          ),
          subtitle: Text(
            DateFormat('MMM d, yyyy • h:mm a').format(session.createdAt),
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          onTap: () {
            DefaultTabController.of(context).animateTo(0);
            if (!isCurrent) {
              _loadSessionMessages(session);
            }
          },
        );
      },
    );
  }
}
