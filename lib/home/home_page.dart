import 'package:flutter/material.dart';

part 'widgets/custom_app_bar.dart';
part 'widgets/my_page_card.dart';
part 'widgets/side_menu.dart';
part 'widgets/card_switcher.dart';
part 'widgets/card_base.dart';
part 'pages/simple_page.dart';
part 'pages/create_league_page.dart';
part 'pages/login_page.dart';

final GlobalKey<LeagueItHomePageState> homeKey =
    GlobalKey<LeagueItHomePageState>();

class LeagueItHomePage extends StatefulWidget {
  const LeagueItHomePage({super.key});

  @override
  State<LeagueItHomePage> createState() => LeagueItHomePageState();
}

class LeagueItHomePageState extends State<LeagueItHomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late final TextEditingController _searchController;

  bool _isMenuOpen = false;
  bool _isMyPageOpen = false;
  bool _isLoggedIn = false;

  bool get isLoggedIn => _isLoggedIn;

  void updateLogin(bool value) {
    if (_isLoggedIn == value) return;
    setState(() => _isLoggedIn = value);
  }

  void closePanels() {
    setState(() {
      _isMenuOpen = false;
      _isMyPageOpen = false;
    });
  }

  void resetHomeUI() {
    setState(() {
      _isMenuOpen = false;
      _isMyPageOpen = false;
    });
    _searchController.clear();
  }

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      _isMyPageOpen = false;
    });
  }

  void _toggleMyPage() {
    setState(() => _isMyPageOpen = !_isMyPageOpen);
  }

  @override
  Widget build(BuildContext context) {
    final double sidebarWidth = MediaQuery.of(context).size.width * 0.42;

    return Stack(
      children: [
        ////////////////////////////////////////////////////////////////
        /// MAIN PAGE
        ////////////////////////////////////////////////////////////////
        Scaffold(
          backgroundColor: Colors.white,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: _CustomAppBar(
              onMenuPressed: _toggleMenu,
              onMyPagePressed: _toggleMyPage,
              searchController: _searchController,
            ),
          ),
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 140),
                    Expanded(
                      child: Center(
                        child: CardSwitcher(isLoggedIn: _isLoggedIn),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 120,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Center(
                    child: Text(
                      'LeagueIt',
                      style: TextStyle(
                        fontSize: 45,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        ////////////////////////////////////////////////////////////////
        /// DIM BACKGROUND (MENU)
        ////////////////////////////////////////////////////////////////
        if (_isMenuOpen)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: 0.45,
            child: GestureDetector(
              onTap: _toggleMenu,
              child: Container(color: Colors.black),
            ),
          ),

        ////////////////////////////////////////////////////////////////
        /// SIDE MENU
        ////////////////////////////////////////////////////////////////
        AnimatedPositioned(
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutCubic,
          left: _isMenuOpen ? 0 : -sidebarWidth,
          top: 0,
          bottom: 0,
          child: SideMenu(width: sidebarWidth),
        ),

        ////////////////////////////////////////////////////////////////
        /// DIM BACKGROUND (MY PAGE)
        ////////////////////////////////////////////////////////////////
        if (_isMyPageOpen)
          GestureDetector(
            onTap: _toggleMyPage,
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),

        ////////////////////////////////////////////////////////////////
        /// MY PAGE POPUP
        ////////////////////////////////////////////////////////////////
        AnimatedPositioned(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          top: _isMyPageOpen ? 100 : 20,
          right: _isMyPageOpen ? 24 : 12,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 420),
            scale: _isMyPageOpen ? 1.0 : 0.2,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isMyPageOpen ? 1 : 0,
              child: MyPageCard(
                isLoggedIn: _isLoggedIn,
                onLogin: () {
                  updateLogin(true);
                  _toggleMyPage();
                },
                onLogout: () {
                  updateLogin(false);
                  _toggleMyPage();
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
