import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/ArtificialIntelligence/ArtificialIntelligenceInstructions.dart';
import 'package:gasan_port_tracker/Dialogs/AITermsPrivacyDialog.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleGeminiAI {
  final String apiKey;
  late final GenerativeModel _model;

  GoogleGeminiAI({
    required this.apiKey,
    String? systemInstruction,
  }) {
    _model = GenerativeModel(
      model: 'gemini-3.1-flash-lite-preview',
      apiKey: apiKey,
      systemInstruction: systemInstruction != null
          ? Content.system(systemInstruction)
          : null,
    );
  }

  Future<String?> askQuestion(String question) async {
    try {
      final content = [Content.text(question)];
      final response = await _model.generateContent(content);
      return response.text;
    } catch (e) {
      debugPrint("Gemini AI Error: $e");
      return "Sorry, I encountered an error connecting to the command center network. Please try again.";
    }
  }
}

class AgaAppAssistant extends StatefulWidget {
  const AgaAppAssistant({super.key});

  @override
  State<AgaAppAssistant> createState() => _AgaAppAssistantState();
}

class _AgaAppAssistantState extends State<AgaAppAssistant> {
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color borderColor = const Color(0xFFE2E8F0);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);

  late final GoogleGeminiAI _aiAssistant;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  SharedPreferences? _preferences;

  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _initializeAI();

      await Future.delayed(const Duration(milliseconds: 700));
      if(mounted) {
        AITermsPrivacyDialog.show(context, (){
          Navigator.of(context).pop();
        });
      }
    });
  }

  Future<void> _initializeAI() async {
    _preferences = await SharedPreferences.getInstance();

    String userName = _preferences?.getString("user_name") ?? "Citizen";
    String userId = _preferences?.getString("user_id") ?? "Unknown ID";
    String userEmail = _preferences?.getString("user_account") ?? "Unknown Email";
    String userAssignedPort = _preferences?.getString("assigned_port") ?? "None";
    String userAssignedPortId = _preferences?.getString("assigned_port_id") ?? "None";
    String userAssignedMunicipalZipCode = _preferences?.getString("municipality_zip_code") ?? "None";

    List<String> accessList = _preferences?.getStringList("user_access") ?? ["Citizen"];
    String userAccessStr = accessList.join(", ");

    String systemInstructions = """
    ${ArtificialIntelligenceInstructions.geminiInstructions}
    
    User Context (Use this data to personalize your responses):
    - Name: $userName
    - User ID: $userId
    - Email: $userEmail
    - Roles/Access Level: $userAccessStr
    - Assigned Port: $userAssignedPort (Port ID: $userAssignedPortId)
    - Municipality Zip Code: $userAssignedMunicipalZipCode
    """;

    // Initialize the AI with the dynamic instructions
    _aiAssistant = GoogleGeminiAI(
      apiKey: 'AIzaSyCgc14XAeZLPGRPG2Pd6J0t4hB_yDlaWMQ',
      systemInstruction: systemInstructions,
    );

    if (mounted) {
      setState(() {
        _isInitializing = false;
        _messages.add({
          'text': "Hello, $userName! I am AGA, your Command Center AI Assistant. How can I help you today?\n"
              "Please do not send any personal information such as password, bank pins etc. You are using this AI because you agreed to the terms and privacy policy of this AI.",
          'isUser': false,
          'timestamp': DateTime.now(),
        });
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- LOGIC ---

  Future<void> _sendMessage() async {
    final String text = _messageController.text.trim();
    if (text.isEmpty || _isInitializing) return;

    // 1. Add User Message
    setState(() {
      _messages.add({
        'text': text,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    // 2. Fetch AI Response
    final String? response = await _aiAssistant.askQuestion(text);

    // 3. Add AI Message
    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add({
          'text': response ?? "Error processing request.",
          'isUser': false,
          'timestamp': DateTime.now(),
        });
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("AGA Assistant", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
            Text("Command Center AI", style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(Icons.memory_rounded, color: primaryDark),
          )
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Chat List
              Expanded(
                child: _isInitializing
                    ? Center(child: CircularProgressIndicator(color: primaryDark))
                    : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isTyping) {
                      return _buildTypingIndicator();
                    }
                    final message = _messages[index];
                    return _buildChatBubble(message['text'], message['isUser']);
                  },
                ),
              ),

              // Input Field Area
              _buildMessageInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: primaryDark.withValues(alpha: 0.1),
              radius: 16,
              child: Icon(Icons.smart_toy_rounded, size: 18, color: primaryDark),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: isUser ? primaryDark : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  border: isUser ? null : Border.all(color: borderColor),
                  boxShadow: [
                    if (!isUser)
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
                  ]
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),

          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
              radius: 16,
              child: const Icon(Icons.person_rounded, size: 18, color: Color(0xFF10B981)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: primaryDark.withValues(alpha: 0.1),
            radius: 16,
            child: Icon(Icons.smart_toy_rounded, size: 18, color: primaryDark),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: primaryDark.withValues(alpha: 0.5)),
                ),
                const SizedBox(width: 8),
                Text("AGA is typing...", style: TextStyle(fontSize: 12, color: textSecondary, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 14, color: textPrimary),
                enabled: !_isInitializing,
                maxLength: 500, // <--- ADDED CHARACTER LIMIT HERE
                decoration: InputDecoration(
                  counterText: "", // <--- HIDES DEFAULT "0/500" TO KEEP UI CLEAN
                  hintText: _isInitializing ? "Connecting to AGA..." : "Ask AGA a question...",
                  hintStyle: TextStyle(color: textSecondary),
                  filled: true,
                  fillColor: bgColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: primaryDark, width: 1)),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: (_isTyping || _isInitializing) ? null : _sendMessage,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_isTyping || _isInitializing) ? Colors.grey.shade300 : primaryDark,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
