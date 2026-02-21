part of '../home_page.dart';

class PlaybookPage extends StatefulWidget {
  const PlaybookPage({super.key});

  @override
  State<PlaybookPage> createState() => _PlaybookPageState();
}

class _PlaybookPageState extends State<PlaybookPage> {
  bool _isMyPageOpen = false;
  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  @override
  Widget build(BuildContext context) {
    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      showSearch: false,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _PlaybookHero()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            sliver: SliverList.list(
              children: const [
                _InfoCard(
                  icon: Icons.sports_soccer_outlined,
                  title: '1. 팀 만들기',
                  body: '리그 참여 후 선수 풀에서 드래프트 또는 오토픽으로 스쿼드를 구성하세요.',
                ),
                _InfoCard(
                  icon: Icons.swap_horiz_outlined,
                  title: '2. 라인업 설정',
                  body: '경기 전까지 포메이션과 라인업을 확정하세요. 미선정 시 기본 라인업이 적용됩니다.',
                ),
                _InfoCard(
                  icon: Icons.bolt_outlined,
                  title: '3. 포인트 획득',
                  body: '실제 경기 기록(골/도움/클린시트 등)을 기반으로 자동 포인트가 집계됩니다.',
                ),
                _InfoCard(
                  icon: Icons.query_stats_outlined,
                  title: '4. 매치업 & 순위',
                  body: '주간 매치업 결과로 리그 순위가 갱신되며, 승점/득점이 누적됩니다.',
                ),
                _InfoCard(
                  icon: Icons.notifications_active_outlined,
                  title: '5. 알림 받기',
                  body: '선수 부상/출전 정보, 마감 알림을 푸시로 받아 라인업을 제때 조정하세요.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaybookHero extends StatelessWidget {
  const _PlaybookHero();

  @override
  Widget build(BuildContext context) {
    return _GradientCard(
      icon: Icons.menu_book_outlined,
      title: 'PlayBook',
      subtitle: '판타지 리그 진행 방법 한눈에 보기',
    );
  }
}
