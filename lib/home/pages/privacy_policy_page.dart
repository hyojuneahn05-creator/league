part of '../home_page.dart';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  bool _isMyPageOpen = false;

  void _toggleMyPage() {
    setState(() => _isMyPageOpen = !_isMyPageOpen);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: LeagueItSubAppBar(
              onMyPageTap: _toggleMyPage,
              showSearch: false,
            ),
            body: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _HeroCard(),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: const [
                            _Section(
                              icon: Icons.info_outline,
                              title: '1. Introduction',
                              body:
                                  'LeagueIt 이용 시 수집·이용되는 개인정보와 사용자 권리를 안내합니다. 실제 서비스 배포 시 회사명·연락처·책임자 정보를 반영해 주세요.',
                            ),
                            _Section(
                              icon: Icons.list_alt_outlined,
                              title: '2. Data We Collect',
                              body:
                                  '• 필수: 계정 이메일, 비밀번호 해시, 로그인 기록\n• 선택: 프로필 이미지, 닉네임\n• 기기/로그: 앱 버전, OS, 크래시 로그',
                            ),
                            _Section(
                              icon: Icons.lock_open_outlined,
                              title: '3. How We Use Data',
                              body:
                                  '계정 인증, 리그/매치 업데이트, 알림 전송, 보안 모니터링, 고객지원에 활용합니다.',
                            ),
                            _Section(
                              icon: Icons.share_arrival_time_outlined,
                              title: '4. Sharing & Retention',
                              body:
                                  '법적 요구 또는 서비스 제공을 위한 최소한의 위탁(클라우드, 분석 등)에만 공유하며, 목적 달성 후 지체 없이 파기합니다.',
                            ),
                            _Section(
                              icon: Icons.verified_user_outlined,
                              title: '5. Your Rights',
                              body:
                                  '열람·정정·삭제·처리정지를 요구할 수 있습니다. 앱 내 문의 또는 support@leagueit.fake 로 요청하세요.',
                            ),
                            _Section(
                              icon: Icons.mail_outline,
                              title: '6. Contact',
                              body:
                                  '개인정보 보호 책임자: (추가 예정)\n문의: support@leagueit.fake',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_isMyPageOpen)
            GestureDetector(
              onTap: _toggleMyPage,
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

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _Section({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFE4F7EA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Icon(icon, color: Colors.green.shade800, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
              Icons.privacy_tip_outlined,
              size: 26,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Privacy & Safety',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text(
                  '사용자의 데이터는 암호화 및 최소 권한 원칙에 따라 보호됩니다.',
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
