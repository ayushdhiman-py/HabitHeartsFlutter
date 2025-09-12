import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EmojiSelector extends StatefulWidget {
  final Function(String) onEmojiSelected;
  final String? selectedEmoji;

  const EmojiSelector({
    super.key,
    required this.onEmojiSelected,
    this.selectedEmoji,
  });

  @override
  State<EmojiSelector> createState() => _EmojiSelectorState();
}

class _EmojiSelectorState extends State<EmojiSelector> {
  // Common emojis for habits and tasks
  final List<String> _emojis = [
    '😊', '💪', '🧠', '⏰', '✅', '📅', '🎯', '⭐',
    '🔥', '💡', '❤️', '👍', '👏', '🙏', '🎉', '🏆',
    '📚', '✍️', '🗣️', '🚶', '🏃', '🚴', '🧘', '🎨',
    '🎵', '🎮', '📱', '💻', '📖', '🌿', '🌞', '🌙',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _emojis.length,
        itemBuilder: (context, index) {
          String emoji = _emojis[index];
          bool isSelected = emoji == widget.selectedEmoji;
          
          return GestureDetector(
            onTap: () {
              widget.onEmojiSelected(emoji);
            },
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? AppColors.electricBlue.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.electricBlue : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}