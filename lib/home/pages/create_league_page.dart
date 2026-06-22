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
  final GlobalKey _leagueNameCoachKey = GlobalKey();
  final GlobalKey _teamCountCoachKey = GlobalKey();
  final GlobalKey _draftDateCoachKey = GlobalKey();
  final GlobalKey _inviteCoachKey = GlobalKey();
  final GlobalKey _createButtonCoachKey = GlobalKey();
  bool _isMyPageOpen = false;

  final TextEditingController _nameCtrl = TextEditingController();
  int? _teamCount = 8;
  int? _roundCount;
  DateTime? _draftDateTime;
  bool _creating = false;
  String? _createdLeagueId;
  String? _createdInviteCode;
  Timer? _coachRetryTimer;

  @override
  void initState() {
    super.initState();
    _roundCount = _defaultFantasyRoundCount(isSoccer: widget.isSoccer);
    unawaited(_refreshRoundCount());
    _scheduleCreateLeagueCoachMarks();
  }

  @override
  void dispose() {
    _coachRetryTimer?.cancel();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  String get _coachStorageKey =>
      'create_league.coachmarks.${widget.isSoccer ? 'soccer' : 'baseball'}.v3';

  List<GlobalKey> get _coachKeys => [
    _leagueNameCoachKey,
    _teamCountCoachKey,
    _draftDateCoachKey,
    _inviteCoachKey,
    _createButtonCoachKey,
  ];

  void _scheduleCreateLeagueCoachMarks({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_maybeStartCreateLeagueCoachMarks(force: force));
    });
  }

  void _retryCreateLeagueCoachMarks({bool force = false}) {
    _coachRetryTimer?.cancel();
    _coachRetryTimer = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      unawaited(_maybeStartCreateLeagueCoachMarks(force: force));
    });
  }

  Future<void> _maybeStartCreateLeagueCoachMarks({bool force = false}) async {
    if (!mounted || _isMyPageOpen) {
      _retryCreateLeagueCoachMarks(force: force);
      return;
    }
    if (!force) {
      final seen = await _readLocalStateCache(_coachStorageKey);
      if (seen == '1') return;
    }
    if (!mounted) return;

    try {
      final showcase = ShowcaseView.get();
      final ready = _coachKeys.every(showcase.isTargetRendered);
      if (!ready) {
        _retryCreateLeagueCoachMarks(force: force);
        return;
      }
      if (showcase.isShowcaseRunning) return;
      await _writeLocalStateCache(_coachStorageKey, '1');
      if (!mounted) return;
      showcase.startShowCase(
        _coachKeys,
        delay: const Duration(milliseconds: 240),
      );
    } catch (error, stackTrace) {
      debugPrint('CreateLeague coach marks failed: $error');
      debugPrint('$stackTrace');
      _retryCreateLeagueCoachMarks(force: force);
    }
  }

  void _replayCreateLeagueCoachMarks() {
    _coachRetryTimer?.cancel();
    _appBarKey.currentState?.closeSearch();
    try {
      final showcase = ShowcaseView.get();
      if (showcase.isShowcaseRunning) {
        showcase.dismiss();
      }
    } catch (_) {}
    setState(() => _isMyPageOpen = false);
    _scheduleCreateLeagueCoachMarks(force: true);
  }

  DateTime _maxDraftDate(DateTime now) {
    final defaultMax = now.add(const Duration(days: 180));
    if (widget.isSoccer) return defaultMax;

    final seasonEnd = DateTime(2026, 9, 6, 23, 59);
    if (seasonEnd.isBefore(now)) return defaultMax;
    return seasonEnd.isBefore(defaultMax) ? seasonEnd : defaultMax;
  }

  Future<void> _refreshRoundCount() async {
    if (widget.isSoccer) {
      await _loadCachedKLeagueLeagueData();
    }
    if (!mounted) return;
    setState(() {
      _roundCount = _defaultFantasyRoundCount(
        isSoccer: widget.isSoccer,
        draftAt: _draftDateTime,
      );
    });
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final maxDraftDate = _maxDraftDate(now);
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
                  maximumDate: maxDraftDate,
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
      setState(() => _draftDateTime = temp);
      await _refreshRoundCount();
    } else {
      final date = await showDatePicker(
        context: context,
        initialDate: now.add(const Duration(days: 1)),
        firstDate: now,
        lastDate: maxDraftDate,
      );
      if (date == null) return;
      if (!mounted) return;
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
      await _refreshRoundCount();
    }
  }

  Future<({String leagueId, String inviteCode})?> _ensureLeagueCreated() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('리그 이름을 입력해 주세요.')));
      return null;
    }
    if (_draftDateTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('드래프트 날짜와 시간을 선택해 주세요.')));
      return null;
    }

    if ((_createdLeagueId ?? '').isNotEmpty &&
        (_createdInviteCode ?? '').isNotEmpty) {
      return (leagueId: _createdLeagueId!, inviteCode: _createdInviteCode!);
    }

    if (widget.isSoccer) {
      await _loadCachedKLeagueLeagueData();
    }

    final resolvedRoundCount = _defaultFantasyRoundCount(
      isSoccer: widget.isSoccer,
      draftAt: _draftDateTime,
    );

    setState(() => _creating = true);
    try {
      final leagueId = await LeagueService.instance.createLeague(
        _nameCtrl.text.trim(),
        isSoccer: widget.isSoccer,
        teamCount: _teamCount,
        roundCount: resolvedRoundCount,
        draftDateTime: _draftDateTime,
      );
      final inviteCode = leagueId.substring(0, 6).toUpperCase();
      if (mounted) {
        setState(() {
          _createdLeagueId = leagueId;
          _createdInviteCode = inviteCode;
        });
      } else {
        _createdLeagueId = leagueId;
        _createdInviteCode = inviteCode;
      }
      return (leagueId: leagueId, inviteCode: inviteCode);
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('리그 생성 실패: $e')));
      return null;
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _createLeague() async {
    final created = await _ensureLeagueCreated();
    if (created == null || !mounted) return;

    Navigator.pop(
      context,
      _DraftResult(
        leagueName: _nameCtrl.text.trim(),
        when: _draftDateTime!,
        isSoccer: widget.isSoccer,
      ),
    );
  }

  Future<void> _copyInviteLink() async {
    final created = await _ensureLeagueCreated();
    if (created == null || !mounted) return;

    final inviteLink = 'leagueit://join?code=${created.inviteCode}';
    await Clipboard.setData(ClipboardData(text: inviteLink));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('초대 링크가 복사되었습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    const actionGreen = Color(0xFF49B75C);
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
              onHelpTap: _replayCreateLeagueCoachMarks,
              showSearch: false,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isSoccer ? 'K리그 판타지리그 생성' : 'KBO 판타지리그 생성',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildLeagueItCoachMark(
                    context: context,
                    showcaseKey: _leagueNameCoachKey,
                    title: '리그 이름',
                    description:
                        '생성하게 되는 판타지리그의 이름이 됩니다.',
                    targetBorderRadius: BorderRadius.circular(18),
                    tooltipPosition: TooltipPosition.bottom,
                    badge: 'CREATE LEAGUE',
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'League Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildLeagueItCoachMark(
                    context: context,
                    showcaseKey: _teamCountCoachKey,
                    title: '팀 수 선택',
                    description:
                        '리그 참가 인원에 맞춰 팀 수를 정합니다. 드래프트 자리 수도 이 설정을 기준으로 만들어집니다.',
                    targetBorderRadius: BorderRadius.circular(18),
                    tooltipPosition: TooltipPosition.bottom,
                    badge: 'CREATE LEAGUE',
                    child: DropdownButtonFormField<int>(
                      initialValue: _teamCount,
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
                  ),
                  const SizedBox(height: 16),

                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Rounds',
                      helperText: widget.isSoccer
                          ? '드래프트 날짜 기준으로 자동 계산됩니다. 총 33라운드 기준입니다.'
                          : '드래프트 날짜 기준으로 자동 계산됩니다.',
                      border: const OutlineInputBorder(),
                    ),
                    child: Text(
                      widget.isSoccer
                          ? '${_roundCount ?? _kLeagueFantasyTotalRounds2026} Round'
                          : '${_roundCount ?? _kboFantasyTotalRounds2026} Round',
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildLeagueItCoachMark(
                    context: context,
                    showcaseKey: _draftDateCoachKey,
                    title: '드래프트 일정',
                    description:
                        '드래프트 날짜와 시간을 정하면 시즌 라운드 수가 자동 계산됩니다.',
                    targetBorderRadius: BorderRadius.circular(999),
                    tooltipPosition: TooltipPosition.bottom,
                    badge: 'CREATE LEAGUE',
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        _draftDateTime == null
                            ? '드래프트 날짜 & 시간 선택'
                            : '${_draftDateTime!.month}/${_draftDateTime!.day} '
                                  '${_draftDateTime!.hour.toString().padLeft(2, '0')}:${_draftDateTime!.minute.toString().padLeft(2, '0')}',
                      ),
                      onPressed: _pickDateTime,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    '초대',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildLeagueItCoachMark(
                    context: context,
                    showcaseKey: _inviteCoachKey,
                    title: '초대 링크',
                    description:
                        '리그를 생성하기 전 초대 링크를 복사해 참가자들에게 보내세요.',
                    targetBorderRadius: BorderRadius.circular(999),
                    tooltipPosition: TooltipPosition.top,
                    badge: 'CREATE LEAGUE',
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _creating ? null : _copyInviteLink,
                        child: const Text('초대 링크 복사'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildLeagueItCoachMark(
                    context: context,
                    showcaseKey: _createButtonCoachKey,
                    title: '리그 생성 완료',
                    description:
                        '필수 항목을 입력한 뒤 이 버튼으로 리그를 생성합니다. 완료되면 드래프트 정보와 초대 흐름이 이어집니다.',
                    targetBorderRadius: BorderRadius.circular(999),
                    tooltipPosition: TooltipPosition.top,
                    badge: 'CREATE LEAGUE',
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: actionGreen,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: actionGreen.withValues(
                            alpha: 0.45,
                          ),
                          disabledForegroundColor: Colors.white70,
                        ),
                        onPressed: _creating ? null : _createLeague,
                        child: _creating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('리그 생성'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

class _DraftResult {
  final String leagueName;
  final DateTime when;
  final bool isSoccer;
  const _DraftResult({
    required this.leagueName,
    required this.when,
    required this.isSoccer,
  });
}
