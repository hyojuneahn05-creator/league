class _LeagueItSubAppBarState extends State<LeagueItSubAppBar> {
  bool _isSearching = false;

  void _closeSearch() {
    if (_isSearching) {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        // ⭐ 돋보기 외 아무 터치 시 underline 제거
        _closeSearch();
      },
      child: AppBar(
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
              /// 🔤 LeagueIt (왼쪽으로 사라짐)
              AnimatedAlign(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
                alignment:
                    _isSearching ? Alignment.centerRight : Alignment.center,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _isSearching ? 0 : 1,
                  child: GestureDetector(
                    onTap: () {
                      /// 🏠 LeagueIt 누르면 홈으로 (완전 초기화)
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
          /// 🔍 SEARCH (이거 눌렀을 때만 underline 생김)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => _isSearching = true);
            },
            child: SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  /// 아이콘은 절대 움직이지 않음
                  const Center(
                    child: Icon(Icons.search, color: Colors.black),
                  ),

                  /// underline (오른쪽 → 왼쪽 확장)
                  Positioned(
                    bottom: 6,
                    right: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                      height: 1.4, // 메인페이지와 동일
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
      ),
    );
  }
}