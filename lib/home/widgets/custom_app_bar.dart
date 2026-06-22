part of '../home_page.dart';

class _CustomAppBar extends StatelessWidget {
  final VoidCallback onMenuPressed;
  final VoidCallback onHelpPressed;
  final VoidCallback onMyPagePressed;
  final TextEditingController searchController;
  final ValueChanged<String>? onSearch;
  final ValueChanged<String>? onChanged;
  final bool showSearch;
  final Widget Function(BuildContext context, Widget child)? wrapMenuButton;
  final Widget Function(BuildContext context, Widget child)? wrapMyPageButton;

  const _CustomAppBar({
    required this.onMenuPressed,
    required this.onHelpPressed,
    required this.onMyPagePressed,
    required this.searchController,
    this.onSearch,
    this.onChanged,
    this.showSearch = true,
    this.wrapMenuButton,
    this.wrapMyPageButton,
  });

  @override
  Widget build(BuildContext context) {
    Widget menuButton = IconButton(
      onPressed: onMenuPressed,
      icon: Icon(
        Icons.menu,
        size: 28,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      splashRadius: 22,
      padding: EdgeInsets.zero,
    );
    if (wrapMenuButton != null) {
      menuButton = wrapMenuButton!(context, menuButton);
    }

    Widget helpButton = _RoundIconButton(
      icon: Icons.help_outline_rounded,
      onTap: onHelpPressed,
    );

    Widget myPageButton = _MyPageButton(onTap: onMyPagePressed);
    if (wrapMyPageButton != null) {
      myPageButton = wrapMyPageButton!(context, myPageButton);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            menuButton,
            Row(
              children: [
                if (showSearch)
                  _SearchBar(
                    controller: searchController,
                    onSearch: onSearch,
                    onChanged: onChanged,
                  )
                else
                  helpButton,
                const SizedBox(width: 12),
                myPageButton,
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
              cursorColor: stroke,
              enableSuggestions: false,
              autocorrect: false,
              enableIMEPersonalizedLearning: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
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
    return _RoundIconButton(icon: Icons.person_outline, onTap: onTap);
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

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
        child: Icon(icon, size: 20, color: stroke),
      ),
    );
  }
}
