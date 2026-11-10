import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'package:clippo/core/data/highlight.dart';
import 'package:clippo/core/data/highlight_media_repository.dart';
import 'package:clippo/core/format/clippo_format.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_capture_chip.dart';
import 'package:clippo/core/widgets/clippo_svg_icon.dart';
import 'package:clippo/features/home/widgets/home_feedback.dart';

/// Baixa o vídeo do lance para um arquivo local (D17: nunca por `getDownloadURL()`).
typedef HighlightVideoLoader = Future<File> Function(String storagePath);

/// Cria o player de um arquivo local. Injetável para os testes.
typedef HighlightVideoControllerFactory = VideoPlayerController Function(File file);

/// Compartilha o arquivo do lance com outro app.
typedef HighlightVideoSharer = Future<void> Function(File file, Highlight highlight, String sessionName);

/// Player: o vídeo de um lance em tela cheia sobre o preto (docs/produto.md › 4.4).
///
/// Toca o arquivo que o [HighlightMediaRepository] baixou para o cache, baixa para a
/// galeria e compartilha o vídeo (R11: todo participante assiste e baixa). Lance
/// ainda subindo (`pending`) mostra "enviando…" e não tenta baixar. Deslizar ou as
/// setas levam ao lance anterior/próximo da mesma sessão.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    this.sessionName = '',
    this.highlights = const [],
    this.initialIndex = 0,
    this.autoPlay = true,
    this.mediaRepository,
    this.loadVideo,
    this.saveToGallery,
    this.shareVideo,
    this.controllerFactory,
  });

  /// Nome da sessão, discreto no topo.
  final String sessionName;

  /// Os lances da sessão, para ir ao anterior e ao próximo.
  final List<Highlight> highlights;

  /// Lance que abre primeiro.
  final int initialIndex;

  /// Começa tocando assim que o vídeo carrega.
  final bool autoPlay;

  /// Vídeos no Storage. No app, `highlightMediaRepository`.
  final HighlightMediaRepository? mediaRepository;

  /// Substitui `mediaRepository.videoFile` (testes).
  final HighlightVideoLoader? loadVideo;

  /// Substitui `mediaRepository.saveToGallery` (testes).
  final Future<void> Function(String storagePath)? saveToGallery;

  /// Substitui o compartilhamento do sistema (testes).
  final HighlightVideoSharer? shareVideo;

  /// Substitui `VideoPlayerController.file` (testes).
  final HighlightVideoControllerFactory? controllerFactory;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

enum _Stage { uploading, unavailable, loading, ready, error }

class _PlayerScreenState extends State<PlayerScreen> {
  late final List<Highlight> _items = ensureDistinctHighlightTitles(widget.highlights);
  late int _currentIndex =
      _items.isEmpty ? 0 : widget.initialIndex.clamp(0, _items.length - 1);
  late final PageController _pageController = PageController(initialPage: _currentIndex);

  _Stage _stage = _Stage.loading;
  String? _message;
  VideoPlayerController? _controller;
  File? _file;
  int _loadToken = 0;
  late bool _wantsPlay = widget.autoPlay;
  bool _saving = false;
  bool _sharing = false;

  Highlight get _current => _items[_currentIndex];

  HighlightMediaRepository get _media => widget.mediaRepository ?? highlightMediaRepository;

  Future<File> _fetch(String path) => widget.loadVideo != null ? widget.loadVideo!(path) : _media.videoFile(path);

  /// Só dá para baixar o que já chegou ao Storage.
  bool _canFetch(Highlight h) =>
      !h.isUploading && h.status != HighlightStatus.failed && (h.videoPath ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_items.isNotEmpty) _load();
  }

  @override
  void dispose() {
    _loadToken++;
    _releaseController();
    _pageController.dispose();
    super.dispose();
  }

  void _releaseController() {
    final old = _controller;
    _controller = null;
    _file = null;
    if (old != null) {
      old.removeListener(_onTick);
      unawaited(old.dispose());
    }
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    _releaseController();
    final highlight = _current;

    if (highlight.isUploading) {
      setState(() {
        _stage = _Stage.uploading;
        _message = 'Enviando o lance…';
      });
      return;
    }
    if (highlight.status == HighlightStatus.failed) {
      setState(() {
        _stage = _Stage.unavailable;
        _message = 'O envio desse lance falhou. O Clippo tenta de novo sozinho.';
      });
      return;
    }
    final path = highlight.videoPath;
    if (path == null || path.isEmpty) {
      setState(() {
        _stage = _Stage.unavailable;
        _message = 'Esse lance ainda não tem vídeo.';
      });
      return;
    }

    setState(() {
      _stage = _Stage.loading;
      _message = 'Carregando o lance…';
    });
    try {
      final file = await _fetch(path);
      if (token != _loadToken || !mounted) return;
      final controller = (widget.controllerFactory ?? VideoPlayerController.file)(file);
      await controller.initialize();
      if (token != _loadToken || !mounted) {
        unawaited(controller.dispose());
        return;
      }
      controller.addListener(_onTick);
      setState(() {
        _file = file;
        _controller = controller;
        _stage = _Stage.ready;
        _message = null;
      });
      if (_wantsPlay) await controller.play();
    } catch (e) {
      if (token != _loadToken || !mounted) return;
      setState(() {
        _stage = _Stage.error;
        _message = HighlightMediaFailure.from(e).message;
      });
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  bool get _playing => _controller?.value.isPlaying ?? false;

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null || _stage != _Stage.ready) return;
    if (controller.value.isPlaying) {
      _wantsPlay = false;
      await controller.pause();
    } else {
      _wantsPlay = true;
      final value = controller.value;
      if (value.duration > Duration.zero && value.position >= value.duration) {
        await controller.seekTo(Duration.zero);
      }
      await controller.play();
    }
  }

  void _goToIndex(int index) {
    if (index < 0 || index >= _items.length || index == _currentIndex) return;
    if (ClippoMotion.reduced(context)) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(index, duration: ClippoMotion.enable, curve: ClippoMotion.standard);
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _load();
  }

  void _seekToFraction(double fraction) {
    final controller = _controller;
    if (controller == null) return;
    final total = controller.value.duration;
    controller.seekTo(total * fraction.clamp(0.0, 1.0));
  }

  Future<void> _download() async {
    final highlight = _current;
    if (!_canFetch(highlight) || _saving) return;
    setState(() => _saving = true);
    try {
      final path = highlight.videoPath!;
      await (widget.saveToGallery != null ? widget.saveToGallery!(path) : _media.saveToGallery(path));
      if (mounted) showHomeMessage(context, 'Lance salvo na galeria.');
    } catch (e) {
      if (mounted) showHomeMessage(context, HighlightMediaFailure.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share() async {
    final highlight = _current;
    if (!_canFetch(highlight) || _sharing) return;
    setState(() => _sharing = true);
    try {
      final file = _file ?? await _fetch(highlight.videoPath!);
      await (widget.shareVideo ?? _shareWithSystem)(file, highlight, widget.sessionName);
    } catch (e) {
      if (mounted) showHomeMessage(context, HighlightMediaFailure.from(e).message);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  static Future<void> _shareWithSystem(File file, Highlight highlight, String sessionName) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'video/mp4')],
        text: clippoDotList([highlight.title, if (sessionName.isNotEmpty) sessionName]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: ClippoBrand.captureBackground,
      ),
      child: Scaffold(
        backgroundColor: ClippoBrand.captureBackground,
        body: SafeArea(child: _items.isEmpty ? _buildEmpty() : _buildPlayer()),
      ),
    );
  }

  Widget _topBar({String? counter}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ClippoSpace.gutter,
        ClippoSpace.spaceM,
        ClippoSpace.gutter,
        ClippoSpace.spaceM,
      ),
      child: Row(
        children: [
          _CircleAction(
            icon: 'close',
            semanticLabel: 'Fechar',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: ClippoSpace.spaceM),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.sessionName.isNotEmpty)
                  Text(
                    widget.sessionName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: ClippoText.label.copyWith(color: ClippoBrand.captureTextMuted),
                  ),
                if (counter != null) ...[
                  const SizedBox(height: ClippoSpace.labelToValue),
                  Text(
                    counter,
                    textAlign: TextAlign.center,
                    style: ClippoText.label.copyWith(color: ClippoBrand.onWine, fontFeatures: ClippoText.tabular),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: ClippoSpace.spaceM),
          // Mantém o título centralizado: o espaço do botão de fechar, do outro lado.
          const SizedBox.square(dimension: ClippoSize.minTouchTarget),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _topBar(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: ClippoSpace.gutter),
              child: Text(
                'Nenhum lance para mostrar.',
                textAlign: TextAlign.center,
                style: ClippoText.titleS.copyWith(color: ClippoBrand.onWine),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayer() {
    final highlight = _current;
    final hasPrev = _currentIndex > 0;
    final hasNext = _currentIndex < _items.length - 1;
    final controller = _controller;
    final value = controller?.value;
    final total = (value != null && value.duration > Duration.zero) ? value.duration : highlight.duration;
    final position = value?.position ?? Duration.zero;
    final progress = total.inMilliseconds <= 0 ? 0.0 : position.inMilliseconds / total.inMilliseconds;
    final canFetch = _canFetch(highlight);
    final ready = _stage == _Stage.ready && controller != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _topBar(counter: '${_currentIndex + 1} de ${_items.length}'),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _items.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final isCurrent = index == _currentIndex;
              if (isCurrent && ready) {
                return Center(
                  child: Semantics(
                    button: true,
                    label: _playing ? 'Pausar vídeo' : 'Reproduzir vídeo',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _togglePlay,
                      child: AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(controller),
                            if (!_playing) const _PlayBadge(),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
              return Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _VideoPlaceholder(
                    stage: isCurrent ? _stage : _Stage.loading,
                    message: isCurrent ? _message : null,
                    onRetry: isCurrent && _stage == _Stage.error ? _load : null,
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ClippoSpace.gutter,
            ClippoSpace.spaceL,
            ClippoSpace.gutter,
            ClippoSpace.screenBottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                highlight.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ClippoText.titleS.copyWith(color: ClippoBrand.onWine),
              ),
              const SizedBox(height: ClippoSpace.spaceS),
              Row(
                children: [
                  const ClippoSvgIcon('clock', size: ClippoSize.checkIcon, color: ClippoBrand.captureTextMuted),
                  const SizedBox(width: ClippoSpace.spaceS),
                  Flexible(
                    child: Text(
                      clippoHighlightTiming(highlight.offset, highlight.duration, uploading: highlight.isUploading),
                      style: ClippoText.label.copyWith(
                        color: highlight.isUploading ? ClippoBrand.peach : ClippoBrand.captureTextMuted,
                        fontFeatures: ClippoText.tabular,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ClippoSpace.spaceM),
              Opacity(
                opacity: canFetch ? 1 : ClippoOpacity.disabled,
                child: Wrap(
                  spacing: ClippoSpace.spaceM,
                  runSpacing: ClippoSpace.spaceS,
                  children: [
                    ClippoCaptureChip(
                      label: _saving ? 'Baixando…' : 'Baixar',
                      selected: false,
                      onPressed: canFetch ? _download : null,
                    ),
                    ClippoCaptureChip(
                      label: _sharing ? 'Preparando…' : 'Compartilhar',
                      selected: false,
                      onPressed: canFetch ? _share : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ClippoSpace.spaceM),
              _ProgressBar(
                progress: progress,
                elapsedLabel: clippoPlayerProgress(position),
                totalLabel: clippoPlayerProgress(total),
                onSeek: ready ? _seekToFraction : null,
              ),
              const SizedBox(height: ClippoSpace.spaceL),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CircleAction(
                    icon: 'chevron-left',
                    semanticLabel: 'Lance anterior',
                    enabled: hasPrev,
                    onPressed: () => _goToIndex(_currentIndex - 1),
                  ),
                  const SizedBox(width: ClippoSpace.gutter),
                  _PlayPauseButton(playing: _playing, enabled: ready, onPressed: _togglePlay),
                  const SizedBox(width: ClippoSpace.gutter),
                  _CircleAction(
                    icon: 'chevron-right',
                    semanticLabel: 'Próximo lance',
                    enabled: hasNext,
                    onPressed: () => _goToIndex(_currentIndex + 1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.enabled = true,
  });

  final String icon;
  final String semanticLabel;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: enabled ? 1 : ClippoOpacity.disabled,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? onPressed : null,
            child: SizedBox.square(
              dimension: ClippoSize.minTouchTarget,
              child: Center(
                child: Container(
                  width: ClippoSize.control,
                  height: ClippoSize.control,
                  decoration: BoxDecoration(
                    color: ClippoBrand.captureChip,
                    shape: BoxShape.circle,
                    border: Border.all(color: ClippoBrand.captureChipBorder, width: ClippoSize.border),
                  ),
                  alignment: Alignment.center,
                  child: ClippoSvgIcon(icon, size: ClippoSize.fieldIcon, color: ClippoBrand.onWine),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.playing, required this.enabled, required this.onPressed});

  final bool playing;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: playing ? 'Pausar' : 'Reproduzir',
      child: ExcludeSemantics(
        child: Opacity(
          opacity: enabled ? 1 : ClippoOpacity.disabled,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? onPressed : null,
            child: Container(
              width: ClippoSize.playerPlayButton,
              height: ClippoSize.playerPlayButton,
              decoration: const BoxDecoration(color: ClippoBrand.wine, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: ClippoSvgIcon(playing ? 'pause' : 'play', size: ClippoSize.icon, color: ClippoBrand.onWine),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.progress,
    required this.elapsedLabel,
    required this.totalLabel,
    required this.onSeek,
  });

  final double progress;
  final String elapsedLabel;
  final String totalLabel;
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    final seek = onSeek;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth <= 0 ? 1.0 : constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: seek == null ? null : (details) => seek(details.localPosition.dx / width),
              onHorizontalDragUpdate: seek == null ? null : (details) => seek(details.localPosition.dx / width),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: ClippoSpace.spaceM),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                  child: SizedBox(
                    height: ClippoSize.meter,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: ClippoBrand.captureChipBorder),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: const ColoredBox(color: ClippoBrand.peach),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              elapsedLabel,
              style: ClippoText.label.copyWith(color: ClippoBrand.captureTextMuted, fontFeatures: ClippoText.tabular),
            ),
            Text(
              totalLabel,
              style: ClippoText.label.copyWith(color: ClippoBrand.captureTextMuted, fontFeatures: ClippoText.tabular),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ClippoSize.navButton,
      height: ClippoSize.navButton,
      decoration: const BoxDecoration(color: ClippoBrand.captureOverlay, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: const ClippoSvgIcon('play', size: ClippoSize.icon, color: ClippoBrand.onWine),
    );
  }
}

/// O quadro enquanto o vídeo não está pronto: carregando, enviando, sem vídeo ou erro.
class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({required this.stage, required this.message, required this.onRetry});

  final _Stage stage;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = message;
    return DecoratedBox(
      decoration: BoxDecoration(color: ClippoColors.dark.surface),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(child: CustomPaint(painter: _StageCourtPainter())),
          Padding(
            padding: const EdgeInsets.all(ClippoSpace.cardPadding),
            child: Semantics(
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (stage == _Stage.loading)
                    const SizedBox.square(
                      dimension: ClippoSize.spinner,
                      child: CircularProgressIndicator(strokeWidth: ClippoSize.border, color: ClippoBrand.peach),
                    ),
                  if (text != null) ...[
                    if (stage == _Stage.loading) const SizedBox(height: ClippoSpace.spaceM),
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: ClippoText.label.copyWith(
                        color: stage == _Stage.uploading ? ClippoBrand.peach : ClippoBrand.onWine,
                      ),
                    ),
                  ],
                  if (onRetry != null) ...[
                    const SizedBox(height: ClippoSpace.spaceM),
                    ClippoCaptureChip(label: 'Tentar de novo', selected: false, onPressed: onRetry),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Desenho de quadra atrás do quadro vazio, nas cores da gravação.
class _StageCourtPainter extends CustomPainter {
  const _StageCourtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = ClippoBrand.captureChipBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = ClippoSize.iconStroke;

    final horizon = size.height * 0.32;
    canvas.drawLine(Offset(0, horizon), Offset(size.width, horizon), linePaint);
    final court = Path()
      ..moveTo(size.width * 0.06, size.height * 0.94)
      ..lineTo(size.width * 0.24, horizon)
      ..lineTo(size.width * 0.76, horizon)
      ..lineTo(size.width * 0.94, size.height * 0.94);
    canvas.drawPath(court, linePaint);
    final midY = size.height * 0.62;
    canvas.drawLine(Offset(size.width * 0.15, midY), Offset(size.width * 0.85, midY), linePaint);
  }

  @override
  bool shouldRepaint(_StageCourtPainter oldDelegate) => false;
}
