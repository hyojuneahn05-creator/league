part of '../home_page.dart';

enum _PlayerFilter { all, GK, DF, MF, FW }

extension on _PlayerFilter {
  String get label {
    switch (this) {
      case _PlayerFilter.all:
        return 'All';
      case _PlayerFilter.GK:
        return 'GK';
      case _PlayerFilter.DF:
        return 'DF';
      case _PlayerFilter.MF:
        return 'MF';
      case _PlayerFilter.FW:
        return 'FW';
    }
  }

  String get name {
    switch (this) {
      case _PlayerFilter.all:
        return 'ALL';
      case _PlayerFilter.GK:
        return 'GK';
      case _PlayerFilter.DF:
        return 'DF';
      case _PlayerFilter.MF:
        return 'MF';
      case _PlayerFilter.FW:
        return 'FW';
    }
  }
}

class DraftPage extends StatefulWidget {
  final DateTime draftTime;
  final String leagueName;
  final bool isMock;
  const DraftPage({
    super.key,
    required this.draftTime,
    required this.leagueName,
    this.isMock = false,
  });

  @override
  State<DraftPage> createState() => _DraftPageState();
}

class _DraftPageState extends State<DraftPage> with TickerProviderStateMixin {
  static const int rounds = 18;
  static const int teams = 8;
  static const Duration pickTime = Duration(seconds: 90);

  late final List<String> _teamNames; // 랜덤 순서로 셔플된 팀
  late final List<_PlayerSlot> _playerPool;
  late final List<List<_PlayerSlot?>> _board; // [round][team]
  late final List<int> _order; // row-major, 셀 인덱스
  int _currentIndex = 0;

  Timer? _pickTimer;
  Duration _pickRemaining = pickTime;
  late final AnimationController _blinkController;
  late final ValueNotifier<String> _timeLabel;

  @override
  void initState() {
    super.initState();
    final rand = Random();
    _teamNames = List.generate(teams, (i) => 'Team ${i + 1}')..shuffle(rand);
    _playerPool = _buildPlayerPool(rand);
    _board =
        List.generate(rounds, (_) => List<_PlayerSlot?>.filled(teams, null));
    // 팀 순서만 랜덤, 픽 진행은 좌→우, 상→하
    _order = List<int>.generate(rounds * teams, (i) => i);

    _pickTimer = null;
    _timeLabel = ValueNotifier('0:00');
    _startPickTimer();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
      lowerBound: 0.25,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pickTimer?.cancel();
    _blinkController.dispose();
    _timeLabel.dispose();
    super.dispose();
  }

  String _ord(int n) {
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  void _startPickTimer() {
    _pickTimer?.cancel();
    _pickRemaining = pickTime;
    _updateTimeLabel();
    _pickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _pickRemaining -= const Duration(seconds: 1);
        _updateTimeLabel();
        if (_pickRemaining <= Duration.zero) {
          _advancePick();
        }
      });
    });
  }

  void _updateTimeLabel() {
    if (_pickRemaining.isNegative) {
      _timeLabel.value = '0:00';
      return;
    }
    final m = _pickRemaining.inMinutes;
    final s = (_pickRemaining.inSeconds % 60).toString().padLeft(2, '0');
    _timeLabel.value = '$m:$s';
  }

  void _advancePick() {
    if (_currentIndex < _order.length - 1) {
      setState(() => _currentIndex++);
      _startPickTimer();
    } else {
      _pickTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft 완료!')),
      );
      Navigator.pop(context);
    }
  }

  (int row, int col) _idxToPos(int idx) => (idx ~/ teams, idx % teams);

  bool _isCurrentCell(int row, int col) {
    final (r, c) = _idxToPos(_order[_currentIndex]);
    return r == row && c == col;
  }

  bool _isPicked(_PlayerSlot p) =>
      _board.any((round) => round.any((sel) => sel?.name == p.name));

  Future<void> _onCellTap(int row, int col) async {
    if (!_isCurrentCell(row, col)) return;
    final picked = await Navigator.push<_PlayerSlot>(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerSelectPage(
          available: _playerPool.where((p) => !_isPicked(p)).toList(),
          timeListenable: _timeLabel,
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _board[row][col] = picked;
      });
      _advancePick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (curRow, curCol) = _idxToPos(_order[_currentIndex]);
    final timeText = _pickRemaining.isNegative
        ? '0:00'
        : '${_pickRemaining.inMinutes}:${(_pickRemaining.inSeconds % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isMock ? '${widget.leagueName} Mock Draft' : '${widget.leagueName} Draft',
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            timeText,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final double rowHeight =
                    (constraints.maxHeight - 40) / (teams + 1); // header+rows
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowHeight: max(40, rowHeight),
                      dataRowMinHeight: max(48, rowHeight - 2),
                      dataRowMaxHeight: max(72, rowHeight + 10),
                      columnSpacing: 28,
                      columns: [
                        const DataColumn(label: Text('팀')),
                        for (int r = 0; r < rounds; r++)
                          DataColumn(label: Text(_ord(r + 1))),
                      ],
                      rows: List.generate(teams, (teamIdx) {
                        return DataRow(
                          cells: [
                            DataCell(Text(_teamNames[teamIdx])),
                            for (int r = 0; r < rounds; r++)
                              DataCell(
                                AnimatedBuilder(
                                  animation: _blinkController,
                                  builder: (context, _) {
                                    final active = _isCurrentCell(r, teamIdx);
                                    final bg = active
                                        ? cs.error
                                            .withOpacity(_blinkController.value * 0.35)
                                        : Colors.transparent;
                                    return Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.black54,
                                          width: 0.8,
                                        ),
                                        color: bg,
                                      ),
                                      child: Center(
                                        child: _board[r][teamIdx] == null
                                            ? const SizedBox.shrink()
                                            : Padding(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                ),
                                                child: Text(
                                                  _board[r][teamIdx]!.name,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                      ),
                                    );
                                  },
                                ),
                                onTap: () => _onCellTap(r, teamIdx),
                              ),
                          ],
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              '현재 픽: ${_teamNames[curCol]} · ${_ord(curRow + 1)} 라운드',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class PlayerSelectPage extends StatefulWidget {
  final List<_PlayerSlot> available;
  final ValueListenable<String> timeListenable;
  const PlayerSelectPage({
    super.key,
    required this.available,
    required this.timeListenable,
  });

  @override
  State<PlayerSelectPage> createState() => _PlayerSelectPageState();
}

class _PlayerSelectPageState extends State<PlayerSelectPage> {
  _PlayerFilter _filter = _PlayerFilter.all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.available.where((p) {
      final matchesFilter =
          _filter == _PlayerFilter.all || p.position == _filter.name;
      final matchesQuery =
          _query.isEmpty || p.name.toLowerCase().contains(_query.toLowerCase());
      return matchesFilter && matchesQuery;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Player'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: ValueListenableBuilder<String>(
                valueListenable: widget.timeListenable,
                builder: (_, v, __) => Text(
                  v,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: '선수 검색',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            children: _PlayerFilter.values.map((f) {
              final active = _filter == f;
              return ChoiceChip(
                label: Text(f.label),
                selected: active,
                onSelected: (_) => setState(() => _filter = f),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final p = filtered[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent.withOpacity(0.1),
                    child: Text(
                      p.position,
                      style: const TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ),
                  title: Text(p.name),
                  subtitle: Text('포지션: ${p.position}'),
                  trailing: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, p),
                    child: const Text('Draft'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
