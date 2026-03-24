import 'package:flutter/material.dart';
import '../../models/request_message.dart';
import '../../models/user.dart' as AppUserModel;
import '../../services/supabase_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatWidget extends StatefulWidget {
  final String requestId;
  final String requestTitle;
  final AppUserModel.User currentUser;
  final double? height;

  const ChatWidget({
    super.key,
    required this.requestId,
    required this.requestTitle,
    required this.currentUser,
    this.height,
  });

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<RequestMessage> _messages = [];
  bool _isLoading = true;
  RealtimeChannel? _subscription;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupSubscription();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupSubscription() {
    _subscription = SupabaseService.subscribeToRequestMessages(widget.requestId, (newMessage) {
      if (mounted) {
        setState(() {
          if (!_messages.any((m) => m.id == newMessage.id)) {
            _messages.add(newMessage);
            _scrollToBottom();
          }
        });
      }
    });
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await SupabaseService.getRequestMessages(widget.requestId);
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMessage = RequestMessage(
      id: tempId,
      requestId: widget.requestId,
      senderId: widget.currentUser.id,
      senderName: '${widget.currentUser.firstName} ${widget.currentUser.lastName}',
      message: text,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(tempMessage);
    });
    _scrollToBottom();

    try {
      await SupabaseService.sendRequestMessage(
        requestId: widget.requestId,
        senderId: widget.currentUser.id,
        message: text,
      );
    } catch (e) {
      setState(() {
        _messages.removeWhere((m) => m.id == tempId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    final tempId = 'temp_img_${DateTime.now().millisecondsSinceEpoch}';
    final tempMessage = RequestMessage(
      id: tempId,
      requestId: widget.requestId,
      senderId: widget.currentUser.id,
      senderName: '${widget.currentUser.firstName} ${widget.currentUser.lastName}',
      message: 'Загрузка фото...',
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(tempMessage);
    });
    _scrollToBottom();

    try {
      final bytes = await image.readAsBytes();
      final url = await SupabaseService.uploadRequestAttachment(
        widget.requestId,
        bytes,
        image.name,
        image.mimeType ?? 'image/jpeg',
      );
      
      await SupabaseService.sendRequestMessage(
        requestId: widget.requestId,
        senderId: widget.currentUser.id,
        message: 'Прикреплено фото',
        attachments: [url],
      );
      
      setState(() {
        _messages.removeWhere((m) => m.id == tempId);
      });
    } catch (e) {
      setState(() {
        _messages.removeWhere((m) => m.id == tempId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки фото: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      constraints: widget.height == null ? const BoxConstraints.expand() : null,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: widget.height != null ? BorderRadius.circular(16) : null,
        boxShadow: widget.height != null ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          reverse: true, // исправляет работу с клавиатурой
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[_messages.length - 1 - index];
                            final isMe = message.senderId == widget.currentUser.id;
                            return _buildMessageBubble(message, isMe);
                          },
                        ),
            ),
            _buildInputSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text(
            'Чат по заявке пуст',
            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(RequestMessage message, bool isMe) {
    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (!isMe)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              message.senderName ?? 'Пользователь',
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            ),
          ),
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.message != null && message.message!.isNotEmpty)
                Text(
                  message.message!,
                  style: TextStyle(
                    color: isMe ? Colors.white : const Color(0xFF1E293B),
                    fontSize: 14,
                  ),
                ),
              if (message.attachments != null && message.attachments!.isNotEmpty) ...[
                if (message.message != null && message.message!.isNotEmpty) const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    message.attachments!.first,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                message.formattedTime,
                style: TextStyle(
                  color: isMe ? Colors.white70 : const Color(0xFF94A3B8),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF2563EB), size: 22),
            onPressed: _pickImage,
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Написать...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                maxLines: 4,
                minLines: 1,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Color(0xFF2563EB), size: 22),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  final String requestId;
  final String? requestTitle;  // теперь необязательный — можем загрузить сами
  final AppUserModel.User currentUser;

  const ChatPage({
    super.key,
    required this.requestId,
    this.requestTitle,
    required this.currentUser,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  String? _loadedTitle;
  bool _loadingTitle = false;

  @override
  void initState() {
    super.initState();
    if (widget.requestTitle == null || widget.requestTitle!.isEmpty) {
      _loadTitle();
    }
  }

  Future<void> _loadTitle() async {
    setState(() => _loadingTitle = true);
    try {
      final req = await SupabaseService.getRequestById(widget.requestId);
      if (mounted && req != null) {
        setState(() {
          _loadedTitle = req.title;
          _loadingTitle = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTitle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.requestTitle ?? _loadedTitle;
    final shortId = widget.requestId.length >= 8
        ? widget.requestId.substring(0, 8).toUpperCase()
        : widget.requestId.toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Обсуждение заявки',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Text(
              _loadingTitle ? 'Загрузка...' : (title ?? '#$shortId'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0.5,
        centerTitle: true,
      ),
      body: ChatWidget(
        requestId: widget.requestId,
        requestTitle: title ?? '#$shortId',
        currentUser: widget.currentUser,
      ),
    );
  }
}
