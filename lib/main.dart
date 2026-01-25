import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}
final TextEditingController searchController = TextEditingController();
final GlobalKey<_LeagueItHomePageState> homeKey =
GlobalKey<_LeagueItHomePageState>();


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LeagueItHomePage(key: homeKey),
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
/// HOME
////////////////////////////////////////////////////////////////////////////////

class LeagueItHomePage extends StatefulWidget {
  const LeagueItHomePage({super.key});

  @override
  State<LeagueItHomePage> createState() => _LeagueItHomePageState();
}

class _LeagueItHomePageState extends State<LeagueItHomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _isMenuOpen = false;
  bool _isMyPageOpen = false;
  bool _isLoggedIn = false;

  void resetHomeUI() {
    setState(() {
      _isMenuOpen = false;
      _isMyPageOpen = false;
    });
    searchController.clear();
  }

  @override
  void initState() {
    super.initState();

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
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      _isMyPageOpen = false; // ⭐ 이 줄이 핵심
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
            ),
          ),
          body: Stack(
            children: [
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: Column(
                  children: [
                    const SizedBox(height: 140),
                    Expanded(
                        child: Center(
                           child: CardSwitcher(
                          isLoggedIn: _isLoggedIn,
                        ))),
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
                isLoggedIn: _isLoggedIn, // 🔁 MODIFIED
                onLogin: () {
                  setState(() => _isLoggedIn = true);   _toggleMyPage(); // 임시
                },
                onLogout: () {
                  setState(() => _isLoggedIn = false);
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

////////////////////////////////////////////////////////////////////////////////
/// APP BAR
////////////////////////////////////////////////////////////////////////////////

class _CustomAppBar extends StatelessWidget {
  final VoidCallback onMenuPressed;
  final VoidCallback onMyPagePressed;

  const _CustomAppBar({
    required this.onMenuPressed,
    required this.onMyPagePressed,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding:
        const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
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
                const _SearchBar(),
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

////////////////////////////////////////////////////////////////////////////////
/// SEARCH BAR & MY PAGE BUTTON
////////////////////////////////////////////////////////////////////////////////

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.black, width: 1.4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(bottom: 8),
              ),
              style: TextStyle(fontSize: 14),
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
        child:
        const Icon(Icons.person_outline, size: 20, color: Colors.black),
      ),
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
/// MY PAGE CARD
////////////////////////////////////////////////////////////////////////////////

class MyPageCard extends StatelessWidget {
  final bool isLoggedIn;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  const MyPageCard({
    super.key,
    required this.isLoggedIn,
    required this.onLogin,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "My Page",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),

            if (!isLoggedIn) ...[
              _MyPageItem(
                "Log in",
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LoginPage()),
                  );
                  if (result == true) {
                    onLogin();
                  }
                },
              ),
              _MyPageItem(
                "Create account",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SimplePage(title: "Create Account"),
                    ),
                  );
                },
              ),
              ] else ...[
              _MyPageItem(
                "Profile",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SimplePage(title: "Profile"),
                    ),
                  );
                },
              ),
              _MyPageItem(
                "My League",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SimplePage(title: "My League"),
                    ),
                  );
                },
              ),
              _MyPageItem(
                "Password",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SimplePage(title: "Password"),
                    ),
                  );
                },
              ),
              const Divider(height: 22),
              _MyPageItem(
                "Log out",
                isDanger: true,
                onTap: onLogout,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MyPageItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final bool isDanger;

  const _MyPageItem(
      this.title, {
        required this.onTap,
        this.isDanger = false,
      });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            color: isDanger ? Colors.red : Colors.black87,
            fontWeight:
            isDanger ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
/// SIDE MENU
////////////////////////////////////////////////////////////////////////////////

class SideMenu extends StatelessWidget {
  final double width;
  const SideMenu({super.key, required this.width});

  @override
  Widget build(BuildContext context) {
    return Material( // ⭐ 중요: InkWell 때문에 필요
      color: Colors.transparent,
      child: Container(
        width: width,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(26),
            bottomRight: Radius.circular(26),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 12,
              offset: Offset(6, 0),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/leagueit_logo.png',
                    width: 26,
                    height: 26,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "LeagueIt",
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 30),

            _MenuItem(
              "About Us",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SimplePage(title: "About Us"),
                  ),
                );
              },
            ),
            const SizedBox(height: 22),

            _MenuItem(
              "PlayBook",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SimplePage(title: "PlayBook"),
                  ),
                );
              },
            ),
            const SizedBox(height: 22),

            _MenuItem(
              "Privacy Policy",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                    const SimplePage(title: "Privacy Policy"),
                  ),
                );
              },
            ),
            const SizedBox(height: 22),

            _MenuItem(
              "FAQs",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SimplePage(title: "FAQs"),
                  ),
                );
              },
            ),
            const SizedBox(height: 22),

            _MenuItem(
              "Settings",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SimplePage(title: "Settings"),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _MenuItem(
      this.title, {
        required this.onTap,
      });

  @override
  Widget build(BuildContext context) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    final double textWidth = textPainter.width;

    return InkWell(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: textWidth,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF00BC13).withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              title,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
////////////////////////////////////////////////////////////////////////////////
/// LOGIN PAGE
////////////////////////////////////////////////////////////////////////////////

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Log in")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const TextField(
              decoration: InputDecoration(
                  labelText: "Email", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const TextField(
              obscureText: true,
              decoration: InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                child: const Text("Log in"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
/// CARD SWITCHER
////////////////////////////////////////////////////////////////////////////////

enum LeagueCard { kLeague, kbo }

class CardSwitcher extends StatefulWidget {
  final bool isLoggedIn;

  const CardSwitcher({
    super.key,
    required this.isLoggedIn,
  });

  @override
  State<CardSwitcher> createState() => _CardSwitcherState();
}

class _CardSwitcherState extends State<CardSwitcher>
    with SingleTickerProviderStateMixin {
  double dragX = 0.0;
  late final AnimationController _controller;

  LeagueCard _front = LeagueCard.kLeague;
  LeagueCard _back = LeagueCard.kbo;

  double _fromDrag = 0.0;
  double _toDrag = 0.0;
  bool _pendingSwitch = false;

  static const double switchThreshold = 120;
  static const double maxDrag = 220;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    _controller.addListener(() {
      final t = Curves.easeOutCubic.transform(_controller.value);
      setState(() {
        dragX = _fromDrag + (_toDrag - _fromDrag) * t;
      });
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && _pendingSwitch) {
        final tmp = _front;
        _front = _back;
        _back = tmp;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void handleDragUpdate(DragUpdateDetails d) {
    if (_controller.isAnimating) _controller.stop();
    setState(() {
      dragX += d.delta.dx;
      dragX = dragX.clamp(-maxDrag, maxDrag);
    });
  }

  void handleDragEnd(DragEndDetails _) {
    _pendingSwitch = dragX.abs() > switchThreshold;
    _fromDrag = dragX;
    _toDrag = 0.0;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    const double peek = 16;
    final double m = dragX.abs();
    final bool showMatchUp = widget.isLoggedIn;

    final Offset frontOffset = Offset(m, -m * 0.35);
    final Offset backOffset = Offset(peek - m * 0.9, -peek + m * 0.35);

    final bool frontSoccer = _front == LeagueCard.kLeague;
    final bool backSoccer = _back == LeagueCard.kLeague;

    // 🔑 FRONT CARD CONTENT (로그인 상태 기준)
    final String frontTitle =
    showMatchUp ? "THIS WEEK MATCH" : "CREATE YOUR LEAGUE";

    final String frontSubtitle = showMatchUp
        ? "You vs Alex · K League"
        : (frontSoccer ? "K League · Soccer" : "KBO · Baseball");

    final VoidCallback frontAction = showMatchUp
        ? () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SimplePage(title: "Match Detail"),
        ),
      );
    }
        : () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CreateLeaguePage(isSoccer: frontSoccer),
        ),
      );
    };

    return SizedBox(
      width: 300,
      height: 200,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 🔹 BACK CARD (미리보기)
          Transform.translate(
            offset: backOffset,
            child: CardBase(
              title: showMatchUp
                  ? "THIS WEEK MATCH"
                  : "CREATE YOUR LEAGUE",
              subtitle: showMatchUp
                  ? (backSoccer
                  ? "You vs Alex · K League"
                  : "You vs Alex · KBO")
                  : (backSoccer
                  ? "K League · Soccer"
                  : "KBO · Baseball"),
              isSoccer: backSoccer,
              onStart: () {}, // back 카드는 여전히 클릭 X
            ),
          ),

          // 🔹 FRONT CARD (실제 인터랙션)
          Transform.translate(
            offset: frontOffset,
            child: GestureDetector(
              onPanUpdate: handleDragUpdate,
              onPanEnd: handleDragEnd,
              child: CardBase(
                title: frontTitle,
                subtitle: frontSubtitle,
                isSoccer: frontSoccer,
                onStart: frontAction,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class SimplePage extends StatefulWidget {
  final String title;


  const SimplePage({super.key, required this.title});

  @override
  State<SimplePage> createState() => _SimplePageState();
}

class _SimplePageState extends State<SimplePage> {
  final ValueNotifier<bool> isSearching = ValueNotifier(false);

  bool _isMyPageOpen = false;


  void _toggleMyPage() {
    setState(() => _isMyPageOpen = !_isMyPageOpen);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          // ⭐ 화면 아무 데나 누르면 underline 끄기
          _LeagueItSubAppBarState.closeSearchIfOpen();
        },
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: Colors.white,
              appBar: LeagueItSubAppBar(
                onMyPageTap: _toggleMyPage,
              ),
              body: Center(
                child: Text(
                  widget.title,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),

        /// 🔲 Dim background
        if (_isMyPageOpen)
          GestureDetector(
            onTap: _toggleMyPage,
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),

        /// 📦 My Page popup (메인페이지와 동일)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          top: _isMyPageOpen ? 100 : 20,
          right: _isMyPageOpen ? 24 : 12,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 400),
            scale: _isMyPageOpen ? 1.0 : 0.2,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _isMyPageOpen ? 1 : 0,
              child: MyPageCard(
                isLoggedIn: homeKey.currentState!._isLoggedIn,
                onLogin: () {
                  homeKey.currentState!.setState(() {
                    homeKey.currentState!._isLoggedIn = true;
                  });
                  Navigator.pop(context);
                },
                onLogout: () {
                  homeKey.currentState!.setState(() {
                    homeKey.currentState!._isLoggedIn = false;
                    homeKey.currentState!._isMyPageOpen = false;
                    homeKey.currentState!._isMenuOpen = false;
                  });
                  Navigator.pop(context); // ⭐ 이 줄이 핵심
                },
              ),
            ),
          ),
        ),
      ],
        )
        );
  }
}


class LeagueItSubAppBar extends StatefulWidget
    implements PreferredSizeWidget {
  final VoidCallback onMyPageTap;

  const LeagueItSubAppBar({
    super.key,
    required this.onMyPageTap,
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

  static _LeagueItSubAppBarState? _currentState;

  // ⭐ 외부에서 underline 닫기용
  static void closeSearchIfOpen() {
    _currentState?._closeSearch();
  }

  void _closeSearch() {
    if (_isSearching) {
      _controller.clear();
      _searchFocus.unfocus();   // ⭐ 여기!
      setState(() => _isSearching = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // ⭐ 현재 AppBar state 등록
    _currentState = this;
  }

  @override
  void dispose() {
    if (_currentState == this) {
      _currentState = null;
    }
    _searchFocus.dispose();     // ⭐ 추가
    _controller.dispose();      // ⭐ 추가
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: true,
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,

      /// ---------------- TITLE ----------------
      title: SizedBox(
        height: 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              alignment:
              _isSearching ? Alignment.centerLeft : Alignment.center,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _isSearching ? 0 : 1,
                child: GestureDetector(
                  onTap: () {
                    // 🏠 홈으로 + 완전 초기화
                    homeKey.currentState?.resetHomeUI();
                    Navigator.popUntil(
                      context,
                          (route) => route.isFirst,
                    );
                  },
                  child: const Text(
                    "LeagueIt",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      /// ---------------- ACTIONS ----------------
      actions: [
        /// 🔍 SEARCH
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
                /// 🔍 아이콘 (고정)
                const Center(
                  child: Icon(Icons.search, color: Colors.black),
                ),

                /// ✍️ ⭐ 입력창 (이게 핵심)
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

                /// underline (오른쪽 → 왼쪽)
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
                    decoration: const BoxDecoration(
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),


        const SizedBox(width: 12),

        /// 👤 MY PAGE
        GestureDetector(
          onTap: widget.onMyPageTap,
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black),
            ),
            child: const Icon(
              Icons.person_outline,
              size: 18,
              color: Colors.black,
            ),
          ),
        ),
     ],
    );
  }
}

////////////////////////////////////////////////////////////////////////////////
/// CREATE LEAGUE PAGE
////////////////////////////////////////////////////////////////////////////////

class CreateLeaguePage extends StatefulWidget {
  final bool isSoccer;
  const CreateLeaguePage({super.key, required this.isSoccer});

  @override
  State<CreateLeaguePage> createState() => _CreateLeaguePageState();
}

class _CreateLeaguePageState extends State<CreateLeaguePage> {
  bool _isMyPageOpen = false;


  void _toggleMyPage() {
    setState(() => _isMyPageOpen = !_isMyPageOpen);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        _LeagueItSubAppBarState.closeSearchIfOpen();
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.white,
            appBar: LeagueItSubAppBar(
              onMyPageTap: _toggleMyPage,
            ),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isSoccer
                        ? "Create K League"
                        : "Create KBO League",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    decoration: const InputDecoration(
                      labelText: "League Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Number of Teams",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text("Create League"),
                    ),
                  ),
                ],
              ),
            ),
          ),

          /// 🔲 DIM
          if (_isMyPageOpen)
            GestureDetector(
              onTap: _toggleMyPage,
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),

          /// 👤 MY PAGE POPUP (About Us랑 동일)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            top: _isMyPageOpen ? 100 : 20,
            right: _isMyPageOpen ? 24 : 12,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 400),
              scale: _isMyPageOpen ? 1.0 : 0.2,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _isMyPageOpen ? 1 : 0,
                child: MyPageCard(
                  isLoggedIn: homeKey.currentState!._isLoggedIn,
                  onLogin: () {
                    homeKey.currentState!.setState(() {
                      homeKey.currentState!._isLoggedIn = true;
                    });
                    Navigator.pop(context);
                  },
                  onLogout: () {
                    homeKey.currentState!.setState(() {
                      homeKey.currentState!._isLoggedIn = false;
                      homeKey.currentState!._isMyPageOpen = false;
                      homeKey.currentState!._isMenuOpen = false;
                    });
                    Navigator.pop(context); // ⭐ 이 줄이 핵심
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
////////////////////////////////////////////////////////////////////////////////
/// CARD UI
////////////////////////////////////////////////////////////////////////////////

class CardBase extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSoccer;
  final VoidCallback onStart;

  const CardBase({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isSoccer,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black87, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, 8),
            blurRadius: 12,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: Icon(
                isSoccer ? Icons.sports_soccer : Icons.sports_baseball,
                size: 180,
                color: Colors.grey,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: GestureDetector(
                  onTap: onStart, // ⭐ 여기
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E6FF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'Start',
                      style: TextStyle(
                        color: Color(0xFF9555FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

