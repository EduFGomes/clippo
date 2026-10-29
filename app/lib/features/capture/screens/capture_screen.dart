import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:clippo/core/camera/clippo_camera.dart';
import 'package:clippo/core/gesture/gesture_pipeline.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_back_button.dart';
import 'package:clippo/core/widgets/clippo_capture_chip.dart';
import 'package:clippo/core/widgets/clippo_capture_toast.dart';
import 'package:clippo/core/widgets/clippo_ghost_button.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_pulse_dot.dart';
import 'package:clippo/core/widgets/clippo_record_button.dart';
import 'package:clippo/core/widgets/placeholder_screen.dart';

/// Um amigo que pode entrar na sessão pelo chip "Com `nome`".
/// 🟡 Provisório até existir o repositório de amigos; aí a tela recebe o modelo de lá.
class CaptureFriend {
  const CaptureFriend({required this.id, required this.firstName});

  final String id;
  final String firstName;
}

/// Um highlight salvo nesta gravação, ainda só no aparelho (R13 cuida do envio).
class CapturedHighlight {
  const CapturedHighlight({required this.clip, required this.offset});

  final SavedClip clip;

  /// Momento do gesto desde o início da gravação ("00:12:40").
  final Duration offset;
}

/// Os 4 estados da Gravação (glossário: preparing, recording, saved, finishing).
enum CaptureStep { preparing, recording, saved, finishing }

enum _CameraState { checking, needsPermission, starting, running, failed }

/// Gravação: um fluxo com 4 estados que compartilham câmera, buffer e sessão em andamento
/// (docs/produto.md › 4.5). Ignora o tema claro/escuro.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    this.friends = const [],
    this.camera = const ClippoCamera(),
    this.pipeline,
    this.preview,
  });

  /// Amigos que aparecem nos chips "Com `nome`". Vazio: só "Gravar sozinho".
  final List<CaptureFriend> friends;

  final ClippoCamera camera;

  /// Só para testes: uma detecção de mentira.
  final GesturePipeline? pipeline;

  /// Só para testes: a imagem da câmera é uma platform view, que não existe no teste.
  final WidgetBuilder? preview;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  late final GesturePipeline _pipeline = widget.pipeline ?? GesturePipeline();
  StreamSubscription<GestureObservation>? _subscription;

  _CameraState _camera = _CameraState.checking;
  String? _error;

  CaptureStep _step = CaptureStep.preparing;

  /// 🟡 Vários amigos ao mesmo tempo (proposta em produto.md › 4.5). Vazio = "Gravar sozinho".
  final Set<String> _selectedFriends = {};

  /// Hora (relógio do sensor) do primeiro quadro da gravação: o zero dos offsets.
  Duration? _recordingStart;

  /// 🟡 Ficam aqui até a "Confirme a sessão" existir. "Cancelar gravação" não apaga (R14).
  final List<CapturedHighlight> _highlights = [];

  bool _showControls = false;
  Timer? _controlsTimer;
  Timer? _toastTimer;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _toastTimer?.cancel();
    _subscription?.cancel();
    // Sem await: a tela já está saindo. Erros aqui não têm mais onde aparecer.
    widget.camera.stop().catchError((Object _) {});
    super.dispose();
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
    await _subscription?.cancel();
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
    // Um gesto feito enquanto o celular era posicionado não pode contar.
    _pipeline.reset();
    setState(() {
      _step = CaptureStep.recording;
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

  /// O aviso sobe na hora do gesto; salvar fica em segundo plano para não travar a análise.
  void _onGesture({required Duration until, required Duration offset}) {
    HapticFeedback.lightImpact();
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

  /// Um toque no preto mostra "Encerrar sessão" e "Cancelar gravação" por alguns segundos.
  void _revealControls() {
    _controlsTimer?.cancel();
    setState(() => _showControls = true);
    _controlsTimer = Timer(ClippoMotion.stopControls, () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _cancelRecording() {
    _controlsTimer?.cancel();
    _toastTimer?.cancel();
    setState(() {
      _step = CaptureStep.preparing;
      _showControls = false;
    });
  }

  void _finishSession() {
    _controlsTimer?.cancel();
    _toastTimer?.cancel();
    widget.camera.stop().catchError((Object _) {});
    setState(() {
      _step = CaptureStep.finishing;
      _showControls = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_step == CaptureStep.finishing) {
      // 🟡 Próximo passo: o estado D de verdade, com _highlights e _selectedFriends.
      return const PlaceholderScreen(title: 'Confirme a sessão', docSection: 'produto.md · 4.5 Gravação (estado D)');
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
          // Gravando, o "Voltar" do Android só mostra os controles: sair sem querer perderia a sessão.
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

  // ── Estado A ─────────────────────────────────────────────────────────────

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

  // ── Estados B e C ────────────────────────────────────────────────────────

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
                      ClippoGhostButton(label: 'Cancelar gravação', onPressed: _cancelRecording),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
