import 'package:flutter/material.dart';

/// Chip editor for comma-separated tags stored by the existing document model.
class TagEditor extends StatefulWidget {
  final String initialTags;
  final ValueChanged<String> onChanged;

  const TagEditor({super.key, required this.initialTags, required this.onChanged});

  @override
  State<TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<TagEditor> {
  late final TextEditingController _input;
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    _tags = _parse(widget.initialTags);
    _input = TextEditingController();
  }

  List<String> _parse(String value) {
    final seen = <String>{};
    return value.split(',').map((tag) => tag.trim()).where((tag) {
      return tag.isNotEmpty && seen.add(tag.toLowerCase());
    }).toList();
  }

  void _commitInput() {
    final additions = _parse(_input.text);
    if (additions.isEmpty) return;
    final seen = _tags.map((tag) => tag.toLowerCase()).toSet();
    setState(() => _tags.addAll(additions.where((tag) => seen.add(tag.toLowerCase()))));
    _input.clear();
    widget.onChanged(_tags.join(', '));
  }

  void _remove(String tag) {
    setState(() => _tags.remove(tag));
    widget.onChanged(_tags.join(', '));
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Thẻ từ khóa (Tags)',
          prefixIcon: Icon(Icons.tag),
          border: OutlineInputBorder(),
          helperText: 'Nhập một hoặc nhiều tag, phân cách bằng dấu phẩy',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _tags.map((tag) => InputChip(
                    label: Text(tag),
                    onDeleted: () => _remove(tag),
                  )).toList(),
                ),
              ),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'Ví dụ: Flutter, Ôn thi',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (value) {
                    // Keep an in-progress tag in the form value so Save works
                    // even when the user does not press Enter or the plus button.
                    final combined = [..._tags, ..._parse(value)];
                    widget.onChanged(combined.join(', '));
                  },
                  onSubmitted: (_) => _commitInput(),
                ),
              ),
              IconButton(
                tooltip: 'Thêm tag',
                onPressed: _commitInput,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ]),
          ],
        ),
      );
}
