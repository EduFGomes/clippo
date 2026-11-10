import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:clippo/core/camera/clippo_camera.dart';
import 'package:clippo/core/data/friendship.dart';
import 'package:clippo/core/data/session.dart';
import 'package:clippo/core/data/sessions_repository.dart';
import 'package:clippo/core/format/clippo_format.dart';
import 'package:clippo/core/gesture/gesture_pipeline.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/upload/upload_queue.dart';
import 'package:clippo/core/validation/input_validation.dart';
import 'package:clippo/core/widgets/clippo_back_button.dart';
import 'package:clippo/core/widgets/clippo_capture_chip.dart';
import 'package:clippo/core/widgets/clippo_capture_toast.dart';
import 'package:clippo/core/widgets/clippo_ghost_button.dart';
import 'package:clippo/core/widgets/clippo_icon.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_pulse_dot.dart';
import 'package:clippo/core/widgets/clippo_record_button.dart';
import 'package:clippo/core/widgets/clippo_screen_ground.dart';
import 'package:clippo/core/widgets/clippo_screen_title.dart';
import 'package:clippo/core/widgets/clippo_text_button.dart';
import 'package:clippo/core/widgets/clippo_text_field.dart';

/// 🟡 TEMPORÁRIO (FASE DE TESTES): copia cada highlight salvo na Gravação para a galeria do celular
/// (álbum Clippo), para assistir aos vídeos enquanto o Player real e o upload (R13) não estão ligados.
/// Para desligar sem mexer no código: `--dart-define=COPY_TO_GALLERY=false`.
const bool copyCapturedHighlightsToGallery = bool.fromEnvironment('COPY_TO_GALLERY', defaultValue: true);

/// Os amigos aceitos (R10, R15) a partir das amizades de `friendsRepository.watchFriendships()`:
/// é o que alimenta os chips "Gravar com" e o "+ adicionar".
Stream<List<Friend>> acceptedFriends(Stream<List<Friendship>> friendships) => friendships.map(
      (list) => [
        for (final f in list)
          if (f.isAccepted && f.other.uid.isNotEmpty) f.other,
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
    );

/// Highlight salvo localmente durante a gravação (R13).
class CapturedHighlight {
  const CapturedHighlight({required this.clip, required this.offset});

  final SavedClip clip;
  final Duration offset;

  /// Converte o clipe salvo localmente num [PendingHighlight] para o [SessionsRepository.saveSession].
  PendingHighlight toPendingHighlight({required int position, int? maxOffsetSeconds}) {
    final fileName = clip.path.split('/').last.replaceAll(RegExp(r'\.mp4$', caseSensitive: false), '');
    final highlightId = validateEntityId(fileName) == null
        ? fileName
        : 'lance-${position.toString().padLeft(4, '0')}';
    final safeDurationSeconds = clip.duration.inSeconds.clamp(1, highlightSecondsMax);
    final rawOffsetSeconds = offset.inSeconds < 0 ? 0 : offset.inSeconds;
    final safeOffsetSeconds = maxOffsetSeconds != null && rawOffsetSeconds > maxOffsetSeconds
        ? maxOffsetSeconds
        : rawOffsetSeconds;
    return PendingHighlight(
      highlightId: highlightId,
      localPath: clip.path,
      offset: Duration(seconds: safeOffsetSeconds),
      duration: Duration(seconds: safeDurationSeconds),
    );
  }
}

/// Os 4 estados da Gravação (glossário: preparing, recording, saved, finishing).
enum CaptureStep { preparing, recording, saved, finishing }

enum _CameraState { checking, needsPermission, starting, running, failed }

/// Fluxo de gravação em 4 estados que compartilham câmera, buffer e sessão (docs/produto.md › 4.5).
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    this.friends,
    this.camera = const ClippoCamera(),
    this.highlightLength = HighlightLength.standard,
    this.pipeline,
    this.preview,
    this.uploads,
    this.onOpenFriends,
    this.onSaved,
    this.onSessionCreated,
  });

  /// Os amigos aceitos do dono (veja [acceptedFriends]). Nulo ou vazio: só "Gravar sozinho".
  final Stream<List<Friend>>? friends;

  final ClippoCamera camera;

  /// Duração inicial do trecho salvo a cada gesto (R1: 15, 30, 45 ou 60 s; padrão 30 s).
  final Duration highlightLength;

  /// Injetado nos testes para simular disparos do gesto sem câmera física.
  final GesturePipeline? pipeline;

  /// Substitui a `AndroidView` da câmera nos testes e no preview de emulador.
  final WidgetBuilder? preview;

  /// Fila de envio (R13, D15): guarda a sessão no aparelho, chama o `saveSession` e sobe os
  /// vídeos. Nulo (catálogo, testes sem Firebase): a sessão só existe na memória.
  final UploadQueue? uploads;

  /// "Adicione amigos…" quando ainda não há nenhum: quem abriu a Gravação leva à tela Amigos.
  final VoidCallback? onOpenFriends;

  /// Chamado quando a sessão é confirmada e salva no Estado D.
  final VoidCallback? onSaved;

  /// Recebe a [Session] criada no Estado D (com os participantes).
  final ValueChanged<Session>? onSessionCreated;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  late final GesturePipeline _pipeline = widget.pipeline ?? GesturePipeline();
  StreamSubscription<GestureObservation>? _subscription;

  _CameraState _camera = _CameraState.checking;
  String? _error;
  bool _withSound = true;
  bool _micWarned = false;

  // Configurações do modo de gravação (menu no canto superior direito).
  late Duration _length = widget.highlightLength;
  VideoResolution _resolution = VideoResolution.hd720;
  bool _recordAudio = true;
  bool _soundOnSave = true;
  bool _flashOnSave = true;
  bool _vibrationOnSave = false;

  CaptureStep _step = CaptureStep.preparing;

  /// Amigos selecionados para a sessão no Estado D.
  final Set<String> _selectedFriends = {};

  /// Timestamp (relógio do sensor) do primeiro quadro gravado, usado para calcular o offset de cada highlight.
  Duration? _recordingStart;

  /// Horários de início e fim para preencher o resumo do Estado D.
  DateTime? _recordingStartTime;
  DateTime? _recordingEndTime;

  final List<CapturedHighlight> _highlights = [];

  bool _showControls = false;
  Timer? _controlsTimer;
  Timer? _toastTimer;
  String? _saveError;

  // Estado D: campos de confirmação da sessão.
  late final TextEditingController _nameController;
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;
  late final TextEditingController _locationController;
  String? _sessionId;
  String? _nameError;
  String? _timeError;
  String? _locationError;
  String? _participantsError;
  String? _formError;
  bool _saving = false;
  bool _addingFriend = false;

  /// Amigos aceitos, como chegaram do Firestore.
  List<Friend> _friends = const [];
  StreamSubscription<List<Friend>>? _friendsSubscription;

  List<Friend> get _unselectedFriends =>
      _friends.where((f) => !_selectedFriends.contains(f.uid)).toList(growable: false);

  void _listenToFriends() {
    _friendsSubscription = widget.friends?.listen(
      (friends) {
        if (!mounted) return;
        setState(() {
          _friends = friends;
          // Quem deixou de ser amigo não pode continuar na sessão (R10).
          _selectedFriends.retainAll({for (final f in friends) f.uid});
        });
      },
      // Sem amigos carregados (ex.: sem internet e nada no cache): grava sozinho.
      onError: (Object _) {},
    );
  }

  @override
  void initState() {
    super.initState();
    _listenToFriends();
    final now = DateTime.now();
    _nameController = TextEditingController(text: _defaultSessionName(now));
    _dateController = TextEditingController(text: clippoDate(now));
    _timeController = TextEditingController(text: clippoTimeRange(now, now));
    _locationController = TextEditingController(text: 'Quadra local (GPS)');
    _loadSavedSettings();
    _checkPermission();
  }

  Future<void> _loadSavedSettings() async {
    try {
      final saved = await widget.camera.loadSettings();
      if (!mounted) return;
      setState(() {
        _length = saved.length;
        _resolution = saved.resolution;
        _recordAudio = saved.recordAudio;
        _soundOnSave = saved.soundOnSave;
        _flashOnSave = saved.flashOnSave;
        _vibrationOnSave = saved.vibrationOnSave;
      });
    } catch (_) {}
  }

  void _persistSettings() {
    widget.camera.saveSettings(CaptureSettings(
      length: _length,
      resolution: _resolution,
      recordAudio: _recordAudio,
      soundOnSave: _soundOnSave,
      flashOnSave: _flashOnSave,
      vibrationOnSave: _vibrationOnSave,
    )).catchError((Object _) {});
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _toastTimer?.cancel();
    _subscription?.cancel();
    _friendsSubscription?.cancel();
    _nameController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _locationController.dispose();
    widget.camera.stop().catchError((Object _) {});
    super.dispose();
  }

  static String _defaultSessionName(DateTime date) {
    const days = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];
    return 'Pelada de ${days[date.weekday - 1]}';
  }

  Future<void> _checkPermission() async {
    try {
      final granted = await widget.camera.hasPermission();
      if (!mounted) return;
      granted ? await _startCamera() : setState(() => _camera = _CameraState.needsPermission);
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _requestPermission() async {
    try {
      final granted = await widget.camera.requestPermission();
      if (!mounted) return;
      if (granted) {
        await _startCamera();
      } else {
        setState(() {
          _camera = _CameraState.needsPermission;
          _error = 'Se o Android não perguntar de novo, libere em Configurações › Apps › Clippo › Permissões.';
        });
      }
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _startCamera() async {
    setState(() {
      _camera = _CameraState.starting;
      _error = null;
    });
    _subscription?.cancel();
    _subscription = _pipeline.watch(widget.camera.poses).listen(_onObservation, onError: _fail);
    try {
      // Só a imagem, para enquadrar: a análise e o buffer ligam no "Gravar" (_startRecording).
      // Câmeras LIMITED (ex.: Galaxy A50) não abrem os três fluxos juntos.
      final withSound = await widget.camera.startPreview(recordAudio: _recordAudio);
      if (mounted) {
        setState(() {
          _camera = _CameraState.running;
          _withSound = withSound;
        });
      }
    } catch (e) {
      _fail(e);
    }
  }

  void _fail(Object error) {
    if (!mounted) return;
    setState(() {
      _camera = _CameraState.failed;
      _error = error is CameraFailure ? error.message : 'Algo deu errado.';
    });
  }

  void _toggleFriend(String id) {
    setState(() {
      _selectedFriends.contains(id) ? _selectedFriends.remove(id) : _selectedFriends.add(id);
      _participantsError = null;
    });
  }

  Future<void> _startRecording() async {
    // Reinicia a janela da pose para ignorar gestos feitos durante o posicionamento do celular.
    _pipeline.reset();
    setState(() {
      _step = CaptureStep.recording;
      _recordingStartTime = DateTime.now();
      _recordingStart = null;
      _showControls = false;
      _micWarned = true;
    });
    // A tela já ficou preta (R7): troca a imagem pela análise do gesto e pelo buffer.
    try {
      final withSound = await widget.camera.start(
        multiPerson: true,
        fullHd: _resolution.fullHd,
        recordAudio: _recordAudio,
        withPreview: false,
      );
      if (mounted) setState(() => _withSound = withSound);
    } catch (e) {
      if (!mounted || _step == CaptureStep.finishing) return;
      setState(() => _step = CaptureStep.preparing);
      _fail(e);
    }
  }

  void _onObservation(GestureObservation observation) {
    if (_step != CaptureStep.recording && _step != CaptureStep.saved) return;
    final at = observation.frame.timestamp;
    final start = _recordingStart ??= at;
    if (observation.triggered) _onGesture(until: at, offset: at - start);
  }

  /// Exibe o aviso imediatamente e delega o corte do MP4 em segundo plano para não bloquear a análise.
  void _onGesture({required Duration until, required Duration offset}) {
    _showToast(error: null);
    widget.camera.saveHighlight(until: until, length: _length).then((clip) {
      // Avisa quem está longe na quadra depois que o MP4 foi salvo (R2), conforme configurado.
      widget.camera
          .signalSaved(sound: _soundOnSave, flash: _flashOnSave, vibration: _vibrationOnSave)
          .catchError((Object _) {});
      _highlights.add(CapturedHighlight(clip: clip, offset: offset));
      // 🟡 TEMPORÁRIO (FASE DE TESTES): copia o MP4 para a galeria do celular depois de salvar (R2).
      // Remover quando o Player reproduzir o arquivo/URL real e o envio para o Storage (R13) estiver ativo.
      if (copyCapturedHighlightsToGallery) {
        widget.camera.copyToGallery(clip).catchError((Object _) {});
      }
    }).catchError((Object e) {
      if (mounted) _showToast(error: e is CameraFailure ? e.message : 'Não foi possível salvar o lance.');
    });
  }

  void _showToast({required String? error}) {
    _toastTimer?.cancel();
    setState(() {
      _step = CaptureStep.saved;
      _saveError = error;
    });
    _toastTimer = Timer(ClippoMotion.savedBanner, () {
      if (mounted && _step == CaptureStep.saved) setState(() => _step = CaptureStep.recording);
    });
  }

  /// Um toque na tela preta revela os controles de encerrar/cancelar por `stopControls`.
  void _revealControls() {
    _controlsTimer?.cancel();
    setState(() => _showControls = true);
    _controlsTimer = Timer(ClippoMotion.stopControls, () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  /// Menu de configurações do modo de gravação (tempo, resolução, microfone, bip, flash e vibração).
  Future<void> _openSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Theme(
          data: clippoTheme(Brightness.dark),
          child: StatefulBuilder(
            builder: (innerContext, setSheetState) {
              final colors = ClippoColors.of(innerContext);
              return Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(ClippoRadius.radiusField)),
                ),
                padding: const EdgeInsets.fromLTRB(
                  ClippoSpace.gutter,
                  ClippoSpace.spaceL,
                  ClippoSpace.gutter,
                  ClippoSpace.screenBottom,
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colors.line,
                              borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                            ),
                          ),
                        ),
                        const SizedBox(height: ClippoSpace.spaceL),
                        Text(
                          'Configurações da gravação',
                          style: ClippoText.titleS.copyWith(color: colors.text),
                        ),
                        const SizedBox(height: ClippoSpace.section),
                        Text(
                          'Tempo do highlight',
                          style: ClippoText.label.copyWith(color: colors.textLabel),
                        ),
                        const SizedBox(height: ClippoSpace.spaceS),
                        Wrap(
                          spacing: ClippoSpace.spaceS,
                          runSpacing: ClippoSpace.spaceS,
                          children: [
                            for (final option in HighlightLength.options)
                              ClippoCaptureChip(
                                label: '${option.inSeconds}s',
                                selected: _length == option,
                                onPressed: () {
                                  setState(() => _length = option);
                                  setSheetState(() {});
                                  _persistSettings();
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: ClippoSpace.spaceL),
                        Text(
                          'Resolução da imagem',
                          style: ClippoText.label.copyWith(color: colors.textLabel),
                        ),
                        const SizedBox(height: ClippoSpace.spaceS),
                        Wrap(
                          spacing: ClippoSpace.spaceS,
                          runSpacing: ClippoSpace.spaceS,
                          children: [
                            for (final res in VideoResolution.values)
                              ClippoCaptureChip(
                                label: res.label,
                                selected: _resolution == res,
                                onPressed: () {
                                  if (_resolution == res) return;
                                  setState(() => _resolution = res);
                                  setSheetState(() {});
                                  _persistSettings();
                                  _startCamera();
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: ClippoSpace.spaceL),
                        Text(
                          'Áudio e avisos ao salvar',
                          style: ClippoText.label.copyWith(color: colors.textLabel),
                        ),
                        const SizedBox(height: ClippoSpace.spaceS),
                        _settingToggle(
                          colors: colors,
                          title: 'Microfone',
                          subtitle: 'Gravar som do ambiente nos highlights',
                          value: _recordAudio && _withSound,
                          onChanged: (enabled) async {
                            if (enabled) {
                              final hasMic = await widget.camera.hasMicrophonePermission();
                              if (!hasMic) {
                                await widget.camera.requestMicrophonePermission();
                              }
                            }
                            if (!mounted) return;
                            setState(() => _recordAudio = enabled);
                            _persistSettings();
                            await _startCamera();
                            if (innerContext.mounted) setSheetState(() {});
                          },
                        ),
                        _settingToggle(
                          colors: colors,
                          title: 'Som (bip)',
                          subtitle: 'Aviso sonoro ao salvar um highlight',
                          value: _soundOnSave,
                          onChanged: (v) {
                            setState(() => _soundOnSave = v);
                            setSheetState(() {});
                            _persistSettings();
                          },
                        ),
                        _settingToggle(
                          colors: colors,
                          title: 'Flash',
                          subtitle: 'Piscar a lanterna ao salvar um highlight',
                          value: _flashOnSave,
                          onChanged: (v) {
                            setState(() => _flashOnSave = v);
                            setSheetState(() {});
                            _persistSettings();
                          },
                        ),
                        _settingToggle(
                          colors: colors,
                          title: 'Vibração',
                          subtitle: 'Vibrar o celular ao salvar um highlight',
                          value: _vibrationOnSave,
                          onChanged: (v) {
                            setState(() => _vibrationOnSave = v);
                            setSheetState(() {});
                            _persistSettings();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _settingToggle({
    required ClippoColors colors,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ClippoSpace.spaceXs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ClippoText.body.copyWith(color: colors.text)),
                Text(subtitle, style: ClippoText.label.copyWith(color: colors.textMuted)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: ClippoBrand.onWine,
            activeTrackColor: ClippoBrand.wine,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// Pede confirmação antes de cancelar ou descartar a sessão por segurança.
  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Theme(
          data: clippoTheme(Brightness.dark),
          child: Builder(
            builder: (innerContext) {
              final colors = ClippoColors.of(innerContext);
              return Dialog(
                backgroundColor: colors.surface,
                insetPadding: const EdgeInsets.symmetric(horizontal: ClippoSpace.gutter),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(ClippoSpace.cardPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(title, style: ClippoText.titleS.copyWith(color: colors.text)),
                      const SizedBox(height: ClippoSpace.spaceS),
                      Text(message, style: ClippoText.body.copyWith(color: colors.textMuted)),
                      const SizedBox(height: ClippoSpace.spaceL),
                      ClippoPrimaryButton(
                        label: confirmLabel,
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                      ),
                      const SizedBox(height: ClippoSpace.spaceS),
                      ClippoTextButton(
                        label: cancelLabel,
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _confirmCancelRecording() async {
    _controlsTimer?.cancel();
    final confirmed = await _confirmAction(
      title: 'Cancelar gravação?',
      message: 'Tem certeza que quer interromper a gravação atual?',
      confirmLabel: 'Sim, cancelar',
      cancelLabel: 'Continuar gravando',
    );
    if (!mounted) return;
    if (confirmed) {
      _toastTimer?.cancel();
      _discardHighlights();
      // De volta ao enquadramento: desliga a análise e o buffer e mostra a imagem de novo.
      _startCamera();
      setState(() {
        _step = CaptureStep.preparing;
        _showControls = false;
      });
    } else {
      setState(() => _showControls = false);
    }
  }

  void _finishSession() {
    _controlsTimer?.cancel();
    _toastTimer?.cancel();
    _recordingEndTime = DateTime.now();
    final start = _recordingStartTime ?? _recordingEndTime!;
    _dateController.text = clippoDate(start);
    _timeController.text = clippoTimeRange(start, _recordingEndTime!);
    _nameController.text = _defaultSessionName(start);
    widget.camera.stop().catchError((Object _) {});
    setState(() {
      _step = CaptureStep.finishing;
      _showControls = false;
      _addingFriend = false;
      _nameError = null;
      _timeError = null;
      _locationError = null;
      _participantsError = null;
      _formError = null;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final current = _recordingStartTime ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    final start = DateTime(picked.year, picked.month, picked.day, current.hour, current.minute);
    final end = _recordingEndTime != null
        ? DateTime(picked.year, picked.month, picked.day, _recordingEndTime!.hour, _recordingEndTime!.minute)
        : start;
    setState(() {
      _recordingStartTime = start;
      _recordingEndTime = end;
      _dateController.text = clippoDate(start);
      _timeError = null;
      _formError = null;
    });
  }

  Future<void> _pickTimeRange() async {
    final start = _recordingStartTime ?? DateTime.now();
    final end = _recordingEndTime ?? start;
    final pickedStart = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
    );
    if (pickedStart == null || !mounted) return;
    final pickedEnd = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(end),
    );
    if (pickedEnd == null || !mounted) return;
    final newStart = DateTime(start.year, start.month, start.day, pickedStart.hour, pickedStart.minute);
    final newEnd = DateTime(start.year, start.month, start.day, pickedEnd.hour, pickedEnd.minute);
    setState(() {
      _recordingStartTime = newStart;
      _recordingEndTime = newEnd;
      _timeController.text = clippoTimeRange(newStart, newEnd);
      _timeError = null;
      _formError = null;
    });
  }

  void _discardHighlights() {
    for (final h in _highlights) {
      widget.camera.deleteHighlight(h.clip).catchError((Object _) {});
    }
    _highlights.clear();
    _sessionId = null;
  }

  void _backToCamera() {
    _startCamera();
    setState(() => _step = CaptureStep.preparing);
  }

  Future<void> _confirmDiscardSession() async {
    final confirmed = await _confirmAction(
      title: 'Descartar sessão?',
      message: 'Os highlights salvos nesta sessão serão descartados.',
      confirmLabel: 'Sim, descartar',
      cancelLabel: 'Voltar',
    );
    if (!mounted || !confirmed) return;
    _discardHighlights();
    _startCamera();
    setState(() => _step = CaptureStep.preparing);
  }

  Future<void> _saveSession() async {
    if (_saving) return;
    final participantIds = _selectedFriends.toList(growable: false);
    final nameError = validateSessionName(_nameController.text);
    final locationError = validateLocation(_locationController.text);
    final participantsError = validateParticipantIds(participantIds);
    if (nameError != null || locationError != null || participantsError != null) {
      setState(() {
        _nameError = nameError;
        _locationError = locationError;
        _participantsError = participantsError;
        _formError = null;
      });
      return;
    }
    final normalizedName = normalizeSessionName(_nameController.text);
    final normalizedLocation = normalizeLocation(_locationController.text);
    _nameController.text = normalizedName;
    _locationController.text = normalizedLocation ?? '';

    final start = _recordingStartTime ?? DateTime.now();
    final rawEnd = _recordingEndTime ?? start;
    final effectiveEnd = rawEnd.isAtSameMomentAs(start)
        ? start.add(const Duration(minutes: 1))
        : rawEnd;
    final periodError = validateSessionPeriod(start, effectiveEnd);
    if (periodError != null) {
      setState(() {
        _timeError = periodError;
        _formError = null;
      });
      return;
    }

    final sessionId = _sessionId ??= 'sessao-${start.millisecondsSinceEpoch}';
    final uploads = widget.uploads;
    final ownerUid = uploads?.currentUid;
    if (uploads != null) {
      if (ownerUid == null) {
        setState(() => _formError = 'Entre na sua conta para salvar a sessão.');
        return;
      }
      setState(() {
        _saving = true;
        _formError = null;
      });
      try {
        // A fila guarda tudo no aparelho antes de tentar a rede (R13): sem internet, a
        // sessão continua aqui e sobe sozinha depois.
        await uploads.submit(QueuedSession(
          sessionId: sessionId,
          ownerUid: ownerUid,
          name: normalizedName,
          startedAt: start,
          endedAt: effectiveEnd,
          location: normalizedLocation,
          participantIds: participantIds,
          highlights: [
            for (var i = 0; i < _highlights.length; i++)
              QueuedHighlight.fromPending(_highlights[i].toPendingHighlight(
                position: i + 1,
                maxOffsetSeconds: effectiveEnd.difference(start).inSeconds,
              )),
          ],
        ));
      } on SessionsFailure catch (e) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _showFieldError(e);
        });
        return;
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _formError = 'Não foi possível salvar a sessão. Tente de novo.';
        });
        return;
      }
      if (!mounted) return;
      setState(() => _saving = false);
    }

    final rawDuration = effectiveEnd.difference(start);
    final duration = rawDuration.inMinutes >= 1 ? rawDuration : const Duration(minutes: 1);
    final owner = ownerUid ?? 'voce';
    final selectedParticipants = <SessionParticipant>[
      SessionParticipant(uid: owner, name: 'Você'),
      for (final friend in _friends)
        if (_selectedFriends.contains(friend.uid))
          SessionParticipant(
            uid: friend.uid,
            name: friend.name,
            username: friend.username,
            photoUrl: friend.photoUrl,
          ),
    ];

    final created = Session(
      id: sessionId,
      name: normalizedName,
      ownerId: owner,
      participantIds: [for (final p in selectedParticipants) p.uid],
      participants: selectedParticipants,
      participantCount: selectedParticipants.length,
      startedAt: start,
      endedAt: effectiveEnd,
      duration: duration,
      location: normalizedLocation == null ? null : SessionLocation(label: normalizedLocation),
      highlightCount: _highlights.length,
    );

    // Os MP4 agora são da fila: ela apaga cada um depois do `uploaded` (R13).
    _highlights.clear();
    _sessionId = null;
    widget.onSessionCreated?.call(created);
    widget.onSaved?.call();
    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(created);
      } else {
        _startCamera();
        setState(() => _step = CaptureStep.preparing);
      }
    }
  }

  /// Põe o erro do `saveSession` embaixo do campo que o servidor apontou ([SessionsFailure.code]).
  void _showFieldError(SessionsFailure e) {
    switch (e.code) {
      case 'name':
        _nameError = e.message;
      case 'location':
        _locationError = e.message;
      case 'startedAt' || 'endedAt':
        _timeError = e.message;
      case 'participantIds':
        _participantsError = e.message;
      default:
        _formError = e.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == CaptureStep.finishing) {
      return Theme(
        data: clippoTheme(Brightness.dark),
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _backToCamera();
          },
          child: _confirmSession(),
        ),
      );
    }
    final recording = _step == CaptureStep.recording || _step == CaptureStep.saved;
    return Theme(
      data: clippoTheme(Brightness.dark),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: ClippoBrand.captureBackground,
          systemNavigationBarColor: ClippoBrand.captureBackground,
        ),
        child: PopScope(
          // Durante a gravação, o "Voltar" do Android apenas revela os controles para evitar saída acidental.
          canPop: !recording,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _revealControls();
          },
          child: Scaffold(
            backgroundColor: ClippoBrand.captureBackground,
            body: Builder(
              builder: (context) => recording ? _standby() : _prepare(context),
            ),
          ),
        ),
      ),
    );
  }

  // ── Estado A: Preparar (minimalista) ─────────────────────────────────────

  Widget _prepare(BuildContext context) {
    return switch (_camera) {
      _CameraState.running => _framing(context),
      _CameraState.checking || _CameraState.starting => const Center(child: CircularProgressIndicator()),
      _CameraState.needsPermission => _message(
          'O Clippo precisa da câmera para gravar os lances.',
          ClippoPrimaryButton(label: 'Permitir câmera', onPressed: _requestPermission),
        ),
      _CameraState.failed => _message(
          _error ?? 'Algo deu errado.',
          ClippoPrimaryButton(label: 'Tentar de novo', onPressed: _checkPermission),
        ),
    };
  }

  Widget _message(String text, Widget action) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(ClippoSpace.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ClippoBackButton(),
            const Spacer(),
            Text(text, style: ClippoText.bodyL.copyWith(color: ClippoBrand.onWine), textAlign: TextAlign.center),
            if (_camera == _CameraState.needsPermission && _error != null) ...[
              const SizedBox(height: ClippoSpace.spaceM),
              Text(
                _error!,
                style: ClippoText.body.copyWith(color: ClippoBrand.captureTextMuted),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: ClippoSpace.section),
            action,
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _settingsButton(BuildContext context) {
    final colors = ClippoColors.of(context);
    return Semantics(
      button: true,
      label: 'Configurações da gravação',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openSettings,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: ClippoSize.minTouchTarget,
            minHeight: ClippoSize.minTouchTarget,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Container(
              width: ClippoSize.control,
              height: ClippoSize.control,
              decoration: BoxDecoration(color: colors.controlSoft, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: ClippoIcon(
                ClippoIconShape.sliders,
                size: ClippoSize.backIcon,
                color: colors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _framing(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.preview?.call(context) ?? const AndroidView(viewType: ClippoCamera.previewViewType),
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(ClippoSpace.gutter, ClippoSpace.spaceM, ClippoSpace.gutter, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const ClippoBackButton(),
                    _settingsButton(context),
                  ],
                ),
              ),
              if (_recordAudio && !_withSound && !_micWarned)
                Padding(
                  padding: const EdgeInsets.fromLTRB(ClippoSpace.gutter, ClippoSpace.spaceS, ClippoSpace.gutter, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ClippoSpace.spaceL,
                      vertical: ClippoSpace.spaceS,
                    ),
                    decoration: BoxDecoration(
                      color: ClippoBrand.captureOverlay,
                      borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                    ),
                    child: Text(
                      'Sem microfone · os highlights saem sem som',
                      style: ClippoText.label.copyWith(color: ClippoBrand.captureTextMuted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              const Spacer(),
              _recordWith(),
              const SizedBox(height: ClippoSpace.spaceL),
              Padding(
                padding: const EdgeInsets.only(bottom: ClippoSpace.screenBottom),
                child: Center(
                  child: ClippoRecordButton(
                    onPressed: _startRecording,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// "Gravar com": "Gravar sozinho" (padrão) e um chip por amigo aceito; dá para marcar vários
  /// (🟡 proposta em docs/produto.md › 4.5). Sem amigos, uma frase leva à tela Amigos.
  Widget _recordWith() {
    final alone = _selectedFriends.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ClippoSpace.gutter),
          child: Text('Gravar com', style: ClippoText.label.copyWith(color: ClippoBrand.captureTextMuted)),
        ),
        const SizedBox(height: ClippoSpace.spaceXs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: ClippoSpace.gutter),
          child: Row(
            children: [
              ClippoCaptureChip(
                label: 'Gravar sozinho',
                selected: alone,
                onPressed: alone ? null : () => setState(_selectedFriends.clear),
              ),
              for (final friend in _friends) ...[
                const SizedBox(width: ClippoSpace.spaceS),
                ClippoCaptureChip(
                  label: 'Com ${friend.firstName}',
                  selected: _selectedFriends.contains(friend.uid),
                  onPressed: () => _toggleFriend(friend.uid),
                ),
              ],
            ],
          ),
        ),
        if (_friends.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(ClippoSpace.gutter, ClippoSpace.spaceXs, ClippoSpace.gutter, 0),
            child: Semantics(
              button: widget.onOpenFriends != null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onOpenFriends,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: ClippoSize.minTouchTarget),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Para gravar com alguém, adicione seus amigos em ',
                            style: ClippoText.label.copyWith(color: ClippoBrand.captureTextMuted),
                          ),
                          TextSpan(
                            text: 'Amigos',
                            style: ClippoText.label.copyWith(
                              color: ClippoBrand.onWine,
                              decoration: TextDecoration.underline,
                              decorationColor: ClippoBrand.onWine,
                            ),
                          ),
                          TextSpan(
                            text: '.',
                            style: ClippoText.label.copyWith(color: ClippoBrand.captureTextMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Estados B e C: Gravando (standby) e Highlight salvo ──────────────────

  Widget _standby() {
    final saved = _step == CaptureStep.saved;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _revealControls,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: saved
                  ? ClippoCaptureToast(
                      title: _saveError ?? 'Highlight salvo',
                      detail: _saveError == null
                          ? 'últimos ${_length.inSeconds}s · gesto \\ o / detectado'
                          : null,
                      success: _saveError == null,
                    )
                  : const ClippoPulseDot(),
            ),
            if (_showControls)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ClippoSpace.gutter,
                    0,
                    ClippoSpace.gutter,
                    ClippoSpace.screenBottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClippoPrimaryButton.onWine(label: 'Encerrar sessão', onPressed: _finishSession),
                      const SizedBox(height: ClippoSpace.spaceM),
                      ClippoGhostButton(label: 'Cancelar gravação', onPressed: _confirmCancelRecording),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Estado D: Confirme a sessão ──────────────────────────────────────────

  Widget _confirmSession() {
    final colors = ClippoColors.of(context);
    final summary = clippoDotList([
      'Gravação encerrada',
      clippoHighlightCount(_highlights.length),
    ]);

    return ClippoScreenGround(
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_formError != null) ...[
            Text(
              _formError!,
              style: ClippoText.label.copyWith(color: colors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: ClippoSpace.spaceS),
          ],
          ClippoPrimaryButton(
            label: 'Salvar sessão',
            loading: _saving,
            onPressed: _saveSession,
          ),
          const SizedBox(height: ClippoSpace.spaceS),
          ClippoTextButton(
            label: 'Descartar',
            onPressed: _saving ? null : _confirmDiscardSession,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClippoBackButton(onPressed: _backToCamera),
              const SizedBox(width: ClippoSpace.spaceS),
              Flexible(
                child: GestureDetector(
                  onTap: _backToCamera,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'Voltar à câmera',
                    style: ClippoText.link.copyWith(color: colors.textMuted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ClippoSpace.spaceL),
          Text(
            summary,
            style: ClippoText.label.copyWith(
              color: colors.accent,
              fontFeatures: ClippoText.tabular,
            ),
          ),
          const SizedBox(height: ClippoSpace.spaceS),
          const ClippoScreenTitle(
            line1: 'Confirme a',
            line2: 'sessão.',
          ),
          const SizedBox(height: ClippoSpace.section),
          ClippoTextField(
            label: 'Nome da sessão',
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            errorText: _nameError,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          Row(
            children: [
              Expanded(
                child: ClippoTextField(
                  label: 'Data',
                  controller: _dateController,
                  readOnly: true,
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: ClippoSpace.spaceM),
              Expanded(
                child: ClippoTextField(
                  label: 'Horário',
                  controller: _timeController,
                  readOnly: true,
                  onTap: _pickTimeRange,
                  errorText: _timeError,
                ),
              ),
            ],
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          ClippoTextField(
            label: 'Local · sugerido por GPS',
            controller: _locationController,
            textCapitalization: TextCapitalization.words,
            errorText: _locationError,
            onChanged: (_) {
              if (_locationError != null) setState(() => _locationError = null);
            },
          ),
          const SizedBox(height: ClippoSpace.section),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ClippoSpace.spaceS),
            child: Text(
              'Participantes',
              style: ClippoText.label.copyWith(color: colors.textLabel),
            ),
          ),
          const SizedBox(height: ClippoSpace.spaceS),
          Wrap(
            spacing: ClippoSpace.spaceS,
            runSpacing: ClippoSpace.spaceS,
            children: [
              const ClippoCaptureChip(
                label: 'Você',
                selected: true,
                onPressed: null,
              ),
              for (final friend in _friends)
                if (_selectedFriends.contains(friend.uid))
                  ClippoCaptureChip(
                    label: friend.firstName,
                    selected: true,
                    onPressed: () => _toggleFriend(friend.uid),
                  ),
              if (_unselectedFriends.isNotEmpty)
                if (_addingFriend)
                  ..._unselectedFriends.map(
                    (f) => ClippoCaptureChip(
                      label: '+ ${f.firstName}',
                      selected: false,
                      onPressed: () {
                        _toggleFriend(f.uid);
                        setState(() => _addingFriend = false);
                      },
                    ),
                  )
                else
                  ClippoCaptureChip(
                    label: '+ adicionar',
                    selected: false,
                    onPressed: () => setState(() => _addingFriend = true),
                  ),
            ],
          ),
          if (_participantsError != null) ...[
            const SizedBox(height: ClippoSpace.spaceXs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ClippoSpace.spaceS),
              child: Text(
                _participantsError!,
                style: ClippoText.label.copyWith(color: colors.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
