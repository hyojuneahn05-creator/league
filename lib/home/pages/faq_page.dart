part of '../home_page.dart';

class FAQPage extends StatefulWidget {
  const FAQPage({super.key});

  @override
  State<FAQPage> createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  final GlobalKey<_LeagueItSubAppBarState> _appBarKey =
      GlobalKey<_LeagueItSubAppBarState>();
  bool _isMyPageOpen = false;

  final List<_FaqEntry> _entries = List.generate(
    8,
    (index) => _FaqEntry(
      question: 'Question ${index + 1}',
      answer: 'Answer for question ${index + 1}. Placeholder content.',
    ),
  );

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
              onMyPageTap: () {
                setState(() => _isMyPageOpen = !_isMyPageOpen);
              },
              showSearch: false,
            ),
            body: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: _FAQHeroCard()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  sliver: SliverList.separated(
                    itemBuilder: (context, index) =>
                        _FAQItem(entry: _entries[index]),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: _entries.length,
                  ),
                ),
              ],
            ),
          ),
          if (_isMyPageOpen)
            GestureDetector(
              onTap: () => setState(() => _isMyPageOpen = false),
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FAQItem extends StatefulWidget {
  final _FaqEntry entry;

  const _FAQItem({required this.entry});

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              widget.entry.question,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            trailing: AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 26,
              ),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          AnimatedCrossFade(
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                border: Border.all(color: Colors.black12),
              ),
              child: Text(
                widget.entry.answer,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqEntry {
  final String question;
  final String answer;

  _FaqEntry({required this.question, required this.answer});
}

class _FAQHeroCard extends StatelessWidget {
  const _FAQHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDCF8E8), Color(0xFFC6E8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.green.shade400, width: 1.2),
            ),
            child: Icon(
              Icons.quiz_outlined,
              size: 26,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '자주 묻는 질문',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text(
                  '궁금한 점을 빠르게 찾아보세요. 카테고리별로 정리되어 있어요.',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
