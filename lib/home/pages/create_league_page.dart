part of '../home_page.dart';

class CreateLeaguePage extends StatefulWidget {
  final bool isSoccer;
  const CreateLeaguePage({super.key, required this.isSoccer});

  @override
  State<CreateLeaguePage> createState() => _CreateLeaguePageState();
}

class _CreateLeaguePageState extends State<CreateLeaguePage> {
  final GlobalKey<_LeagueItSubAppBarState> _appBarKey =
      GlobalKey<_LeagueItSubAppBarState>();
  bool _isMyPageOpen = false;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _nicknameCtrl = TextEditingController();
  int? _teamCount = 8;
  int? _roundCount;
  DateTime? _draftDateTime;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _roundCount = widget.isSoccer ? 19 : 72;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    if (Platform.isIOS) {
      DateTime temp = _draftDateTime ?? now.add(const Duration(hours: 1));
      await showCupertinoModalPopup(
        context: context,
        builder: (_) => Container(
          color: CupertinoColors.systemBackground.resolveFrom(context),
          height: 280,
          child: Column(
            children: [
              SizedBox(
                height: 220,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: temp,
                  minimumDate: now,
                  maximumDate: now.add(const Duration(days: 180)),
                  use24hFormat: false,
                  onDateTimeChanged: (v) => temp = v,
                ),
              ),
              CupertinoButton(
                child: const Text('확인'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
      setState(() {
        _draftDateTime = temp;
      });
    } else {
      final date = await showDatePicker(
        context: context,
        initialDate: now.add(const Duration(days: 1)),
        firstDate: now,
        lastDate: now.add(const Duration(days: 180)),
      );
      if (date == null) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      );
      if (time == null) return;
      setState(() {
        _draftDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  Future<void> _createLeague() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('리그 이름을 입력해 주세요.')));
      return;
    }
    if (_draftDateTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Draft 날짜와 시간을 선택해 주세요.')));
      return;
    }

    setState(() => _creating = true);
    try {
      print('🔥 createLeague called');
      await LeagueService.instance.createLeague(
        _nameCtrl.text.trim(),
        isSoccer: widget.isSoccer,
        teamCount: _teamCount,
        roundCount: _roundCount,
        draftDateTime: _draftDateTime,
      );
      if (!mounted) return;
      print('✅ createLeague finished');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('리그 생성 실패: $e')));
      return;
    } finally {
      if (mounted) setState(() => _creating = false);
    }

    if (!mounted) return;
    Navigator.pop(
      context,
      _DraftResult(
        leagueName: _nameCtrl.text.trim(),
        when: _draftDateTime!,
      ),
    );
  }

  Future<void> _showNicknameInvite() async {
    _nicknameCtrl.clear();
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('닉네임으로 초대'),
          content: TextField(
            controller: _nicknameCtrl,
            decoration: const InputDecoration(
              labelText: '닉네임 입력',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                final nick = _nicknameCtrl.text.trim();
                if (nick.isEmpty) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$nick 닉네임으로 초대를 보냈어요.')),
                );
              },
              child: const Text('초대'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _appBarKey.currentState?.closeSearch(),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: LeagueItSubAppBar(
              key: _appBarKey,
              onMyPageTap: _toggleMyPage,
              showSearch: false,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isSoccer ? 'Create your League' : 'Create your League',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'League Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<int>(
                    value: _teamCount,
                    decoration: const InputDecoration(
                      labelText: 'Number of Teams',
                      border: OutlineInputBorder(),
                    ),
                    items: const [6, 8, 10, 12]
                        .map(
                          (e) =>
                              DropdownMenuItem(value: e, child: Text('$e 팀')),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _teamCount = v),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<int>(
                    value: _roundCount,
                    decoration: const InputDecoration(
                      labelText: 'Rounds',
                      border: OutlineInputBorder(),
                    ),
                    items: (widget.isSoccer ? [19, 38] : [72, 144])
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text('$e Round'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _roundCount = v),
                  ),
                  const SizedBox(height: 16),

                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      _draftDateTime == null
                          ? 'Draft 날짜 & 시간 선택'
                          : '${_draftDateTime!.month}/${_draftDateTime!.day} '
                                '${_draftDateTime!.hour.toString().padLeft(2, '0')}:${_draftDateTime!.minute.toString().padLeft(2, '0')}',
                    ),
                    onPressed: _pickDateTime,
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Invite',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _showNicknameInvite,
                          child: const Text('닉네임으로 초대'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('초대 링크가 복사되었습니다.')),
                            );
                          },
                          child: const Text('URL 링크 복사'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _creating ? null : _createLeague,
                      child: _creating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create League'),
                    ),
                  ),
                ],
              ),
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

class _DraftResult {
  final String leagueName;
  final DateTime when;
  const _DraftResult({required this.leagueName, required this.when});
}
