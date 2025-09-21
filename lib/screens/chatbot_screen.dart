import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'search_results_screen.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final _functions = FirebaseFunctions.instance;
  bool _isSending = false;

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isSending = true;
    });

    _controller.clear();

    try {
      final result = await _functions.httpsCallable('chatWithGenAI').call({
        'text': text,
      });
      final data = result.data as Map<String, dynamic>? ?? {};
      final reply = (data['reply'] ?? "I didn’t understand that.").toString();

      // If backend returned products, navigate to SearchResultsScreen with them
      if (data['products'] != null && (data['products'] as List).isNotEmpty) {
        final List<dynamic> products = data['products'];
        // convert to list of maps the SearchResultsScreen expects
        final searchResults = products
            .map(
              (p) => {
                'name': p['name'] ?? 'Unnamed',
                'price': p['price'],
                'imageUrl': p['imageUrl'],
                'description': p['description'] ?? '',
              },
            )
            .toList();

        // show a bot message then navigate
        setState(() {
          _messages.add({'sender': 'bot', 'text': reply});
        });

        // navigate after a short delay so user sees the reply
        Future.delayed(const Duration(milliseconds: 300), () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SearchResultsScreen(
                query: text,
                searchResults: searchResults,
              ),
            ),
          );
        });
      } else {
        setState(() {
          _messages.add({'sender': 'bot', 'text': reply});
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'sender': 'bot', 'text': "Error: $e"});
      });
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Assistant")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final msg = _messages[i];
                final isUser = msg['sender'] == 'user';
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isSending) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText:
                          "Ask me anything (try: 'Show me brass lamps under 1000')",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
