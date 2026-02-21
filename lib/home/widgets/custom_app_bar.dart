part of '../home_page.dart';

class _CustomAppBar extends StatelessWidget {
  final VoidCallback onMenuPressed;
  final VoidCallback onMyPagePressed;
  final TextEditingController searchController;
  final ValueChanged<String>? onSearch;
  final ValueChanged<String>? onChanged;

  const _CustomAppBar({
    required this.onMenuPressed,
    required this.onMyPagePressed,
    required this.searchController,
    this.onSearch,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: onMenuPressed,
              icon: Icon(
                Icons.menu,
                size: 28,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              splashRadius: 22,
              padding: EdgeInsets.zero,
            ),
            Row(
              children: [
                _SearchBar(
                  controller: searchController,
                  onSearch: onSearch,
                  onChanged: onChanged,
                ),
                const SizedBox(width: 12),
                _MyPageButton(onTap: onMyPagePressed),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onSearch;
  final ValueChanged<String>? onChanged;

  const _SearchBar({required this.controller, this.onSearch, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final Color stroke = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: 190,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: stroke, width: 1.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(bottom: 8),
              ),
              style: TextStyle(fontSize: 14, color: stroke),
              onChanged: (v) => onChanged?.call(v.trim()),
              onSubmitted: (v) => onSearch?.call(v.trim()),
            ),
          ),
          GestureDetector(
            onTap: () => onSearch?.call(controller.text.trim()),
            child: Icon(Icons.search, size: 20, color: stroke),
          ),
        ],
      ),
    );
  }
}

class _MyPageButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MyPageButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color stroke = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: stroke, width: 1.4),
        ),
        child: Icon(Icons.person_outline, size: 20, color: stroke),
      ),
    );
  }
}
