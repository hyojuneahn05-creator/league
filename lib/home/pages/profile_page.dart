part of '../home_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isMyPageOpen = false;
  final ImagePicker _picker = ImagePicker();
  File? _avatarFile;

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  Future<void> _pickAvatar() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (picked != null) {
        setState(() => _avatarFile = File(picked.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 불러올 수 없습니다. 설정에서 사진 접근 권한을 확인해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      title: 'LeagueIt',
      showSearch: false,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _pickAvatar,
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: cs.primary.withOpacity(0.15),
                  backgroundImage:
                      _avatarFile != null ? FileImage(_avatarFile!) : null,
                  child: _avatarFile == null
                      ? Icon(
                          Icons.camera_alt_outlined,
                          color: cs.primary,
                          size: 28,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '프로필 사진',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '탭해서 변경',
                    style: TextStyle(
                      color: cs.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _ProfileField(label: '이름'),
          const _ProfileField(label: '닉네임'),
          const _ProfileField(label: '이메일'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  const _ProfileField({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
