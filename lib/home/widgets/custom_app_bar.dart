part of '../home_page.dart';

class _CustomAppBar extends StatelessWidget {
  final VoidCallback onMenuPressed;
  final VoidCallback onMyPagePressed;
  final TextEditingController searchController;

  const _CustomAppBar({
    required this.onMenuPressed,
    required this.onMyPagePressed,
    required this.searchController,
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
              icon: const Icon(Icons.menu, size: 28, color: Colors.black),
              splashRadius: 22,
              padding: EdgeInsets.zero,
            ),
            Row(
              children: [
                _SearchBar(controller: searchController),
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

  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black, width: 1.4)),
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
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const Icon(Icons.search, size: 20),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 1.4),
        ),
        child: const Icon(Icons.person_outline, size: 20, color: Colors.black),
      ),
    );
  }
}
