part of '../home_page.dart';

class SimplePage extends StatefulWidget {
  final String title;

  const SimplePage({super.key, required this.title});

  @override
  State<SimplePage> createState() => _SimplePageState();
}

class _SimplePageState extends State<SimplePage> {
  final GlobalKey<_LeagueItSubAppBarState> _appBarKey =
      GlobalKey<_LeagueItSubAppBarState>();
  bool _isMyPageOpen = false;

  void _toggleMyPage() {
    setState(() => _isMyPageOpen = !_isMyPageOpen);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        _appBarKey.currentState?.closeSearch();
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: LeagueItSubAppBar(
              key: _appBarKey,
              onMyPageTap: _toggleMyPage,
              showSearch: false,
            ),
            body: Center(
              child: Text(widget.title, style: const TextStyle(fontSize: 24)),
            ),
          ),

          if (_isMyPageOpen)
            GestureDetector(
              onTap: _toggleMyPage,
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),

          _MyPagePopupOverlay(
            isOpen: _isMyPageOpen,
            onDismiss: _toggleMyPage,
            isLoggedIn: homeKey.currentState?.isLoggedIn ?? false,
            onLogin: () {
              homeKey.currentState?.updateLogin(true);
              Navigator.pop(context);
            },
            onLogout: () {
              homeKey.currentState?.updateLogin(false);
              homeKey.currentState?.closePanels();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class LeagueItSubAppBar extends StatefulWidget implements PreferredSizeWidget {
  final VoidCallback onMyPageTap;
  final VoidCallback? onHelpTap;
  final void Function(BuildContext anchorContext)? onNotificationTap;
  final int notificationCount;
  final String? title;
  final bool showSearch;
  final Widget Function(BuildContext context, Widget child)? wrapHelpButton;

  const LeagueItSubAppBar({
    super.key,
    required this.onMyPageTap,
    this.onHelpTap,
    this.onNotificationTap,
    this.notificationCount = 0,
    this.title,
    this.showSearch = true,
    this.wrapHelpButton,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  State<LeagueItSubAppBar> createState() => _LeagueItSubAppBarState();
}

class _LeagueItSubAppBarState extends State<LeagueItSubAppBar> {
  bool _isSearching = false;

  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus && _isSearching) {
        _controller.clear();
        setState(() => _isSearching = false);
      }
    });
  }

  void _closeSearch() {
    if (_isSearching) {
      _controller.clear();
      _searchFocus.unfocus();
      setState(() => _isSearching = false);
    }
  }

  void closeSearch() {
    _closeSearch();
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    final iconColor = palette.ink;
    final borderColor = palette.cardBorder;
    Widget helpButton = GestureDetector(
      onTap: widget.onHelpTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor),
        ),
        child: Icon(Icons.help_outline_rounded, size: 18, color: iconColor),
      ),
    );
    if (widget.wrapHelpButton != null) {
      helpButton = widget.wrapHelpButton!(context, helpButton);
    }
    return AppBar(
      automaticallyImplyLeading: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      centerTitle: true,

      title: GestureDetector(
        onTap: () {
          homeKey.currentState?.resetHomeUI();
          Navigator.popUntil(context, (route) => route.isFirst);
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: _isSearching ? 0 : 1,
          child: Text(
            widget.title ?? "LeagueIt",
            style: TextStyle(
              color: iconColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),

      actions: [
        if (widget.showSearch)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => _isSearching = true);
              Future.delayed(Duration.zero, () {
                _searchFocus.requestFocus();
              });
            },
            child: SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(child: Icon(Icons.search, color: iconColor)),
                  if (_isSearching)
                    Positioned(
                      bottom: -2,
                      right: 0,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.45,
                        height: 36,
                        child: TextField(
                          focusNode: _searchFocus,
                          controller: _controller,
                          autofocus: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.only(bottom: 8),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 6,
                    right: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                      height: 1.4,
                      width: _isSearching
                          ? MediaQuery.of(context).size.width * 0.45
                          : 0,
                      decoration: BoxDecoration(color: iconColor),
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (widget.showSearch) const SizedBox(width: 12),

        if (widget.onHelpTap != null) helpButton,

        if (widget.onNotificationTap != null) ...[
          Builder(
            builder: (anchorContext) {
              return GestureDetector(
                onTap: () => widget.onNotificationTap?.call(anchorContext),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 32,
                  height: 32,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor),
                        ),
                        child: Icon(
                          Icons.notifications_none,
                          size: 18,
                          color: iconColor,
                        ),
                      ),
                      if (widget.notificationCount > 0)
                        Positioned(
                          top: -1,
                          right: -1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: palette.pageBackground,
                                width: 1.2,
                              ),
                            ),
                            width: 10,
                            height: 10,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],

        /// 👤 MY PAGE
        GestureDetector(
          onTap: widget.onMyPageTap,
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: Icon(Icons.person_outline, size: 18, color: iconColor),
          ),
        ),
      ],
    );
  }
}
