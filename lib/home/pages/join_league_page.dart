part of '../home_page.dart';

class JoinLeaguePage extends StatefulWidget {
  const JoinLeaguePage({super.key});

  @override
  State<JoinLeaguePage> createState() => _JoinLeaguePageState();
}

class _JoinLeaguePageState extends State<JoinLeaguePage> {
  final TextEditingController _codeCtrl = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('초대 코드를 입력해 주세요.')));
      return;
    }

    setState(() => _joining = true);
    try {
      final data = await LeagueService.instance.joinLeagueByInviteCode(code);
      if (!mounted) return;
      final draftTime = DateTime.tryParse('${data['draftDateTime'] ?? ''}');
      if (draftTime == null) {
        throw StateError('Draft 정보가 없는 리그입니다.');
      }
      Navigator.pop(
        context,
        _JoinedDraft(
          leagueId: '${data['leagueId'] ?? ''}',
          leagueName: '${data['leagueName'] ?? 'My League'}',
          when: draftTime.toLocal(),
          isSoccer: '${data['sport'] ?? 'soccer'}' == 'soccer',
          teamCount: data['teamCount'] is int
              ? data['teamCount'] as int
              : int.tryParse('${data['teamCount'] ?? 8}') ?? 8,
          memberCount: data['memberCount'] is int
              ? data['memberCount'] as int
              : int.tryParse('${data['memberCount'] ?? 1}') ?? 1,
          inviteCode: '${data['inviteCode'] ?? code}',
          ownerId: '${data['ownerId'] ?? ''}',
          draftOrder:
              (data['draftOrder'] as List<dynamic>? ?? const [])
                  .whereType<Map>()
                  .map(
                    (item) => _DraftOrderEntry(
                      uid: '${item['uid'] ?? ''}',
                      displayName: '${item['displayName'] ?? 'Team'}',
                      slot: item['slot'] is int
                          ? item['slot'] as int
                          : int.tryParse('${item['slot'] ?? 0}') ?? 0,
                    ),
                  )
                  .toList()
                ..sort((a, b) => a.slot.compareTo(b.slot)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('리그 참가 실패: $e')));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('리그 참가')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '초대 코드 입력',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Draft 화면에서 공유된 초대 코드를 입력하면 바로 리그에 참가할 수 있어요.',
              style: TextStyle(
                color: cs.onSurface.withOpacity(0.72),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeCtrl,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Invite Code',
                hintText: '예: A1B2C3',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final normalized = value.toUpperCase().replaceAll(' ', '');
                if (normalized == value) return;
                _codeCtrl.value = TextEditingValue(
                  text: normalized,
                  selection: TextSelection.collapsed(offset: normalized.length),
                );
              },
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surface.withOpacity(0.92),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.onSurface.withOpacity(0.08)),
              ),
              child: Text(
                '리그 정원이 모두 찬 경우에는 참가할 수 없습니다.',
                style: TextStyle(color: cs.onSurface.withOpacity(0.72)),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _joining ? null : _join,
                child: _joining
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Text('리그 참가'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
