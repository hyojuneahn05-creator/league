part of '../home_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isMyPageOpen = false;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _usernameController = TextEditingController();
  final FocusNode _usernameFocusNode = FocusNode();
  Timer? _usernameDebounce;
  File? _avatarFile;
  File? _pendingAvatarFile;
  bool _isLoadingAvatar = true;
  bool _isLoadingProfile = true;
  bool _isSavingProfile = false;
  String _savedUsername = '';
  String? _remoteAvatarUrl;
  int _usernameCheckToken = 0;
  _UsernameAvailabilityState _usernameState = _UsernameAvailabilityState.idle;
  String? _usernameMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreAvatar());
    unawaited(_loadProfile());
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _usernameController.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  void _toggleMyPage() => setState(() => _isMyPageOpen = !_isMyPageOpen);

  String _normalizeUsername(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  String _sanitizeUsername(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _usernameValidationMessage(String username) {
    if (username.isEmpty) return null;
    if (username.length < 2) {
      return '유저네임은 2자 이상이어야 합니다.';
    }
    if (username.contains('/')) {
      return '유저네임에는 / 문자를 사용할 수 없습니다.';
    }
    return null;
  }

  void _handleUsernameChanged(String rawValue) {
    final username = _sanitizeUsername(rawValue);
    _usernameDebounce?.cancel();
    if (username.isEmpty || username == _savedUsername) {
      setState(() {
        _usernameState = _UsernameAvailabilityState.idle;
        _usernameMessage = null;
      });
      return;
    }

    final validationMessage = _usernameValidationMessage(username);
    if (validationMessage != null) {
      setState(() {
        _usernameState = _UsernameAvailabilityState.invalid;
        _usernameMessage = validationMessage;
      });
      return;
    }

    final token = ++_usernameCheckToken;
    setState(() {
      _usernameState = _UsernameAvailabilityState.checking;
      _usernameMessage = null;
    });
    _usernameDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_checkUsernameAvailability(username, token));
    });
  }

  Future<void> _checkUsernameAvailability(String username, int token) async {
    final userUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('usernames')
          .doc(_normalizeUsername(username))
          .get();
      if (!mounted || token != _usernameCheckToken) return;
      final currentUsername = _sanitizeUsername(_usernameController.text);
      if (currentUsername != username) return;
      final reservedData = snapshot.data() ?? const <String, dynamic>{};
      final reservedUid = '${reservedData['uid'] ?? ''}';
      setState(() {
        if (snapshot.exists && reservedUid.isNotEmpty && reservedUid != userUid) {
          _usernameState = _UsernameAvailabilityState.unavailable;
          _usernameMessage = '이미 사용 중인 유저네임입니다.';
        } else {
          _usernameState = _UsernameAvailabilityState.available;
          _usernameMessage = '사용 가능한 유저네임입니다.';
        }
      });
    } catch (_) {
      if (!mounted || token != _usernameCheckToken) return;
      setState(() {
        _usernameState = _UsernameAvailabilityState.invalid;
        _usernameMessage = '유저네임 확인에 실패했습니다. 다시 시도해주세요.';
      });
    }
  }

  Future<bool> _ensureUsernameAvailableForSubmit(String username) async {
    if (username == _savedUsername) return true;
    final validationMessage = _usernameValidationMessage(username);
    if (validationMessage != null) {
      setState(() {
        _usernameState = _UsernameAvailabilityState.invalid;
        _usernameMessage = validationMessage;
      });
      return false;
    }
    if (_usernameState == _UsernameAvailabilityState.available) {
      return true;
    }
    if (_usernameState == _UsernameAvailabilityState.checking) {
      _usernameDebounce?.cancel();
      await _checkUsernameAvailability(username, _usernameCheckToken);
      return _usernameState == _UsernameAvailabilityState.available;
    }
    final token = ++_usernameCheckToken;
    setState(() {
      _usernameState = _UsernameAvailabilityState.checking;
      _usernameMessage = null;
    });
    await _checkUsernameAvailability(username, token);
    return _usernameState == _UsernameAvailabilityState.available;
  }

  Color _usernameBorderColor() {
    switch (_usernameState) {
      case _UsernameAvailabilityState.available:
        return const Color(0xFF2F8F5B);
      case _UsernameAvailabilityState.unavailable:
      case _UsernameAvailabilityState.invalid:
        return const Color(0xFFD74C4C);
      case _UsernameAvailabilityState.checking:
      case _UsernameAvailabilityState.idle:
        return const Color(0xFFD6DBD1);
    }
  }

  Color _usernameMessageColor() {
    switch (_usernameState) {
      case _UsernameAvailabilityState.available:
        return const Color(0xFF2F8F5B);
      case _UsernameAvailabilityState.unavailable:
      case _UsernameAvailabilityState.invalid:
        return const Color(0xFFD74C4C);
      case _UsernameAvailabilityState.checking:
      case _UsernameAvailabilityState.idle:
        return const Color(0xFF6B6C66);
    }
  }

  Widget? _usernameStatusIcon() {
    switch (_usernameState) {
      case _UsernameAvailabilityState.available:
        return const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF2F8F5B),
        );
      case _UsernameAvailabilityState.unavailable:
      case _UsernameAvailabilityState.invalid:
        return const Icon(
          Icons.cancel_rounded,
          color: Color(0xFFD74C4C),
        );
      case _UsernameAvailabilityState.checking:
      case _UsernameAvailabilityState.idle:
        return null;
    }
  }

  Future<void> _showMessageDialog({
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _isLoadingProfile = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snapshot.data() ?? const <String, dynamic>{};
      final username = _sanitizeUsername(
        '${data['displayName'] ?? user.displayName ?? ''}',
      );
      final photoUrl = '${data['photoUrl'] ?? ''}'.trim();
      unawaited(
        syncCurrentUserPublicProfileFromAuth(
          FirebaseFirestore.instance,
          displayNameOverride: username,
          normalizedDisplayNameOverride: _normalizeUsername(username),
          photoUrlOverride: photoUrl,
        ).catchError((error, stackTrace) {
          debugPrint('Profile public sync on load failed: $error');
          debugPrint('$stackTrace');
        }),
      );
      if (!mounted) return;
      setState(() {
        _savedUsername = username;
        _usernameController.text = username;
        _remoteAvatarUrl = photoUrl.isEmpty ? null : photoUrl;
        _isLoadingProfile = false;
        _usernameState = _UsernameAvailabilityState.idle;
        _usernameMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savedUsername = _sanitizeUsername(
          FirebaseAuth.instance.currentUser?.displayName ?? '',
        );
        _usernameController.text = _savedUsername;
        _remoteAvatarUrl = null;
        _isLoadingProfile = false;
        _usernameState = _UsernameAvailabilityState.idle;
        _usernameMessage = null;
      });
    }
  }

  Future<void> _restoreAvatar() async {
    try {
      await _ensureProfileAvatarPathLoaded();
      final storedPath = _profileAvatarPathNotifier.value;
      final file = storedPath == null || storedPath.isEmpty
          ? null
          : File(storedPath);
      final exists = file != null && await file.exists();
      if (!mounted) return;
      setState(() {
        _avatarFile = exists ? file : null;
        _isLoadingAvatar = false;
      });
      if (!exists && storedPath != null && storedPath.isNotEmpty) {
        await _persistProfileAvatarPath(null);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _avatarFile = null;
        _isLoadingAvatar = false;
      });
    }
  }

  String _avatarFileExtension(String path) {
    final normalized = path.trim();
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == normalized.length - 1) return '.jpg';
    final extension = normalized.substring(dotIndex).toLowerCase();
    return extension.length > 8 ? '.jpg' : extension;
  }

  Future<File> _persistAvatarFile(String sourcePath) async {
    final userUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    if (userUid.isEmpty) {
      throw StateError('로그인된 사용자 정보를 찾을 수 없습니다.');
    }
    final docsDir = await getApplicationDocumentsDirectory();
    final extension = _avatarFileExtension(sourcePath);
    final target = File('${docsDir.path}/profile_avatar_$userUid$extension');

    final previousPath = _profileAvatarPathNotifier.value;
    if (previousPath != null &&
        previousPath.isNotEmpty &&
        previousPath != target.path) {
      final previousFile = File(previousPath);
      if (await previousFile.exists()) {
        await previousFile.delete();
      }
    }

    final source = File(sourcePath);
    if (await target.exists()) {
      await target.delete();
    }
    final saved = await source.copy(target.path);
    await _persistProfileAvatarPath(saved.path, uid: userUid);
    return saved;
  }

  String _contentTypeForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.heic':
      case '.heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  Future<String> _uploadAvatarAndGetUrl(File avatarFile) async {
    final userUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    if (userUid.isEmpty) {
      throw StateError('로그인된 사용자 정보를 찾을 수 없습니다.');
    }
    final extension = _avatarFileExtension(avatarFile.path);
    final ref = firebase_storage.FirebaseStorage.instance
        .ref()
        .child('profile_avatars')
        .child(userUid)
        .child('avatar$extension');
    final metadata = firebase_storage.SettableMetadata(
      contentType: _contentTypeForExtension(extension),
    );
    await ref.putFile(avatarFile, metadata);
    return ref.getDownloadURL();
  }

  Future<void> _syncAvatarToProfile(File avatarFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final photoUrl = await _uploadAvatarAndGetUrl(avatarFile);
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    batch.set(firestore.collection('users').doc(user.uid), {
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(publicUserProfileRef(firestore, user.uid), {
      'uid': user.uid,
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
    await user.updatePhotoURL(photoUrl);
    _cachePublicProfileAvatarUrl(user.uid, photoUrl);
    if (!mounted) return;
    setState(() => _remoteAvatarUrl = photoUrl);
  }

  Future<void> _pickAvatar() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (picked != null) {
        setState(() {
          _pendingAvatarFile = File(picked.path);
        });
      }
    } on firebase_storage.FirebaseException catch (error) {
      if (!mounted) return;
      debugPrint(
        'Profile avatar storage failed: ${error.code} ${error.message}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 사진 저장 중 서버 오류가 발생했습니다.')),
      );
    } catch (error) {
      debugPrint('Profile avatar pick failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 불러올 수 없습니다. 설정에서 사진 접근 권한을 확인해주세요.')),
      );
    }
  }

  bool get _hasPendingAvatarChange => _pendingAvatarFile != null;

  bool get _hasPendingUsernameChange =>
      _sanitizeUsername(_usernameController.text) != _savedUsername;

  bool get _hasPendingProfileChanges =>
      _hasPendingAvatarChange || _hasPendingUsernameChange;

  Future<void> _saveUsernameChange(String rawUsername) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final normalizedUsername = _normalizeUsername(rawUsername);

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(user.uid);
    final publicUserRef = publicUserProfileRef(firestore, user.uid);
    final usernameRef = firestore
        .collection('usernames')
        .doc(normalizedUsername);

    try {
      await firestore.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        final currentData = userSnapshot.data() ?? const <String, dynamic>{};
        final currentUsername = _sanitizeUsername(
          '${currentData['displayName'] ?? user.displayName ?? ''}',
        );
        final currentNormalized =
            '${currentData['normalizedDisplayName'] ?? _normalizeUsername(currentUsername)}';
        final reservedSnapshot = await transaction.get(usernameRef);
        DocumentReference<Map<String, dynamic>>? oldUsernameRef;
        DocumentSnapshot<Map<String, dynamic>>? oldUsernameSnapshot;

        if (reservedSnapshot.exists) {
          final reservedData =
              reservedSnapshot.data() ?? const <String, dynamic>{};
          final reservedUid = '${reservedData['uid'] ?? ''}';
          if (reservedUid.isNotEmpty && reservedUid != user.uid) {
            throw _UsernameAlreadyTakenException();
          }
        }

        if (currentNormalized.isNotEmpty &&
            currentNormalized != normalizedUsername) {
          oldUsernameRef = firestore
              .collection('usernames')
              .doc(currentNormalized);
          oldUsernameSnapshot = await transaction.get(oldUsernameRef);
        }

        transaction.set(usernameRef, {
          'uid': user.uid,
          'displayName': rawUsername,
          'normalizedDisplayName': normalizedUsername,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        transaction.set(userRef, {
          'displayName': rawUsername,
          'normalizedDisplayName': normalizedUsername,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        transaction.set(publicUserRef, {
          'uid': user.uid,
          'displayName': rawUsername,
          'normalizedDisplayName': normalizedUsername,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (currentNormalized.isNotEmpty &&
            currentNormalized != normalizedUsername) {
          final oldUsernameData =
              oldUsernameSnapshot?.data() ?? const <String, dynamic>{};
          final oldReservedUid = '${oldUsernameData['uid'] ?? ''}';
          if (oldReservedUid == user.uid && oldUsernameRef != null) {
            transaction.delete(oldUsernameRef);
          }
        }
      });

      await user.updateDisplayName(rawUsername);
      await user.reload();
      await LeagueService.instance.renameFantasyTeamIdentity(
        teamName: rawUsername,
      );
      homeKey.currentState?.applyFantasyDisplayNameForUser(
        uid: user.uid,
        teamName: rawUsername,
      );
      if (mounted) {
        setState(() {
          _savedUsername = rawUsername;
          _usernameController.text = rawUsername;
          _usernameState = _UsernameAvailabilityState.idle;
          _usernameMessage = null;
        });
      }
      _usernameFocusNode.unfocus();
    } on _UsernameAlreadyTakenException {
      rethrow;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Profile username save firebase failed: ${error.code} ${error.message}',
      );
      debugPrint('$stackTrace');
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Profile username save failed: $error');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  Future<void> _saveAvatarChange(File selectedAvatar) async {
    final saved = await _persistAvatarFile(selectedAvatar.path);
    await _syncAvatarToProfile(saved);
    if (!mounted) return;
    setState(() {
      _avatarFile = saved;
      _pendingAvatarFile = null;
    });
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isSavingProfile) return;

    final rawUsername = _sanitizeUsername(_usernameController.text);
    final usernameChanged = rawUsername != _savedUsername;
    final pendingAvatar = _pendingAvatarFile;
    final avatarChanged = pendingAvatar != null;

    if (!usernameChanged && !avatarChanged) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장할 변경사항이 없습니다.')));
      return;
    }

    if (usernameChanged) {
      if (rawUsername.isEmpty) {
        await _showMessageDialog(
          title: '유저네임이 비어 있습니다',
          message: '유저네임을 입력한 뒤 다시 저장해주세요.',
        );
        return;
      }
      if (rawUsername.length < 2) {
        await _showMessageDialog(
          title: '유저네임이 너무 짧습니다',
          message: '유저네임은 2자 이상으로 설정해주세요.',
        );
        return;
      }
      if (rawUsername.contains('/')) {
        await _showMessageDialog(
          title: '사용할 수 없는 유저네임입니다',
          message: '유저네임에는 / 문자를 사용할 수 없습니다.',
        );
        return;
      }
      if (!await _ensureUsernameAvailableForSubmit(rawUsername)) {
        await _showMessageDialog(
          title: '유저네임을 확인해주세요',
          message: _usernameMessage ?? '다른 유저네임으로 다시 시도해주세요.',
        );
        return;
      }
    }

    setState(() => _isSavingProfile = true);

    var usernameSaved = false;
    var avatarSaved = false;
    try {
      if (usernameChanged) {
        await _saveUsernameChange(rawUsername);
        usernameSaved = true;
      }
      if (avatarChanged) {
        final avatarToSave = pendingAvatar;
        try {
          await _saveAvatarChange(avatarToSave);
          avatarSaved = true;
        } on firebase_storage.FirebaseException catch (error) {
          if (!mounted) return;
          final message = switch (error.code) {
            'unauthorized' => '프로필 사진은 선택되었지만 서버 업로드 권한이 없어 저장되지 않았습니다.',
            'object-not-found' =>
              'Firebase Storage 버킷 또는 업로드 객체를 찾지 못했습니다. 현재 프로젝트의 Storage 설정이 완료되지 않았을 가능성이 큽니다.',
            'bucket-not-found' =>
              'Firebase Storage 버킷이 아직 생성되지 않았습니다. Firebase Console에서 Storage를 먼저 시작해야 합니다.',
            _ => '프로필 사진 저장 중 서버 동기화에 실패했습니다.',
          };
          await _showMessageDialog(title: '프로필 사진 저장 실패', message: message);
          return;
        }
      }
      if (!mounted) return;
      final message = switch ((usernameSaved, avatarSaved)) {
        (true, true) => '유저네임과 프로필 사진이 저장되었습니다.',
        (true, false) => '유저네임이 저장되었습니다.',
        (false, true) => '프로필 사진이 저장되었습니다.',
        _ => '변경사항이 저장되었습니다.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on _UsernameAlreadyTakenException {
      if (mounted) {
        await _showMessageDialog(
          title: '이미 사용 중인 유저네임입니다',
          message: '이미 다른 유저가 사용하고 있습니다. 다른 유저네임으로 다시 시도해주세요.',
        );
      }
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        'Profile save firebase failed: ${error.code} ${error.message}',
      );
      debugPrint('$stackTrace');
      if (!mounted) return;
      final message = switch (error.code) {
        'permission-denied' => '저장 권한이 없어 실패했습니다. 서버 규칙을 확인해주세요.',
        _ => '잠시 후 다시 시도해주세요.',
      };
      await _showMessageDialog(title: '저장에 실패했습니다', message: message);
    } catch (error, stackTrace) {
      debugPrint('Profile save failed: $error');
      debugPrint('$stackTrace');
      if (mounted) {
        await _showMessageDialog(
          title: '저장에 실패했습니다',
          message: '잠시 후 다시 시도해주세요.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _leagueItSurfacePalette(context);
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.trim() ?? '';
    final previewAvatar = _pendingAvatarFile ?? _avatarFile;
    final canSave =
        !_isSavingProfile &&
        !_isLoadingProfile &&
        _hasPendingProfileChanges &&
        (!_hasPendingUsernameChange ||
            _usernameState == _UsernameAvailabilityState.available);

    return _OverlayScaffold(
      isMyPageOpen: _isMyPageOpen,
      onToggleMyPage: _toggleMyPage,
      title: 'LeagueIt',
      showSearch: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [palette.gradientTop, palette.gradientBottom],
              ),
              border: Border.all(color: palette.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: palette.isDark ? 0.28 : 0.07,
                  ),
                  blurRadius: 28,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'MY PROFILE',
                    style: TextStyle(
                      color: palette.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 132,
                          height: 132,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.accentSoft,
                            border: Border.all(
                              color: palette.chipBorder,
                              width: 1.5,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _isLoadingAvatar
                              ? Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: palette.accent,
                                    ),
                                  ),
                                )
                              : previewAvatar != null
                              ? Image.file(previewAvatar, fit: BoxFit.cover)
                              : (_remoteAvatarUrl?.isNotEmpty ?? false)
                              ? Image.network(
                                  _remoteAvatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                        Icons.person_rounded,
                                        size: 58,
                                        color: palette.accent,
                                      ),
                                )
                              : Icon(
                                  Icons.person_rounded,
                                  size: 58,
                                  color: palette.accent,
                                ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: palette.tileSurface,
                              shape: BoxShape.circle,
                              border: Border.all(color: palette.chipBorder),
                            ),
                            child: Icon(
                              Icons.photo_camera_outlined,
                              size: 18,
                              color: palette.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    _hasPendingAvatarChange
                        ? '저장 버튼을 누르면 사진이 적용됩니다.'
                        : '프로필 사진 변경',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: palette.mutedInk,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '유저네임',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _usernameController,
                            focusNode: _usernameFocusNode,
                            enabled: !_isLoadingProfile && !_isSavingProfile,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (canSave) {
                                unawaited(_saveProfile());
                              }
                            },
                            onChanged: _handleUsernameChanged,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: _isLoadingProfile
                                  ? '불러오는 중'
                                  : '2자 이상, 특수 문자 X',
                              hintStyle: TextStyle(
                                color: palette.mutedInk,
                                fontWeight: FontWeight.w600,
                              ),
                              prefixIcon: Icon(
                                Icons.person_outline_rounded,
                                color: palette.mutedInk,
                              ),
                              suffixIcon: _usernameStatusIcon(),
                              suffixIconConstraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 14,
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: _usernameBorderColor(),
                                  width: 1.2,
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: _usernameBorderColor(),
                                  width: 1.6,
                                ),
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: palette.ink,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 10, bottom: 6),
                          child: GestureDetector(
                            onTap: _isLoadingProfile || _isSavingProfile
                                ? null
                                : () => _usernameFocusNode.requestFocus(),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 24,
                              color: _usernameState ==
                                          _UsernameAvailabilityState.available
                                  ? const Color(0xFF2F8F5B)
                                  : (_usernameState ==
                                                  _UsernameAvailabilityState
                                                      .unavailable ||
                                              _usernameState ==
                                                  _UsernameAvailabilityState
                                                      .invalid)
                                  ? const Color(0xFFD74C4C)
                                  : palette.mutedInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_usernameMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _usernameMessage!,
                        style: TextStyle(
                          color: _usernameMessageColor(),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  decoration: BoxDecoration(
                    color: palette.tileSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: palette.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.mail_outline_rounded,
                        size: 18,
                        color: palette.mutedInk,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '이메일',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: palette.mutedInk,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              email.isEmpty ? '연결된 이메일이 없습니다.' : email,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: palette.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: canSave ? _saveProfile : null,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: palette.accent,
                      disabledBackgroundColor: palette.buttonDisabled,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: _isSavingProfile
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '저장',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  )
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              '프로필 사진과 유저네임을 수정할 수 있습니다.',
              style: TextStyle(
                color: palette.mutedInk,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsernameAlreadyTakenException implements Exception {}
