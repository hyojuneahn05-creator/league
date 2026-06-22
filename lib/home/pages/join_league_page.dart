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
      Navigator.pop(
        context,
        _joinedDraftFromJoinLeagueResponse(data, fallbackCode: code),
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
    const actionGreen = Color(0xFF49B75C);
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
              '드래프트 화면에서 공유된 초대 코드를 입력하면 바로 리그에 참가할 수 있어요.',
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: actionGreen.withValues(alpha: 0.45),
                  disabledForegroundColor: Colors.white70,
                ),
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
