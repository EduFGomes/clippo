import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:clippo/core/data/highlight.dart';
import 'package:clippo/core/format/clippo_format.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_svg_icon.dart';

/// Player: reprodução em tela cheia de um highlight (docs/produto.md › 4.4).
///
/// Funciona sobre fundo preto puro (`ClippoBrand.captureBackground`), com controles
/// mínimos (reproduzir/pausar, fechar, compartilhar) e permite deslizar ou tocar
/// nas setas para ir ao highlight anterior/próximo da mesma sessão.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    this.sessionName = 'Pelada de quinta',
    this.highlights = const [],
    this.initialIndex = 0,
    this.autoPlay = true,
    this.onShare,
  });

  /// Nome da sessão exibido de forma discreta no topo.
  final String sessionName;

  /// Lista de highlights da sessão, para navegar entre anterior e próximo.
  final List<Highlight> highlights;

  /// Índice do highlight que começa aberto.
  final int initialIndex;

  /// Inicia reproduzindo ao abrir a tela.
  final bool autoPlay;

  /// Permite interceptar o compartilhamento nos testes.
  final ValueChanged<Highlight>? onShare;

  static final List<Highlight> _defaultHighlights = [
    Highlight(
      id: 'hl-1',
      title: 'Jogada de cinema',
      offset: const Duration(minutes: 4, seconds: 15),
      duration: const Duration(seconds: 30),
      savedAt: DateTime(2026, 9, 11, 19, 34, 15),
      createdBy: 'alice',
    ),
    Highlight(
      id: 'hl-2',
      title: 'Ponto antológico',
      offset: const Duration(minutes: 12, seconds: 40),
      duration: const Duration(seconds: 30),
      savedAt: DateTime(2026, 9, 11, 19, 42, 40),
      createdBy: 'alice',
    ),
    Highlight(
      id: 'hl-3',
      title: 'Defesa no reflexo',
      offset: const Duration(minutes: 27, seconds: 8),
      duration: const Duration(seconds: 30),
      savedAt: DateTime(2026, 9, 11, 19, 57, 8),
      createdBy: 'alice',
    ),
  ];

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final List<Highlight> _items = ensureDistinctHighlightTitles(
    widget.highlights.isEmpty ? PlayerScreen._defaultHighlights : widget.highlights,
  );
  late int _currentIndex = widget.initialIndex.clamp(0, _items.length - 1);
  late final PageController _pageController = PageController(initialPage: _currentIndex);

  late bool _playing = widget.autoPlay;
  Duration _position = Duration.zero;
  Timer? _playbackTimer;

  Highlight get _current => _items[_currentIndex];

  @override
  void initState() {
    super.initState();
    if (_playing) _startTimer();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_playing) return;
      final total = _current.duration;
      final next = _position + const Duration(seconds: 1);
      if (next >= total) {
        setState(() {
          _position = total;
          _playing = false;
        });
        _playbackTimer?.cancel();
      } else {
        setState(() => _position = next);
      }
    });
  }

  void _togglePlay() {
    setState(() {
      if (_playing) {
        _playing = false;
        _playbackTimer?.cancel();
      } else {
        if (_position >= _current.duration) {
          _position = Duration.zero;
        }
        _playing = true;
        _startTimer();
      }
    });
  }

  void _goToIndex(int index) {
    if (index < 0 || index >= _items.length || index == _currentIndex) return;
    if (ClippoMotion.reduced(context)) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(
        index,
        duration: ClippoMotion.enable,
        curve: ClippoMotion.standard,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _position = Duration.zero;
    });
    if (_playing) _startTimer();
  }

  void _seekToFraction(double fraction) {
    final totalSeconds = _current.duration.inSeconds;
    final targetSeconds = (totalSeconds * fraction.clamp(0.0, 1.0)).round();
    setState(() => _position = Duration(seconds: targetSeconds));
  }

  void _share() {
    final callback = widget.onShare;
    if (callback != null) {
      callback(_current);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: ClippoBrand.wine,
          content: Text(
            'Compartilhando ${_current.title}…',
            style: ClippoText.label.copyWith(color: ClippoBrand.onWine),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final highlight = _current;
    final hasPrev = _currentIndex > 0;
    final hasNext = _currentIndex < _items.length - 1;
    final totalSeconds = highlight.duration.inSeconds <= 0 ? 30 : highlight.duration.inSeconds;
    final progress = (_position.inSeconds / totalSeconds).clamp(0.0, 1.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: ClippoBrand.captureBackground,
      ),
      child: Scaffold(
        backgroundColor: ClippoBrand.captureBackground,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
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
                          Text(
                            widget.sessionName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: ClippoText.label.copyWith(color: ClippoBrand.captureTextMuted),
                          ),
                          const SizedBox(height: ClippoSpace.labelToValue),
                          Text(
                            '${_currentIndex + 1} de ${_items.length}',
                            textAlign: TextAlign.center,
                            style: ClippoText.label.copyWith(
                              color: ClippoBrand.onWine,
                              fontFeatures: ClippoText.tabular,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: ClippoSpace.spaceM),
                    _CircleAction(
                      icon: 'share',
                      semanticLabel: 'Compartilhar highlight',
                      onPressed: _share,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _items.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Center(
                      child: Semantics(
                        button: true,
                        label: _playing ? 'Pausar vídeo' : 'Reproduzir vídeo',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _togglePlay,
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: _VideoStage(
                              highlight: item,
                              playing: _playing && index == _currentIndex,
                              seed: index,
                            ),
                          ),
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
                        const ClippoSvgIcon(
                          'clock',
                          size: ClippoSize.checkIcon,
                          color: ClippoBrand.captureTextMuted,
                        ),
                        const SizedBox(width: ClippoSpace.spaceS),
                        Flexible(
                          child: Text(
                            clippoHighlightTiming(
                              highlight.offset,
                              highlight.duration,
                              uploading: highlight.isUploading,
                            ),
                            style: ClippoText.label.copyWith(
                              color: highlight.isUploading
                                  ? ClippoBrand.peach
                                  : ClippoBrand.captureTextMuted,
                              fontFeatures: ClippoText.tabular,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ClippoSpace.spaceL),
                    _ProgressBar(
                      progress: progress,
                      elapsedLabel: clippoPlayerProgress(_position),
                      totalLabel: clippoPlayerProgress(highlight.duration),
                      onSeek: _seekToFraction,
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
                        _PlayPauseButton(
                          playing: _playing,
                          onPressed: _togglePlay,
                        ),
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
          ),
        ),
      ),
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
                    border: Border.all(
                      color: ClippoBrand.captureChipBorder,
                      width: ClippoSize.border,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: ClippoSvgIcon(
                    icon,
                    size: ClippoSize.fieldIcon,
                    color: ClippoBrand.onWine,
                  ),
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
  const _PlayPauseButton({
    required this.playing,
    required this.onPressed,
  });

  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: playing ? 'Pausar' : 'Reproduzir',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            width: ClippoSize.playerPlayButton,
            height: ClippoSize.playerPlayButton,
            decoration: const BoxDecoration(
              color: ClippoBrand.wine,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: ClippoSvgIcon(
              playing ? 'pause' : 'play',
              size: ClippoSize.icon,
              color: ClippoBrand.onWine,
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
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth <= 0 ? 1.0 : constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => onSeek(details.localPosition.dx / width),
              onHorizontalDragUpdate: (details) => onSeek(details.localPosition.dx / width),
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
              style: ClippoText.label.copyWith(
                color: ClippoBrand.captureTextMuted,
                fontFeatures: ClippoText.tabular,
              ),
            ),
            Text(
              totalLabel,
              style: ClippoText.label.copyWith(
                color: ClippoBrand.captureTextMuted,
                fontFeatures: ClippoText.tabular,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VideoStage extends StatelessWidget {
  const _VideoStage({
    required this.highlight,
    required this.playing,
    required this.seed,
  });

  final Highlight highlight;
  final bool playing;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final thumb = highlight.thumbnailPath;
    final hasNetworkThumb = thumb != null && thumb.startsWith('http');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ClippoColors.dark.surface,
        image: hasNetworkThumb
            ? DecorationImage(image: NetworkImage(thumb), fit: BoxFit.cover)
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!hasNetworkThumb)
            Positioned.fill(
              child: CustomPaint(
                painter: _StageCourtPainter(seed: seed),
              ),
            ),
          if (!playing)
            Container(
              width: ClippoSize.navButton,
              height: ClippoSize.navButton,
              decoration: const BoxDecoration(
                color: ClippoBrand.captureOverlay,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const ClippoSvgIcon(
                'play',
                size: ClippoSize.icon,
                color: ClippoBrand.onWine,
              ),
            ),
        ],
      ),
    );
  }
}

class _StageCourtPainter extends CustomPainter {
  const _StageCourtPainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = ClippoBrand.captureChipBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final horizon = size.height * 0.32;
    canvas.drawLine(Offset(0, horizon), Offset(size.width, horizon), linePaint);

    final court = Path()
      ..moveTo(size.width * 0.06, size.height * 0.94)
      ..lineTo(size.width * 0.24, horizon)
      ..lineTo(size.width * 0.76, horizon)
      ..lineTo(size.width * 0.94, size.height * 0.94);
    canvas.drawPath(court, linePaint);

    final midY = size.height * 0.62;
    canvas.drawLine(
      Offset(size.width * 0.15, midY),
      Offset(size.width * 0.85, midY),
      linePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, midY),
        width: size.width * 0.26,
        height: size.height * 0.16,
      ),
      linePaint,
    );

    final goalWidth = size.width * 0.18;
    final goalHeight = size.height * 0.1;
    canvas.drawRect(
      Rect.fromLTWH(
        (size.width - goalWidth) / 2,
        horizon - goalHeight,
        goalWidth,
        goalHeight,
      ),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_StageCourtPainter oldDelegate) => oldDelegate.seed != seed;
}
