part of '../home_page.dart';

class FAQPage extends StatefulWidget {
  const FAQPage({super.key});

  @override
  State<FAQPage> createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  bool _isMyPageOpen = false;
  int _selectedTabIndex = 0;

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  void _selectTab(int index) {
    if (_selectedTabIndex == index) return;
    setState(() => _selectedTabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      showSearch: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _FAQHero(
              selectedTabIndex: _selectedTabIndex,
              onTabChanged: _selectTab,
            ),
          ),
          if (_selectedTabIndex == 0)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
              sliver: SliverList.list(
                children: [
                  for (final section in _faqSections)
                    _FAQSectionCard(section: section),
                ],
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
              sliver: SliverList.list(
                children: const [
                  _FptsSummaryCard(),
                  SizedBox(height: 16),
                  _FptsRuleTableCard(group: _kLeagueFptsRuleGroup),
                  SizedBox(height: 16),
                  _FptsRuleTableCard(group: _kboFptsRuleGroup),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FAQHero extends StatelessWidget {
  final int selectedTabIndex;
  final ValueChanged<int> onTabChanged;

  const _FAQHero({required this.selectedTabIndex, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    final isFaqTab = selectedTabIndex == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 18),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.accent, palette.accent.withValues(alpha: 0.84)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: palette.accent.withValues(alpha: 0.22),
              blurRadius: 26,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: const Text(
                'LeagueIt 도움말',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isFaqTab ? 'FAQs' : 'Fpts 규칙',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                height: 1.05,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isFaqTab
                  ? '계정, 리그, 드래프트, 로스터 운영까지 자주 묻는 질문을 한곳에서 바로 확인할 수 있습니다.'
                  : 'K리그와 KBO의 판타지 점수 기준을 종목별로 나눠 한눈에 비교할 수 있습니다.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _FAQHeroTab(
                    label: 'FAQs',
                    isSelected: isFaqTab,
                    onTap: () => onTabChanged(0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FAQHeroTab(
                    label: 'Fpts 규칙',
                    isSelected: !isFaqTab,
                    onTap: () => onTabChanged(1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FAQHeroTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FAQHeroTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? const Color(0xFF245B45) : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _FAQSectionCard extends StatelessWidget {
  final _FaqSectionData section;

  const _FAQSectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        decoration: BoxDecoration(
          color: palette.tileSurface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: palette.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: palette.accentSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(section.icon, color: palette.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: TextStyle(
                            color: palette.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (var index = 0; index < section.entries.length; index++) ...[
                _FAQItem(entry: section.entries[index]),
                if (index != section.entries.length - 1)
                  const SizedBox(height: 12),
              ],
            ],
          ),
        ),
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

class _FAQItemState extends State<_FAQItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _expanded ? palette.accentSoft : palette.fieldFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _expanded ? palette.chipBorder : palette.cardBorder,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _expanded
                          ? palette.accent
                          : palette.accent.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Q',
                      style: TextStyle(
                        color: _expanded ? Colors.white : palette.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        widget.entry.question,
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 28,
                      color: palette.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeOut,
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.chipBorder),
                ),
                child: Text(
                  widget.entry.answer,
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FptsSummaryCard extends StatelessWidget {
  const _FptsSummaryCard();

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.chipBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '점수 계산 요약',
            style: TextStyle(
              color: palette.accent,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '아래 표는 현재 LeagueIt 앱에서 적용되는 기본 Fpts 규칙입니다. '
            '캡틴(C)으로 지정된 선수는 최종 Fpts가 2배로 반영됩니다.',
            style: TextStyle(
              color: palette.accent,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FptsRuleTableCard extends StatelessWidget {
  final _FptsRuleGroup group;

  const _FptsRuleTableCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.tileSurface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(group.icon, color: palette.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.title,
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        group.subtitle,
                        style: TextStyle(
                          color: palette.mutedInk,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: palette.fieldFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Column(
                children: [
                  const _FptsRuleHeaderRow(),
                  const SizedBox(height: 10),
                  for (var index = 0; index < group.rules.length; index++) ...[
                    _FptsRuleValueRow(
                      row: group.rules[index],
                      isEven: index.isEven,
                    ),
                    if (index != group.rules.length - 1)
                      const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FptsRuleHeaderRow extends StatelessWidget {
  const _FptsRuleHeaderRow();

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: palette.accent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '항목',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              '조건',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Fpts',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FptsRuleValueRow extends StatelessWidget {
  final _FptsRuleRow row;
  final bool isEven;

  const _FptsRuleValueRow({required this.row, required this.isEven});

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: isEven
            ? Colors.white
            : palette.accentSoft.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              row.label,
              style: TextStyle(
                color: palette.ink,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: Text(
              row.condition,
              style: TextStyle(
                color: palette.mutedInk,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              row.points,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: palette.accent,
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqSectionData {
  final String title;
  final IconData icon;
  final List<_FaqEntry> entries;

  const _FaqSectionData({
    required this.title,
    required this.icon,
    required this.entries,
  });
}

class _FaqEntry {
  final String question;
  final String answer;

  const _FaqEntry({required this.question, required this.answer});
}

class _FptsRuleGroup {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<_FptsRuleRow> rules;

  const _FptsRuleGroup({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.rules,
  });
}

class _FptsRuleRow {
  final String label;
  final String condition;
  final String points;

  const _FptsRuleRow({
    required this.label,
    required this.condition,
    required this.points,
  });
}

const List<_FaqSectionData> _faqSections = <_FaqSectionData>[
  _FaqSectionData(
    title: '판타지리그',
    icon: Icons.emoji_events_outlined,
    entries: <_FaqEntry>[
      _FaqEntry(
        question: '판타지리그가 뭔가요?',
        answer:
            '판타지리그는 실제 K리그 또는 KBO 선수들로 나만의 팀을 구성해 경쟁하는 가상 리그입니다. '
            '유저는 드래프트를 통해 선수를 선택하고, 로스터를 운영하며, 실제 경기 결과에 따라 반영되는 판타지 포인트로 '
            '다른 유저와 매치업 및 순위를 겨루게 됩니다.',
      ),
      _FaqEntry(
        question: '참여할 수 있는 판타지리그가 제한이 있나요?',
        answer:
            'LeagueIt에서는 한 개의 리그만 참여해야 하는 제한은 없습니다. '
            '리그 정원이 남아 있다면 여러 판타지리그를 직접 만들거나 초대 코드를 통해 참가할 수 있습니다.',
      ),
      _FaqEntry(
        question: '한 판타지리그에 몇 명의 유저까지 참가할 수 있나요?',
        answer:
            '한 판타지리그의 참가 인원은 리그 생성 시 설정되며, 현재 6명, 8명, 10명, 12명 중에서 선택할 수 있습니다. '
            '즉, 한 리그에는 최대 12명까지 참가할 수 있습니다.',
      ),
      _FaqEntry(
        question: 'K리그와 KBO 두 개 중에 하나만 할 수 있는 건가요?',
        answer:
            '아닙니다. LeagueIt에서는 K리그 판타지리그와 KBO 판타지리그를 각각 따로 즐길 수 있습니다. '
            '원하면 두 종목의 리그에 모두 참여할 수 있습니다.',
      ),
      _FaqEntry(
        question: 'K리그나 KBO나 판타지리그와 라운드가 달라요',
        answer:
            '네, 그럴 수 있습니다. LeagueIt의 판타지리그 라운드는 실제 K리그/KBO 공식 일정과 연결되지만, '
            '판타지리그가 시작된 시점과 드래프트 일정 등을 기준으로 판타지용 라운드가 별도로 계산되기 때문에 공식 라운드 번호와 다르게 보일 수 있습니다.',
      ),
      _FaqEntry(
        question: '판타지리그 라운드는 어떻게 정해지는 건가요?',
        answer:
            '판타지리그 라운드는 실제 경기 일정과 리그 시작 시점을 기준으로 자동 설정됩니다. '
            '드래프트 이후부터 어떤 경기들이 한 라운드에 포함되는지 시스템이 정해주며, 그 일정에 따라 로스터 잠금, 점수 반영, 매치업 결과가 진행됩니다.',
      ),
      _FaqEntry(
        question: '판타지리그 일정 순서는 어떻게 배정되는 건가요?',
        answer:
            '판타지리그의 매치업 일정은 리그 참가 인원을 기준으로 자동 편성됩니다. '
            '각 유저가 고르게 상대를 만나도록 라운드 로빈 방식으로 배정되며, 시즌 동안 순서에 맞춰 매치업이 진행됩니다.',
      ),
      _FaqEntry(
        question: '리그 초대는 어떻게 하나요?',
        answer:
            '리그를 만든 뒤 생성된 초대 코드 또는 초대 링크를 친구에게 공유하면 됩니다. '
            '초대받은 유저는 해당 코드를 입력하거나 링크를 통해 리그에 참가할 수 있습니다.',
      ),
      _FaqEntry(
        question: '판타지리그에서 탈퇴할 수 있나요?',
        answer:
            '네, 가능합니다. My League 화면에서 해당 리그를 왼쪽 방향으로 슬라이드하면 탈퇴 버튼이 보입니다. '
            '다만 이미 참여 중인 리그의 진행 상태에 따라 일부 기능이나 기록 반영 방식은 달라질 수 있습니다.',
      ),
    ],
  ),
  _FaqSectionData(
    title: '계정',
    icon: Icons.manage_accounts_rounded,
    entries: <_FaqEntry>[
      _FaqEntry(
        question: '회원가입에 나이제한이 있나요?',
        answer:
            '현재 LeagueIt 회원가입 과정에는 나이 입력이나 별도의 연령 제한 확인 절차가 없습니다. '
            '누구나 이메일, Apple 또는 Google 계정으로 가입할 수 있습니다.',
      ),
      _FaqEntry(
        question: '판타지 팀 이름 어떻게 변경하나요?',
        answer:
            'LeagueIt에서는 프로필의 유저네임을 변경하면 판타지 팀 이름도 함께 변경됩니다. '
            '프로필 화면에서 유저네임을 수정한 뒤 저장해 주세요.',
      ),
      _FaqEntry(
        question: '비밀번호를 잊어버렸어요.',
        answer:
            '로그인 화면에서 비밀번호를 잊으셨나요?를 눌러 가입한 이메일 주소를 입력해 주세요. '
            '해당 이메일로 비밀번호 재설정 링크가 발송되며, 메일 안의 안내에 따라 새 비밀번호를 설정할 수 있습니다.\n\n'
            '메일이 바로 보이지 않는 경우에는 스팸함이나 프로모션함도 함께 확인해 주세요. '
            'Google 또는 Apple 계정으로 가입한 경우에는 비밀번호 재설정 대신 해당 로그인 수단을 통해 다시 로그인해야 합니다.',
      ),
    ],
  ),
  _FaqSectionData(
    title: '드래프트',
    icon: Icons.how_to_vote_outlined,
    entries: <_FaqEntry>[
      _FaqEntry(
        question: '드래프트 시스템이 뭔가요?',
        answer:
            '드래프트는 리그 시작 전에 참가 유저들이 차례대로 선수를 선택해 각자 팀을 구성하는 방식입니다. '
            '한 번 선택된 선수는 다른 유저가 중복해서 데려갈 수 없으며, 드래프트가 끝나면 선택한 선수들이 내 판타지팀 로스터의 기본 구성이 됩니다.',
      ),
      _FaqEntry(
        question: '몇 명의 선수를 드래프트 할 수 있나요?',
        answer:
            '드래프트 인원은 종목에 따라 다릅니다. K리그 판타지리그는 팀당 18명, KBO 판타지리그는 팀당 21명을 드래프트하게 됩니다.',
      ),
      _FaqEntry(
        question: 'Mock 드래프트는 뭔가요?',
        answer:
            'Mock 드래프트는 실제 리그에 영향을 주지 않는 연습용 드래프트입니다. '
            '실제 드래프트와 비슷한 방식으로 선수 선택 흐름을 미리 경험해볼 수 있고, 다른 팀 선택도 함께 시뮬레이션되기 때문에 드래프트 전략을 연습할 때 사용할 수 있습니다.',
      ),
      _FaqEntry(
        question: '드래프트 순서는 어떻게 배정이 되는 건가요?',
        answer:
            '드래프트 순서는 리그 정원이 모두 채워지면 참가자 기준으로 무작위 배정됩니다. '
            '배정된 순서는 리그의 드래프트 순번으로 저장되며, 실제 드래프트는 그 순서에 따라 진행됩니다.',
      ),
      _FaqEntry(
        question: '드래프트 시간은 어떻게 진행되나요?',
        answer:
            '드래프트는 리그 생성 시 정한 시작 시간에 맞춰 진행됩니다. '
            '시작 후에는 각 팀이 순서대로 선수를 선택하게 되며, 현재 LeagueIt에서는 한 픽당 90초의 시간이 주어집니다.',
      ),
      _FaqEntry(
        question: '자동 지명 기능이 있나요?',
        answer:
            '현재 드래프트 중 직접 선수를 선택하지 않으면 해당 턴은 자동으로 다음 순서로 넘어갑니다. '
            '드래프트가 모두 끝난 뒤 비어 있는 칸이 있으면, 시스템이 포지션 최소 조건을 우선 맞춘 뒤 남은 자리를 자동으로 보정합니다.',
      ),
      _FaqEntry(
        question: '드래프트 시간에 참여하지 못하면 어떻게 되나요?',
        answer:
            '드래프트 시간에 접속하지 못하더라도 리그가 바로 중단되지는 않습니다. '
            '내 차례에 선수를 직접 선택하지 못한 픽은 넘어가고, 드래프트 종료 시 남아 있는 빈 자리는 자동 보정 방식으로 채워집니다.',
      ),
      _FaqEntry(
        question: '드래프트 중간에 나가도 괜찮나요?',
        answer:
            '네, 드래프트 도중 앱을 벗어나더라도 드래프트 자체는 예정된 시간 흐름에 따라 계속 진행됩니다. '
            '다만 접속하지 않은 동안에는 직접 픽을 할 수 없기 때문에, 해당 구간은 지나간 뒤 남은 빈칸이 자동 보정될 수 있습니다.',
      ),
    ],
  ),
  _FaqSectionData(
    title: '선수 영입/방출/트레이드',
    icon: Icons.swap_horiz_rounded,
    entries: <_FaqEntry>[
      _FaqEntry(
        question: '선수 영입/방출은 어떻게 하나요?',
        answer:
            'Players 탭에서 원하는 선수를 선택해 진행할 수 있습니다. FA(자유 선수)는 영입 버튼을 눌러 데려올 수 있고, '
            '내 팀 소속 선수는 방출 버튼을 눌러 로스터에서 제외할 수 있습니다. 로스터가 가득 찬 상태에서 선수를 영입하려면 먼저 방출할 선수를 선택해야 하며, '
            '스타팅 선수를 방출하는 경우에는 같은 포지션의 벤치 선수가 자동으로 올라갑니다.',
      ),
      _FaqEntry(
        question: '선수 영입과 트레이드는 언제 할 수 있는 건가요?',
        answer:
            '선수 영입, 방출, 트레이드는 해당 선수가 로스터 잠금 상태가 아닐 때만 가능합니다. '
            '경기 시작 등으로 잠긴 선수는 이동, 영입, 방출, 트레이드가 제한되며, 잠금이 해제된 뒤 다시 진행할 수 있습니다.',
      ),
      _FaqEntry(
        question: '선수 트레이드는 어떻게 진행되나요?',
        answer:
            '다른 팀 소속 선수에게 트레이드를 제안하면 트레이드 화면에서 내 팀 선수와 상대 팀 선수를 선택해 요청을 보낼 수 있습니다. '
            '요청을 받은 유저는 제안을 확인한 뒤 수락 또는 거절할 수 있고, 수락되면 양 팀 로스터에 실제로 반영됩니다. 거절되면 기존 로스터는 그대로 유지됩니다.',
      ),
      _FaqEntry(
        question: '선수 영입 혹은 방출을 취소할 수 있나요?',
        answer:
            '진행 중에는 취소할 수 있습니다. 예를 들어 방출 확인 창에서 취소를 누르거나, 영입 과정에서 선수 선택 창을 닫으면 적용되지 않습니다. '
            '다만 영입이나 방출이 최종 저장된 뒤에는 별도의 되돌리기 버튼은 없기 때문에, 다시 선수를 영입하거나 방출하는 방식으로 직접 조정해야 합니다.',
      ),
    ],
  ),
  _FaqSectionData(
    title: 'Match Up',
    icon: Icons.insights_outlined,
    entries: <_FaqEntry>[
      _FaqEntry(
        question: '예상 Fpts는 무엇을 의미하는 건가요?',
        answer:
            '예상 Fpts는 해당 선수가 이번 라운드에서 기록할 것으로 예상되는 판타지 포인트입니다. '
            '선수의 최근 경기 흐름, 시즌 기록, 출전 가능성, 팀 컨디션 등을 바탕으로 계산된 참고용 수치이며, 실제 경기 결과에 따라 최종 Fpts는 달라질 수 있습니다.',
      ),
      _FaqEntry(
        question: '승리확률은 뭔가요?',
        answer:
            '승리확률은 현재 매치업에서 양 팀의 예상 Fpts를 비교해 어느 팀이 더 유리한지를 보여주는 지표입니다. '
            '즉, 실제 확정 결과가 아니라 양 팀 예상 점수 비중을 바탕으로 표시되는 예상치라고 보면 됩니다.',
      ),
      _FaqEntry(
        question: '매치업 탭과 로스터 탭의 차이가 뭔가요?',
        answer:
            '매치업 탭은 이번 라운드에서 내 팀과 상대 팀이 어떻게 맞붙는지 보는 화면입니다. '
            '양 팀 선발 라인업, 예상 Fpts, 승리확률 등을 비교할 수 있습니다.\n\n'
            '로스터 탭은 내 팀을 직접 관리하는 화면입니다. 스타팅과 벤치를 확인하고, '
            '선수 위치를 조정하거나 교체하고, 저장해서 실제 운영 중인 로스터에 반영할 수 있습니다.',
      ),
    ],
  ),
  _FaqSectionData(
    title: 'Roster',
    icon: Icons.view_list_rounded,
    entries: <_FaqEntry>[
      _FaqEntry(
        question: '교체명단에 있는 선수의 점수도 반영이 되나요?',
        answer:
            '아닙니다. 해당 라운드의 팀 점수는 스타팅 라인업에 들어간 선수들의 점수만 반영되며, 교체명단(벤치) 선수의 점수는 합산되지 않습니다.',
      ),
      _FaqEntry(
        question: '캡틴과 VC의 차이가 뭔가요?',
        answer:
            '캡틴(C)은 해당 선수의 판타지 점수가 더 크게 반영되는 핵심 선수입니다. 현재 LeagueIt에서는 캡틴 점수 2배가 적용됩니다. '
            '기본적으로 VC(부주장)는 일반 선수와 동일하게 점수가 반영되지만, 만약 캡틴이 그 라운드에 출전하지 않았다면 VC가 대신 캡틴 역할을 받아 해당 라운드 Fpts가 2배로 적용됩니다. '
            '즉, 캡틴은 1순위 2배 적용 선수이고, VC는 캡틴 미출전 시 대신 2배를 받는 예비 주장입니다.',
      ),
      _FaqEntry(
        question: '캡틴 변경 어떻게 하나요?',
        answer:
            'Roster 탭에서 스타팅 선수 카드를 누른 뒤 선수 상세 팝업에서 주장 또는 부주장 버튼을 선택하면 됩니다. '
            '변경 후에는 저장 버튼을 눌러야 실제 로스터에 반영되며, 이미 잠긴 선수는 경기 중 변경할 수 없습니다.',
      ),
      _FaqEntry(
        question: '경기 중인데 선수를 바꾸고 싶은데 왜 안되나요?',
        answer:
            '경기 시작 후에는 해당 선수 또는 해당 팀 소속 선수들이 로스터 잠금 상태가 되기 때문입니다. '
            '잠긴 선수는 이동, 교체, 영입/방출, 주장/부주장 변경이 제한되어 경기 진행 중 임의로 라인업을 바꿀 수 없습니다.',
      ),
      _FaqEntry(
        question: '로스터 잠기는 시점과 풀리는 시점이 어떻게 되나요?',
        answer:
            '로스터는 경기 시작 시점부터 잠깁니다.\n'
            'K리그는 해당 라운드 경기들이 시작되면 관련 선수들이 잠기고, 라운드가 끝난 뒤 해제됩니다.\n'
            'KBO는 그날 경기하는 팀 선수들이 경기 시작과 함께 잠기고, 당일 경기들이 모두 종료된 뒤 시스템 해제 시점에 다시 풀립니다.',
      ),
    ],
  ),
  _FaqSectionData(
    title: 'Players',
    icon: Icons.groups_2_outlined,
    entries: <_FaqEntry>[
      _FaqEntry(
        question: 'Apts가 안 뜨는 선수들이 있어요.',
        answer:
            '일부 선수는 기록 데이터가 아직 충분하지 않거나, 최근 등록된 선수이거나, '
            '해당 선수의 프로필 정보를 아직 불러오지 못한 경우 Apts가 바로 표시되지 않을 수 있습니다. '
            '이런 경우에는 잠시 후 다시 불러오거나 Players 탭에 재진입하면 표시될 수 있으며, '
            '데이터가 없는 선수는 Apts가 비어 있거나 낮게 보일 수 있습니다.',
      ),
    ],
  ),
  _FaqSectionData(
    title: 'League',
    icon: Icons.leaderboard_outlined,
    entries: <_FaqEntry>[
      _FaqEntry(
        question: '판타지리그 순위는 어떤 기준으로 계산되는 건가요?',
        answer:
            '판타지리그 순위는 각 라운드 매치업 결과를 기준으로 계산됩니다. '
            '현재 LeagueIt에서는 승리 3점, 무승부 1점, 패배 0점 방식으로 순위 포인트가 쌓이며, 동률일 경우에는 득실차(내 점수 - 상대 점수), 그다음 누적 득점 순으로 순위가 정해집니다.',
      ),
      _FaqEntry(
        question: '파워랭킹은 뭔가요?',
        answer: '파워랭킹은 현재 리그 팀들의 최근 흐름과 전력을 보여주는 지표입니다.',
      ),
      _FaqEntry(
        question: '지난 라운드의 이주의 선수는 세명밖에 안보여요',
        answer:
            '메인 리그 화면에서는 지난 라운드 이주의 선수를 Top 3 형태로 미리보기만 보여주기 때문에 세 명만 보입니다.',
      ),
    ],
  ),
  _FaqSectionData(
    title: 'K리그',
    icon: Icons.sports_soccer_outlined,
    entries: <_FaqEntry>[
      _FaqEntry(
        question: '수비수를 공격수로 사용할 수 있나요?',
        answer:
            '아니요. K리그 판타지리그에서는 선수의 등록 포지션에 맞게만 사용할 수 있습니다. '
            '수비수는 수비수 자리에서만, 미드필더는 미드필더 자리에서만 배치할 수 있으며, 공격수 자리로 임의 변경하는 것은 불가능합니다.',
      ),
      _FaqEntry(
        question: '포메이션 변경은 어떻게 하나요?',
        answer:
            'Roster 탭에서 스타팅 선수와 벤치 선수를 교체하면, 현재 선발 구성에 맞춰 포메이션이 자동으로 바뀝니다. '
            '다만 아무 조합이나 가능한 것은 아니고, LeagueIt에서 허용하는 선발 포메이션 범위 안에서만 변경할 수 있습니다.',
      ),
      _FaqEntry(
        question: '연기되는 경기는 어떻게 되나요?',
        answer:
            '경기가 연기되면 해당 경기 선수들의 점수는 바로 반영되지 않습니다. '
            '현재 기준으로는 연기된 경기에서 실제 출전 및 점수 데이터가 확정되지 않으면 그 라운드에 점수가 잡히지 않을 수 있으니, 일정과 점수는 앱 내 업데이트를 확인해 주세요.',
      ),
    ],
  ),
  _FaqSectionData(
    title: 'KBO',
    icon: Icons.sports_baseball_outlined,
    entries: <_FaqEntry>[
      _FaqEntry(
        question: '우천취소 경기는 어떻게 처리 되나요?',
        answer:
            '우천취소된 경기는 해당 시점에 실제 경기 결과가 없기 때문에 점수가 반영되지 않습니다. '
            '만약 경기가 진행중이다가 취소되거나 연기되면 취소된 시점까지 획득한 Fpts까지만 반영이 됩니다.',
      ),
      _FaqEntry(
        question: 'Roster에서 내야수와 외야수의 세부 포지션은 없는 건가요?',
        answer:
            '현재 LeagueIt의 KBO 로스터 구성은 세부 수비 위치까지 나누지 않고 '
            '투수(P), 포수(C), 내야수(IF), 외야수(OF) 단위로 운영됩니다. '
            '그래서 1루수, 2루수, 유격수, 3루수는 모두 IF, 좌익수, 중견수, 우익수는 모두 OF로 묶여 표시되고 관리됩니다.',
      ),
    ],
  ),
  _FaqSectionData(
    title: 'Fpts & Apts',
    icon: Icons.rule_folder_outlined,
    entries: <_FaqEntry>[
      _FaqEntry(
        question: 'Fpts 부여 기준이 어떻게 되나요?',
        answer:
            'LeagueIt의 Fpts는 실제 경기 기록을 바탕으로 자동 계산되는 판타지 점수입니다. '
            '선수의 포지션과 종목에 따라 반영되는 기록이 다르며, 예를 들어 축구는 득점, 도움, 출전, 클린시트 등의 요소가, '
            '야구는 안타, 홈런, 타점, 득점, 이닝, 탈삼진, 승리, 세이브 등의 요소가 점수에 반영됩니다. '
            '각 선수의 Fpts는 경기 진행에 따라 실시간 또는 경기 종료 후 업데이트되며, 해당 라운드의 팀 점수와 순위 계산에 사용됩니다.',
      ),
      _FaqEntry(
        question: 'Apts는 뭔가요?',
        answer:
            'Apts는 Average Points의 약자로, 해당 선수가 최근까지 기록한 평균 판타지 점수를 뜻합니다. '
            '한 경기에서의 점수가 아니라 여러 경기 또는 여러 라운드 동안 쌓인 Fpts를 기준으로 계산된 평균값이라서, '
            '선수가 꾸준히 높은 점수를 내는지 판단할 때 참고할 수 있습니다. 드래프트나 로스터 구성, 선수 영입 판단 시 기준 지표로 활용하면 좋습니다.',
      ),
    ],
  ),
];

const _FptsRuleGroup _kLeagueFptsRuleGroup = _FptsRuleGroup(
  title: 'K리그 Fpts 룰',
  subtitle: '출전 시간, 포지션별 득점/도움, 카드, 무실점, 경기 결과가 반영됩니다.',
  icon: Icons.sports_soccer_rounded,
  rules: <_FptsRuleRow>[
    _FptsRuleRow(label: '출전', condition: '실제 출전 시간 1분당', points: '+0.1'),
    _FptsRuleRow(label: '득점', condition: 'GK 득점 1회', points: '+10'),
    _FptsRuleRow(label: '득점', condition: 'DF 득점 1회', points: '+7'),
    _FptsRuleRow(label: '득점', condition: 'MF 득점 1회', points: '+6'),
    _FptsRuleRow(label: '득점', condition: 'FW 득점 1회', points: '+5'),
    _FptsRuleRow(label: '도움', condition: 'GK 도움 1회', points: '+5'),
    _FptsRuleRow(label: '도움', condition: 'DF / MF / FW 도움 1회', points: '+3'),
    _FptsRuleRow(label: '옐로카드', condition: '1회', points: '-1'),
    _FptsRuleRow(label: '레드카드', condition: '1회', points: '-3'),
    _FptsRuleRow(label: '페널티킥 실축', condition: '1회', points: '-1'),
    _FptsRuleRow(label: '자책골', condition: '1회', points: '-2'),
    _FptsRuleRow(label: '무실점', condition: 'GK / DF만 해당', points: '+3'),
    _FptsRuleRow(label: '경기 승리', condition: '출전했고 경기 종료 기준 승리', points: '+3'),
    _FptsRuleRow(label: '경기 무승부', condition: '출전했고 경기 종료 기준 무승부', points: '+1'),
    _FptsRuleRow(label: '경기 패배', condition: '출전했고 경기 종료 기준 패배', points: '0'),
  ],
);

const _FptsRuleGroup _kboFptsRuleGroup = _FptsRuleGroup(
  title: 'KBO Fpts 룰',
  subtitle: '타자 기록과 투수 기록이 함께 합산되며, 항목별 점수가 누적됩니다.',
  icon: Icons.sports_baseball_rounded,
  rules: <_FptsRuleRow>[
    _FptsRuleRow(label: '홈런', condition: '1개', points: '+5'),
    _FptsRuleRow(label: '3루타', condition: '1개', points: '+3'),
    _FptsRuleRow(label: '2루타', condition: '1개', points: '+2'),
    _FptsRuleRow(label: '안타', condition: '1개', points: '+1'),
    _FptsRuleRow(label: '타점', condition: '1개', points: '+1'),
    _FptsRuleRow(label: '득점', condition: '1개', points: '+1'),
    _FptsRuleRow(label: '볼넷', condition: '1개', points: '+0.5'),
    _FptsRuleRow(label: '사구', condition: '1개', points: '+0.5'),
    _FptsRuleRow(label: '도루', condition: '1개', points: '+2'),
    _FptsRuleRow(label: '타자 삼진', condition: '1개', points: '-0.5'),
    _FptsRuleRow(label: '투구 이닝', condition: '1이닝', points: '+2'),
    _FptsRuleRow(label: '투수 탈삼진', condition: '1개', points: '+1'),
    _FptsRuleRow(label: '승리투수', condition: '1회', points: '+5'),
    _FptsRuleRow(label: '세이브', condition: '1회', points: '+5'),
    _FptsRuleRow(label: '자책점', condition: '1점', points: '-2'),
    _FptsRuleRow(label: '투수 볼넷', condition: '1개', points: '-0.5'),
  ],
);
