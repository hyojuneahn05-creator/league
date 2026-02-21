part of '../home_page.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
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
          const SliverToBoxAdapter(child: _AboutHero()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            sliver: SliverList.list(
              children: const [
                _AboutBlock(
                  icon: Icons.flag_outlined,
                  title: '우리의 미션',
                  body:
                      'LeagueIt은 아마추어부터 프로까지 모두가 즐길 수 있는 판타지 리그 경험을 제공합니다. 직관적 UI와 데이터 기반 인사이트로 팬덤을 더 가깝게 만듭니다.',
                ),
                _AboutBlock(
                  icon: Icons.group_outlined,
                  title: '우리가 하는 일',
                  body:
                      '실시간 매치 데이터, 커뮤니티, 리그 관리 도구를 통합해 팀 빌드와 매치업을 쉽고 재미있게 만듭니다.',
                ),
                _AboutBlock(
                  icon: Icons.public_outlined,
                  title: '연락처',
                  body:
                      '문의: support@leagueit.fake\n파트너십: partner@leagueit.fake',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutHero extends StatelessWidget {
  const _AboutHero();

  @override
  Widget build(BuildContext context) {
    return _GradientCard(
      icon: Icons.rocket_launch_outlined,
      title: 'About LeagueIt',
      subtitle: '판타지 스포츠를 더 쉽고, 더 재미있게.',
    );
  }
}

class _AboutBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _AboutBlock({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return _InfoCard(icon: icon, title: title, body: body);
  }
}
