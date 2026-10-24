import 'dart:async';

import 'package:flutter/material.dart';

import 'package:clippo/core/camera/clippo_camera.dart';
import 'package:clippo/core/gesture/body_pose.dart';
import 'package:clippo/core/gesture/gesture_pipeline.dart';
import 'package:clippo/core/gesture/gesture_rule.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_text_button.dart';
import 'package:clippo/dev/pose_skeleton_painter.dart';

/// FERRAMENTA DO TIME (não é tela do produto): mostra a câmera e o que a detecção do gesto
/// conclui em cada quadro, para testar e calibrar a regra (docs/produto.md › Critérios de aceite).
///
/// Abra pelo catálogo ou direto no celular: flutter run -t lib/dev/gesture_lab_main.dart
class GestureLabScreen extends StatefulWidget {
  const GestureLabScreen({super.key, this.camera = const ClippoCamera()});

  final ClippoCamera camera;

  @override
  State<GestureLabScreen> createState() => _GestureLabScreenState();
}

enum _CameraState { checking, needsPermission, starting, running, failed }

class _GestureLabScreenState extends State<GestureLabScreen> {
  final _pipeline = GesturePipeline();
  StreamSubscription<GestureObservation>? _subscription;

  _CameraState _state = _CameraState.checking;
  String? _error;
  bool _accurate = false;

  GestureObservation? _last;
  PoseMeasurement? _measurement;
  int _triggers = 0;
  bool _showTrigger = false;
  Timer? _triggerTimer;

  // Quadros por segundo: conta os quadros e fecha a conta a cada segundo de câmera.
  int _framesInWindow = 0;
  Duration? _windowStart;
  int _framesPerSecond = 0;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _triggerTimer?.cancel();
    _subscription?.cancel();
    // Sem await: a tela já está saindo. Erros aqui não têm mais onde aparecer.
    widget.camera.stop().catchError((Object _) {});
    super.dispose();
  }

  Future<void> _checkPermission() async {
    try {
      final granted = await widget.camera.hasPermission();
      if (!mounted) return;
      granted ? await _start() : setState(() => _state = _CameraState.needsPermission);
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _requestPermission() async {
    try {
      final granted = await widget.camera.requestPermission();
      if (!mounted) return;
      if (granted) {
        await _start();
      } else {
        setState(() {
          _state = _CameraState.needsPermission;
          _error = 'Sem a câmera não dá para ver o gesto. Se o Android não perguntar de novo, '
              'libere em Configurações › Apps › Clippo › Permissões.';
        });
      }
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _start() async {
    setState(() {
      _state = _CameraState.starting;
      _error = null;
    });
    await _subscription?.cancel();
    _pipeline.reset();
    _subscription = _pipeline.watch(widget.camera.poses).listen(_onObservation, onError: _fail);
    try {
      await widget.camera.start(accurate: _accurate);
      if (mounted) setState(() => _state = _CameraState.running);
    } catch (e) {
      _fail(e);
    }
  }

  /// Trocar de modelo exige recriar o detector no Kotlin: desliga e liga de novo.
  Future<void> _toggleModel() async {
    setState(() => _accurate = !_accurate);
    try {
      await widget.camera.stop();
    } catch (_) {
      // Se não conseguiu desligar, o start abaixo mostra o erro.
    }
    _resetStats();
    await _start();
  }

  void _resetStats() {
    _last = null;
    _measurement = null;
    _triggers = 0;
    _framesInWindow = 0;
    _windowStart = null;
    _framesPerSecond = 0;
  }

  void _onObservation(GestureObservation observation) {
    final t = observation.frame.timestamp;
    final windowStart = _windowStart ??= t;
    _framesInWindow++;
    if (t - windowStart >= const Duration(seconds: 1)) {
      _framesPerSecond = _framesInWindow;
      _framesInWindow = 0;
      _windowStart = t;
    }

    // No log (flutter run / adb logcat), só quando algo muda: para quem acompanha pelo computador.
    if (observation.verdict.check != _last?.verdict.check) {
      debugPrint('LAB ${observation.frame.timestamp.inMilliseconds} ms: ${_verdictLabel(observation.verdict)}');
    }
    if (observation.triggered) {
      debugPrint('LAB ${observation.frame.timestamp.inMilliseconds} ms: DISPARO #${_triggers + 1}');
      _triggers++;
      _showTrigger = true;
      _triggerTimer?.cancel();
      _triggerTimer = Timer(ClippoMotion.savedBanner, () {
        if (mounted) setState(() => _showTrigger = false);
      });
    }
    final pose = observation.frame.bodyPose;
    setState(() {
      _last = observation;
      // As medidas vêm da MESMA regra que decidiu: os números da tela são os que valeram.
      _measurement = pose == null ? null : _pipeline.rule.measure(pose);
    });
  }

  void _fail(Object error) {
    if (!mounted) return;
    setState(() {
      _state = _CameraState.failed;
      _error = error is CameraFailure ? error.message : 'Algo deu errado com a câmera ($error).';
    });
  }

  @override
  Widget build(BuildContext context) {
    // A gravação ignora o tema claro/escuro (produto.md › 4.5); o laboratório segue a mesma ideia.
    return Theme(
      data: clippoTheme(Brightness.dark),
      child: Scaffold(
        backgroundColor: ClippoBrand.captureBackground,
        body: SafeArea(
          child: switch (_state) {
            _CameraState.running => _running(),
            _CameraState.checking || _CameraState.starting => const Center(child: CircularProgressIndicator()),
            _CameraState.needsPermission => _message(
                'A detecção do gesto precisa da câmera.',
                ClippoPrimaryButton(label: 'Permitir câmera', onPressed: _requestPermission),
              ),
            _CameraState.failed => _message(
                _error ?? 'Algo deu errado com a câmera.',
                ClippoPrimaryButton(label: 'Tentar de novo', onPressed: _checkPermission),
              ),
          },
        ),
      ),
    );
  }

  Widget _message(String text, Widget action) {
    return Padding(
      padding: const EdgeInsets.all(ClippoSpace.gutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text, style: ClippoText.bodyL.copyWith(color: ClippoBrand.onWine), textAlign: TextAlign.center),
          if (_state == _CameraState.needsPermission && _error != null) ...[
            const SizedBox(height: ClippoSpace.spaceM),
            Text(_error!, style: ClippoText.body.copyWith(color: ClippoBrand.captureTextMuted), textAlign: TextAlign.center),
          ],
          const SizedBox(height: ClippoSpace.section),
          action,
        ],
      ),
    );
  }

  Widget _running() {
    final last = _last;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 9:16 em pé: a mesma proporção da análise (16:9 deitado), sem cortar a imagem. O
        // esqueleto fica na mesma caixa, então os pontos da análise caem em cima da imagem.
        Center(
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const AndroidView(viewType: ClippoCamera.previewViewType),
                if (last != null)
                  CustomPaint(
                    painter: PoseSkeletonPainter(
                      frame: last.frame,
                      verdict: last.verdict,
                      minConfidence: _pipeline.rule.thresholds.minConfidence,
                      colors: ClippoColors.of(context),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_showTrigger)
          Center(
            child: Text('\\O/', style: ClippoText.heroMark.copyWith(color: ClippoBrand.peach)),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            color: ClippoBrand.captureOverlay,
            padding: const EdgeInsets.fromLTRB(ClippoSpace.gutter, ClippoSpace.spaceL, ClippoSpace.gutter, ClippoSpace.spaceS),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  last == null ? 'Esperando o primeiro quadro…' : _verdictLabel(last.verdict),
                  style: ClippoText.titleS.copyWith(
                    color: last?.verdict.isGesture ?? false ? ClippoBrand.peach : ClippoBrand.onWine,
                  ),
                ),
                const SizedBox(height: ClippoSpace.spaceS),
                Text(
                  measurementText(_measurement, _pipeline.rule.thresholds),
                  style: ClippoText.body.copyWith(color: ClippoBrand.onWine, fontFeatures: ClippoText.tabular),
                ),
                const SizedBox(height: ClippoSpace.spaceS),
                Text(
                  '$_framesPerSecond quadros/s · ML Kit ${last?.frame.analysisTime.inMilliseconds ?? '–'} ms · '
                  '${last == null ? '–' : '${last.frame.width}×${last.frame.height}'}\n'
                  'Disparos: $_triggers · modelo ${_accurate ? 'accurate' : 'base'}',
                  style: ClippoText.label.copyWith(
                    color: ClippoBrand.captureTextMuted,
                    fontFeatures: ClippoText.tabular,
                  ),
                ),
                ClippoTextButton(
                  label: _accurate ? 'Usar modelo base' : 'Usar modelo accurate',
                  onPressed: _toggleModel,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _verdictLabel(GestureVerdict verdict) {
    final side = switch (verdict.side) {
      BodySide.left => ' (braço esquerdo)',
      BodySide.right => ' (braço direito)',
      null => '',
    };
    return switch (verdict.check) {
      GestureCheck.matched => '\\ o / reconhecido',
      GestureCheck.noPerson => 'Ninguém no quadro',
      GestureCheck.lowConfidence => 'Pontos com pouca confiança',
      GestureCheck.notFacingCamera => 'Pessoa de lado',
      GestureCheck.armCrossed => 'Braço cruzado$side',
      GestureCheck.armNotDiagonal => 'Braço fora da diagonal$side',
      GestureCheck.armBent => 'Braço dobrado$side',
    };
  }
}

/// As medidas da regra lado a lado com os limites, para ver quanto faltou.
/// "Esq." e "Dir." são os lados da PESSOA, como na regra.
@visibleForTesting
String measurementText(PoseMeasurement? m, GestureThresholds limits) {
  String deg(double v) => '${v.round()}°';
  String decimal(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
  String arm(String label, ArmMeasurement a) =>
      '$label braço ${a.crossed ? 'cruzado' : deg(a.armAngle)} · cotovelo ${deg(a.elbowAngle)}';
  final limitsLine = 'Limites: braço ${deg(limits.minArmAngle)}–${deg(limits.maxArmAngle)} · '
      'cotovelo ≥ ${deg(limits.minElbowAngle)} · ombros ≥ ${decimal(limits.minShoulderSpan)}';
  if (m == null) return 'Sem medidas\n$limitsLine';
  return '${arm('Esq.:', m.left)}\n${arm('Dir.:', m.right)}\n'
      'Ombros: ${decimal(m.shoulderSpan)} braços\n$limitsLine';
}
