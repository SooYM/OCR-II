import 'dart:async';
import 'package:flutter/material.dart';
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

  /// Initializes a new chat session by fetching the patient's global health summary.
  ///
  /// Clears active message states and inserts the layman medical overview as the 
  /// initial assistant message.
  Future<void> _initNewChat() async {
    setState(() {
      _messages.clear();
      _currentSessionId = null;
      _isTyping = true;
    });

    try {
      final summary = await ApiService.fetchHealthSummary();
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: summary,
          ));
          _isTyping = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: "Hello! I'm your **AI Clinical Consultant**. I couldn't load your health summary at the moment, but feel free to ask me any questions about your reports!\n\n*Error: $e*",
          ));
          _isTyping = false;
        });
      }
    }
  }

  /// Queries the API for all historical chat sessions belonging to the user.
  ///
  /// Auto-restores the last active chat thread if it was updated within the last 4 hours.
  Future<void> _loadSessions() async {
    setState(() => _isLoadingHistory = true);
    try {
      final sessions = await ApiService.getChatSessions();
      if (mounted) {
        setState(() => _sessions = sessions);
        if (sessions.isNotEmpty && _currentSessionId == null && _messages.length <= 1) {
          // Only auto-load if the last session is less than 4 hours old
          final timeSinceLastChat = DateTime.now().difference(sessions.first.createdAt);
          if (timeSinceLastChat.inHours < 4) {
            _loadSessionMessages(sessions.first);
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load sessions: $e');
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  /// Retrieves and displays the message history of a specific [session] ID.
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

  Future<void> _deleteSession(ChatSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text('Delete "${session.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService.deleteChatSession(session.id);
      if (mounted) {
        setState(() {
          _sessions.removeWhere((s) => s.id == session.id);
          if (_currentSessionId == session.id) {
            _initNewChat();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  Future<void> _clearAllSessions() async {
    if (_sessions.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Chats'),
        content: Text('Delete all ${_sessions.length} conversations? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final sessionsToDelete = List<ChatSession>.from(_sessions);
    for (final session in sessionsToDelete) {
      try {
        await ApiService.deleteChatSession(session.id);
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _sessions.clear();
        _initNewChat();
      });
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

  /// Handles sending the user's message and streams the AI clinical response.
  ///
  /// Performs:
  /// 1. Updates UI with user query and sets loading state.
  /// 2. Resolves active dates filter parameters.
  /// 3. Lazily initializes a database chat session if none exists.
  /// 4. Subscribes to backend SSE stream (`analyzeHealthTrendsStream`) and appends 
  ///    text tokens in real-time.
  /// 5. Automatically triggers page down scroll sequences.
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
          // New chat button
          GestureDetector(
            onTap: () {
              setState(() {
                _initNewChat();
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_rounded, size: 18, color: cs.primary),
                  const SizedBox(width: 4),
                  Text('New', style: TextStyle(color: cs.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
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

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: msg.role == 'user' ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Assistant avatar
              if (msg.role != 'user') ...[
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
                  crossAxisAlignment: msg.role == 'user' ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: msg.role == 'user'
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(msg.role == 'user' ? 20 : 6),
                          bottomRight: Radius.circular(msg.role == 'user' ? 6 : 20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (msg.role == 'user' ? Theme.of(context).colorScheme.primary : Colors.black).withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: msg.role == 'user'
                          ? Text(msg.content, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5, fontWeight: FontWeight.w500))
                          : MarkdownBody(
                              data: msg.content,
                              styleSheet: MarkdownStyleSheet(
                                p: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, height: 1.6),
                                strong: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w700, height: 1.6),
                                em: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14, fontStyle: FontStyle.italic, height: 1.6),
                                h1: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 17, fontWeight: FontWeight.w800, height: 1.5),
                                h2: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w700, height: 1.5),
                                h3: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 15, fontWeight: FontWeight.w700, height: 1.5),
                                listBullet: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                                blockSpacing: 10,
                              ),
                            ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('HH:mm').format(msg.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // User avatar
              if (msg.role == 'user') ...[
                const SizedBox(width: 10),
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypingIndicator(ColorScheme cs) {
    return Padding(
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chat_bubble_outline_rounded, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 20),
            Text('No conversations yet', style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Start a new chat to see it here', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Clear all button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text(
                '${_sessions.length} conversation${_sessions.length == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _clearAllSessions,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_sweep_rounded, size: 16, color: cs.error),
                      const SizedBox(width: 4),
                      Text('Clear All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.error)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _sessions.length,
            itemBuilder: (context, index) {
              final session = _sessions[index];
              final isCurrent = session.id == _currentSessionId;
              final now = DateTime.now();
              final diff = now.difference(session.createdAt);
              String timeLabel;
              if (diff.inMinutes < 1) {
                timeLabel = 'Just now';
              } else if (diff.inHours < 1) {
                timeLabel = '${diff.inMinutes}m ago';
              } else if (diff.inDays < 1) {
                timeLabel = '${diff.inHours}h ago';
              } else if (diff.inDays < 7) {
                timeLabel = '${diff.inDays}d ago';
              } else {
                timeLabel = DateFormat('MMM d').format(session.createdAt);
              }

              return Dismissible(
                key: Key(session.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: cs.error,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
                ),
                confirmDismiss: (_) async {
                  await _deleteSession(session);
                  return false; // We handle removal in _deleteSession
                },
                child: GestureDetector(
                  onTap: () {
                    DefaultTabController.of(context).animateTo(0);
                    if (!isCurrent) _loadSessionMessages(session);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? cs.primary.withValues(alpha: 0.08)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: isCurrent ? Border.all(color: cs.primary.withValues(alpha: 0.3), width: 1.5) : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isCurrent ? cs.primary.withValues(alpha: 0.15) : cs.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isCurrent ? Icons.chat_rounded : Icons.chat_bubble_outline_rounded,
                            size: 18,
                            color: isCurrent ? cs.primary : cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                                  color: isCurrent ? cs.primary : cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                timeLabel,
                                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _deleteSession(session),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.delete_outline_rounded, size: 18, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
