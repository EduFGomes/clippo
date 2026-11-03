import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:clippo/core/camera/clippo_camera.dart';
import 'package:clippo/core/format/clippo_format.dart';
import 'package:clippo/core/gesture/gesture_pipeline.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/validation/input_validation.dart';
import 'package:clippo/core/widgets/clippo_back_button.dart';
import 'package:clippo/core/widgets/clippo_capture_chip.dart';
import 'package:clippo/core/widgets/clippo_capture_toast.dart';
import 'package:clippo/core/widgets/clippo_ghost_button.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_pulse_dot.dart';
import 'package:clippo/core/widgets/clippo_record_button.dart';
import 'package:clippo/core/widgets/clippo_screen_ground.dart';
import 'package:clippo/core/widgets/clippo_screen_title.dart';
import 'package:clippo/core/widgets/clippo_text_button.dart';
import 'package:clippo/core/widgets/clippo_text_field.dart';

/// Amigo disponível nos chips de participantes da sessão ("Com `firstName`").
/// 🟡 Provisório até existir o repositório de amigos em `core/data/`.
class CaptureFriend {
  const CaptureFriend({required this.id, required this.firstName});

  final String id;
  final String firstName;
}

/// Highlight salvo localmente durante a gravação (R13).
class CapturedHighlight {
  const CapturedHighlight({required this.clip, required this.offset});

  final SavedClip clip;
  final Duration offset;
}

/// Os 4 estados da Gravação (glossário: preparing, recording, saved, finishing).
enum CaptureStep { preparing, recording, saved, finishing }

enum _CameraState { checking, needsPermission, starting, running, failed }

/// Fluxo de gravação em 4 estados que compartilham câmera, buffer e sessão (docs/produto.md › 4.5).
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    this.friends = const [],
    this.camera = const ClippoCamera(),
    this.pipeline,
    this.preview,
    this.onSaved,
  });

  final List<CaptureFriend> friends;
  final ClippoCamera camera;

  /// Injetado nos testes para simular disparos do gesto sem câmera física.
  final GesturePipeline? pipeline;

  /// Substitui a `AndroidView` da câmera nos testes e no preview de emulador.
  final WidgetBuilder? preview;

  /// Chamado quando a sessão é confirmada e salva no Estado D.
  final VoidCallback? onSaved;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  late final GesturePipeline _pipeline = widget.pipeline ?? GesturePipeline();
  StreamSubscription<GestureObservation>? _subscription;

  _CameraState _camera = _CameraState.checking;
  String? _error;

  CaptureStep _step = CaptureStep.preparing;

  /// Amigos selecionados para a sessão. Vazio = "Gravar sozinho".
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
  String? _nameError;
  String? _locationError;
  bool _addingFriend = false;

  List<CaptureFriend> get _unselectedFriends =>
      widget.friends.where((f) => !_selectedFriends.contains(f.id)).toList(growable: false);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _nameController = TextEditingController(text: _defaultSessionName(now));
    _dateController = TextEditingController(text: clippoDate(now));
    _timeController = TextEditingController(text: clippoTimeRange(now, now));
    _locationController = TextEditingController(text: 'Quadra local (GPS)');
    _checkPermission();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _toastTimer?.cancel();
    _subscription?.cancel();
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
      await widget.camera.start(multiPerson: true);
      if (mounted) setState(() => _camera = _CameraState.running);
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
    setState(() => _selectedFriends.contains(id) ? _selectedFriends.remove(id) : _selectedFriends.add(id));
  }

  void _startRecording() {
    // Reinicia a janela da pose para ignorar gestos feitos durante o posicionamento do celular.
    _pipeline.reset();
    setState(() {
      _step = CaptureStep.recording;
      _recordingStartTime = DateTime.now();
      _recordingStart = null;
      _showControls = false;
    });
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
    widget.camera.saveHighlight(until: until).then((clip) {
      _highlights.add(CapturedHighlight(clip: clip, offset: offset));
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
      _locationError = null;
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
    });
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
    _highlights.clear();
    _startCamera();
    setState(() => _step = CaptureStep.preparing);
  }

  void _saveSession() {
    final nameError = validateSessionName(_nameController.text);
    final locationError = validateSessionLocation(_locationController.text);
    if (nameError != null || locationError != null) {
      setState(() {
        _nameError = nameError;
        _locationError = locationError;
      });
      return;
    }
    _nameController.text = normalizeSessionName(_nameController.text);
    _locationController.text = normalizeSessionLocation(_locationController.text);
    widget.onSaved?.call();
    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        _highlights.clear();
        _startCamera();
        setState(() => _step = CaptureStep.preparing);
      }
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
            body: recording ? _standby() : _prepare(),
          ),
        ),
      ),
    );
  }

  // ── Estado A: Preparar ───────────────────────────────────────────────────

  Widget _prepare() {
    return switch (_camera) {
      _CameraState.running => _framing(),
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

  Widget _framing() {
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
                  children: [
                    const ClippoBackButton(),
                    const SizedBox(width: ClippoSpace.spaceM),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ClippoSpace.spaceL,
                          vertical: ClippoSpace.spaceM,
                        ),
                        decoration: BoxDecoration(
                          color: ClippoBrand.captureOverlay,
                          borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                        ),
                        child: Text(
                          'Apoie o celular e enquadre o campo',
                          style: ClippoText.label.copyWith(color: ClippoBrand.onWine),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                color: ClippoBrand.captureOverlay,
                padding: const EdgeInsets.only(top: ClippoSpace.spaceL, bottom: ClippoSpace.screenBottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: ClippoSpace.gutter),
                      child: Text('Gravar com', style: ClippoText.label.copyWith(color: ClippoBrand.captureTextMuted)),
                    ),
                    SizedBox(
                      height: ClippoSize.minTouchTarget * MediaQuery.textScalerOf(context).scale(1),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: ClippoSpace.gutter),
                        children: [
                          ClippoCaptureChip(
                            label: 'Gravar sozinho',
                            selected: _selectedFriends.isEmpty,
                            onPressed: () => setState(_selectedFriends.clear),
                          ),
                          for (final friend in widget.friends) ...[
                            const SizedBox(width: ClippoSpace.spaceS),
                            ClippoCaptureChip(
                              label: 'Com ${friend.firstName}',
                              selected: _selectedFriends.contains(friend.id),
                              onPressed: () => _toggleFriend(friend.id),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: ClippoSpace.section),
                    Center(
                      child: ClippoRecordButton(
                        caption: 'Iniciar detecção de gesto \\ o /',
                        onPressed: _startRecording,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                      detail: _saveError == null ? 'últimos 30s · gesto \\ o / detectado' : null,
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
          ClippoPrimaryButton(
            label: 'Salvar sessão',
            onPressed: _saveSession,
          ),
          const SizedBox(height: ClippoSpace.spaceS),
          ClippoTextButton(
            label: 'Descartar',
            onPressed: _confirmDiscardSession,
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
              for (final friend in widget.friends)
                if (_selectedFriends.contains(friend.id))
                  ClippoCaptureChip(
                    label: friend.firstName,
                    selected: true,
                    onPressed: () => _toggleFriend(friend.id),
                  ),
              if (_unselectedFriends.isNotEmpty)
                if (_addingFriend)
                  ..._unselectedFriends.map(
                    (f) => ClippoCaptureChip(
                      label: '+ ${f.firstName}',
                      selected: false,
                      onPressed: () {
                        _toggleFriend(f.id);
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
        ],
      ),
    );
  }
}
