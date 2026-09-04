import 'package:flutter/material.dart';

class CommandPaletteItem {
  const CommandPaletteItem({
    required this.title,
    required this.category,
    required this.action,
    this.shortcut,
    this.icon,
  });

  final String title;
  final String category;
  final VoidCallback action;
  final String? shortcut;
  final IconData? icon;
}

class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key, required this.items});

  final List<CommandPaletteItem> items;

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  List<CommandPaletteItem> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  void _filter(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredItems = widget.items;
      } else {
        final q = query.toLowerCase();
        _filteredItems = widget.items
            .where(
              (item) =>
                  item.title.toLowerCase().contains(q) ||
                  item.category.toLowerCase().contains(q),
            )
            .toList();
      }
      _selectedIndex = 0;
    });
  }

  void _execute(CommandPaletteItem item) {
    Navigator.pop(context);
    item.action();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 80),
      child: Container(
        width: 580,
        decoration: BoxDecoration(
          color: const Color(0xF5181A20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF383B42)),
          boxShadow: const [
            BoxShadow(color: Colors.black87, blurRadius: 24, spreadRadius: 4),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Nhập lệnh hoặc tìm kiếm tính năng…',
                  prefixIcon: Icon(Icons.search, size: 20),
                  border: InputBorder.none,
                ),
                onChanged: _filter,
                onSubmitted: (_) {
                  if (_filteredItems.isNotEmpty) {
                    _execute(
                      _filteredItems[_selectedIndex.clamp(
                        0,
                        _filteredItems.length - 1,
                      )],
                    );
                  }
                },
              ),
            ),
            const Divider(height: 1),

            // Results List
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: _filteredItems.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Không tìm thấy lệnh phù hợp',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final isSelected = index == _selectedIndex;

                        return InkWell(
                          onTap: () => _execute(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            color: isSelected ? const Color(0x33FFB300) : null,
                            child: Row(
                              children: [
                                if (item.icon != null) ...[
                                  Icon(
                                    item.icon,
                                    size: 16,
                                    color: const Color(0xFFFFB300),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        item.category,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (item.shortcut != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white10,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.shortcut!,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
