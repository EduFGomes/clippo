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
import 'package:clippo/core/widgets/clippo_pressable.dart';
import 'package:clippo/core/widgets/clippo_svg_icon.dart';
import 'package:clippo/features/home/widgets/home_feedback.dart';

/// Baixa o vídeo do lance para um arquivo local (D17: nunca por `getDownloadURL()`).
typedef HighlightVideoLoader = Future<File> Function(String storagePath);

/// Cria o player de um arquivo local. Injetável para os testes.
typedef HighlightVideoControllerFactory = VideoPlayerController Function(File file);

/// Onde buscar o vídeo aos poucos (streaming). Injetável para os testes.
typedef HighlightVideoStreamSource = Future<HighlightVideoStream> Function(String storagePath);

/// Cria o player que toca enquanto o vídeo chega. Injetável para os testes.
typedef HighlightStreamControllerFactory = VideoPlayerController Function(HighlightVideoStream source);

/// Compartilha o arquivo do lance com outro app.
typedef HighlightVideoSharer = Future<void> Function(File file, Highlight highlight, String sessionName);

/// Player: o vídeo de um lance em tela cheia sobre o preto (docs/produto.md › 4.4), com os
/// controles por cima, como nos players de vídeo conhecidos: somem com o vídeo tocando e
/// voltam ao tocar nele. Botões de voltar e avançar 5 s ao lado do play. Deslizar troca de lance; segurar o lado direito toca em 2x; pinça dá zoom.
///
/// Toca o vídeo da nuvem enquanto ele chega (streaming, sem link público: D17), ou do cache se
/// já foi baixado; se o streaming falhar, baixa o arquivo inteiro e toca. Baixa para a
/// galeria e compartilha o vídeo (R11: todo participante assiste e baixa). Quem gravou e
/// ainda tem o MP4 no celular ([Highlight.localPath]) assiste, baixa e compartilha direto
/// dele, sem internet e antes de o lance subir. Sem o arquivo, lance ainda subindo
/// (`pending`) mostra "enviando…" e não tenta baixar. Deslizar ou as setas levam ao lance
/// anterior/próximo da mesma sessão.
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
    this.saveFileToGallery,
    this.localFileExists,
    this.streamVideo,
    this.streamControllerFactory,
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

  /// Substitui `mediaRepository.saveToGallery` (testes). Chama `onProgress` de 0 a 1.
  final Future<void> Function(String storagePath, ValueChanged<double> onProgress)? saveToGallery;

  /// Substitui o compartilhamento do sistema (testes).
  final HighlightVideoSharer? shareVideo;

  /// Substitui `VideoPlayerController.file` (testes).
  final HighlightVideoControllerFactory? controllerFactory;

  /// Substitui `mediaRepository.saveFileToGallery` (testes).
  final Future<void> Function(File file)? saveFileToGallery;

  /// Substitui `File.exists` do MP4 no celular (testes).
  final Future<bool> Function(String path)? localFileExists;

  /// Substitui `mediaRepository.videoStream` (testes). Nos testes que só passam [loadVideo],
  /// o Player não faz streaming: baixa e toca, como antes.
  final HighlightVideoStreamSource? streamVideo;

  /// Substitui `VideoPlayerController.networkUrl` (testes).
  final HighlightStreamControllerFactory? streamControllerFactory;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

enum _Stage { uploading, unavailable, loading, ready, error }

class _PlayerScreenState extends State<PlayerScreen> {
  late final List<Highlight> _items = List<Highlight>.unmodifiable(widget.highlights);
  late int _currentIndex =
      _items.isEmpty ? 0 : widget.initialIndex.clamp(0, _items.length - 1);
  late final PageController _pageController = PageController(initialPage: _currentIndex);
  final GlobalKey _pagesKey = GlobalKey();

  _Stage _stage = _Stage.loading;
  String? _message;
  VideoPlayerController? _controller;
  File? _file;
  int _loadToken = 0;
  late bool _wantsPlay = widget.autoPlay;
  bool _saving = false;

  /// Quanto do vídeo já chegou no "Baixar" (0 a 1); nulo enquanto não se sabe.
  double? _downloadProgress;
  bool _sharing = false;

  /// Segurando o lado direito da tela: o vídeo toca em [_fastSpeed] enquanto o dedo estiver lá.
  bool _fast = false;
  static const double _fastSpeed = 2;

  /// Quanto o "Avançar" pula.
  static const Duration _skip = Duration(seconds: 5);

  /// Zoom com pinça no vídeo. Com zoom, arrastar move o vídeo em vez de trocar de lance.
  final TransformationController _zoom = TransformationController();
  bool _zoomed = false;
  static const double _maxZoom = 4;

  /// Dedos na tela agora. Com dois ou mais (pinça), deslizar não troca de lance: sem isso o
  /// PageView pegava o gesto antes do zoom.
  int _fingers = 0;
  bool get _pinching => _fingers >= 2;

  void _fingerDown(PointerDownEvent _) {
    _fingers++;
    if (_fingers == 2) setState(() {});
  }

  void _fingerUp(PointerEvent _) {
    if (_fingers > 0) _fingers--;
    if (_fingers == 1) setState(() {});
  }

  void _onZoomChanged() {
    final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  /// Os controles por cima do vídeo (fechar, baixar, play, barra…) estão à vista.
  bool _controlsVisible = true;
  Timer? _hideTimer;

  /// Com leitor de tela os controles nunca somem: não haveria como trazê-los de volta.
  bool get _controlsCanHide => !MediaQuery.accessibleNavigationOf(context);

  /// Com o vídeo tocando, os controles somem depois de [ClippoMotion.playerControls].
  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!mounted || !_playing) return;
    _hideTimer = Timer(ClippoMotion.playerControls, () {
      if (!mounted || !_playing || !_controlsCanHide || _seekingTo != null || _saving || _sharing) return;
      setState(() => _controlsVisible = false);
    });
  }

  void _revealControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  /// Tocar no vídeo: esconde os controles se estão à vista (e o vídeo toca); se não, mostra.
  void _onVideoTap() {
    if (_controlsVisible && _playing && _controlsCanHide) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _revealControls();
    }
  }

  Highlight get _current => _items[_currentIndex];

  HighlightMediaRepository get _media => widget.mediaRepository ?? highlightMediaRepository;

  Future<File> _fetch(String path) => widget.loadVideo != null ? widget.loadVideo!(path) : _media.videoFile(path);

  /// Só dá para baixar da nuvem o que já chegou ao Storage.
  bool _canFetch(Highlight h) =>
      !h.isUploading && h.status != HighlightStatus.failed && (h.videoPath ?? '').isNotEmpty;

  /// Os lances cujo MP4 já não está no celular (a fila apagou depois do `uploaded`).
  final Set<String> _localMissing = <String>{};

  /// O vídeo está no celular: toca, baixa e compartilha sem internet.
  bool _isLocal(Highlight h) => h.hasLocalVideo && !_localMissing.contains(h.id);

  /// Dá para baixar e compartilhar: do celular ou da nuvem.
  bool _canAct(Highlight h) => _isLocal(h) || _canFetch(h);

  Future<bool> _localExists(String path) =>
      widget.localFileExists != null ? widget.localFileExists!(path) : File(path).exists();

  /// O arquivo do lance: o MP4 do celular, se ainda estiver lá; se não, o da nuvem.
  Future<File> _videoOf(Highlight h) async {
    if (_isLocal(h)) {
      if (await _localExists(h.localPath!)) return File(h.localPath!);
      _localMissing.add(h.id);
    }
    if (!_canFetch(h)) throw const HighlightMediaFailure('Esse lance ainda está sendo enviado.');
    return _fetch(h.videoPath!);
  }

  @override
  void initState() {
    super.initState();
    _zoom.addListener(_onZoomChanged);
    if (_items.isNotEmpty) _load();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _loadToken++;
    _releaseController();
    _pageController.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _releaseController() {
    final old = _controller;
    _controller = null;
    _file = null;
    _seekingTo = null;
    _fast = false;
    if (old != null) {
      old.removeListener(_onTick);
      unawaited(old.dispose());
    }
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    _releaseController();
    final highlight = _current;

    // O MP4 ainda no celular de quem gravou: toca dele, sem internet (antes de subir).
    if (_isLocal(highlight)) {
      final exists = await _localExists(highlight.localPath!);
      if (token != _loadToken || !mounted) return;
      if (exists) {
        await _play(token, () async => File(highlight.localPath!));
        return;
      }
      // A fila já apagou (o lance subiu): segue pela nuvem.
      _localMissing.add(highlight.id);
    }

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

    if (_streams && await _playStream(token, path)) return;
    await _play(token, () => _fetch(path));
  }

  /// Com o repositório de verdade (ou um [PlayerScreen.streamVideo]), a nuvem toca por streaming.
  bool get _streams => widget.streamVideo != null || widget.loadVideo == null;

  /// Toca do cache, se o vídeo já foi baixado; se não, enquanto ele chega da nuvem.
  /// Devolve false se o streaming não abriu (o [_load] então baixa o arquivo inteiro).
  Future<bool> _playStream(int token, String path) async {
    if (token != _loadToken || !mounted) return true;
    setState(() {
      _stage = _Stage.loading;
      _message = 'Carregando o lance…';
    });
    VideoPlayerController? controller;
    try {
      if (widget.streamVideo == null) {
        final cached = await _media.cachedVideoFile(path);
        if (token != _loadToken || !mounted) return true;
        if (cached != null) {
          await _play(token, () async => cached);
          return true;
        }
      }
      final source = await (widget.streamVideo ?? _media.videoStream)(path);
      if (token != _loadToken || !mounted) return true;
      controller = (widget.streamControllerFactory ?? _networkController)(source);
      final startedAt = DateTime.now();
      await _show(token, controller, file: null);
      debugPrint('ClippoPlayer: streaming abriu em ${DateTime.now().difference(startedAt).inMilliseconds} ms');
      return true;
    } catch (e) {
      // Ex.: rede que não aceita streaming ou token recusado: o download dá o erro certo.
      debugPrint('ClippoPlayer: streaming falhou, baixando o arquivo inteiro ($e)');
      if (controller != null && !identical(controller, _controller)) unawaited(controller.dispose());
      if (identical(controller, _controller) && controller != null) return true; // já está na tela
      return token != _loadToken || !mounted;
    }
  }

  static VideoPlayerController _networkController(HighlightVideoStream source) =>
      VideoPlayerController.networkUrl(source.url, httpHeaders: source.headers);

  /// Abre o player com o arquivo de [source] (do celular ou baixado da nuvem).
  Future<void> _play(int token, Future<File> Function() source) async {
    if (token != _loadToken || !mounted) return;
    setState(() {
      _stage = _Stage.loading;
      _message = 'Carregando o lance…';
    });
    try {
      final file = await source();
      if (token != _loadToken || !mounted) return;
      await _show(token, (widget.controllerFactory ?? VideoPlayerController.file)(file), file: file);
    } catch (e) {
      if (token != _loadToken || !mounted) return;
      setState(() {
        _stage = _Stage.error;
        _message = HighlightMediaFailure.from(e).message;
      });
    }
  }

  /// Liga [controller] na tela. Lança se o vídeo não abrir.
  Future<void> _show(int token, VideoPlayerController controller, {required File? file}) async {
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
    _scheduleHide();
  }

  void _onTick() {
    if (!mounted) return;
    final value = _controller?.value;
    final target = _seekingTo;
    // O pulo terminou: o vídeo chegou perto de onde a pessoa tocou e já não está carregando.
    if (target != null && value != null && !value.isBuffering && (value.position - target).abs() < _seekTolerance) {
      _seekingTo = null;
    }
    setState(() {
      // O vídeo parou (chegou ao fim, por exemplo): os controles voltam.
      if (!(value?.isPlaying ?? false)) {
        _hideTimer?.cancel();
        _controlsVisible = true;
      }
    });
  }

  /// Para onde a pessoa pulou na barra, até o vídeo chegar lá (nulo: sem pulo em andamento).
  Duration? _seekingTo;
  static const Duration _seekTolerance = Duration(seconds: 1);

  /// O vídeo está esperando chegar mais um pedaço (streaming) ou pulando para outro ponto.
  bool get _buffering => (_controller?.value.isBuffering ?? false) || _seekingTo != null;

  bool get _playing => _controller?.value.isPlaying ?? false;

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null || _stage != _Stage.ready) return;
    if (controller.value.isPlaying) {
      _wantsPlay = false;
      _hideTimer?.cancel();
      await controller.pause();
      if (mounted) setState(() => _controlsVisible = true);
    } else {
      _wantsPlay = true;
      final value = controller.value;
      if (value.duration > Duration.zero && value.position >= value.duration) {
        await controller.seekTo(Duration.zero);
      }
      await controller.play();
      _scheduleHide();
    }
  }

  void _onPageChanged(int index) {
    _zoom.value = Matrix4.identity();
    setState(() {
      _currentIndex = index;
      _controlsVisible = true;
    });
    _hideTimer?.cancel();
    _load();
  }

  void _seekToFraction(double fraction) {
    final controller = _controller;
    if (controller == null) return;
    _seekTo(controller.value.duration * fraction.clamp(0.0, 1.0));
  }

  /// Avança (ou volta, com [forward] falso) [_skip], sem passar do fim nem do começo.
  void _skipBy({required bool forward}) {
    final controller = _controller;
    if (controller == null || _stage != _Stage.ready) return;
    final total = controller.value.duration;
    final from = _seekingTo ?? controller.value.position;
    final target = forward ? from + _skip : from - _skip;
    _seekTo(target > total ? total : (target < Duration.zero ? Duration.zero : target));
  }

  void _seekTo(Duration target) {
    final controller = _controller;
    if (controller == null) return;
    // A barra vai na hora para onde a pessoa tocou, mesmo antes de o vídeo chegar lá.
    setState(() => _seekingTo = target);
    _scheduleHide();
    controller.seekTo(target).whenComplete(() {
      // Rede de segurança: o pulo acabou e nada está carregando, mesmo que a posição não bata.
      if (!mounted || _seekingTo != target || !identical(controller, _controller)) return;
      if (!controller.value.isBuffering) setState(() => _seekingTo = null);
    });
  }

  /// Segurou o lado direito da tela (como no Instagram): toca em 2x até soltar.
  void _startFast(LongPressStartDetails details) {
    final controller = _controller;
    if (controller == null || _stage != _Stage.ready || !_playing) return;
    if (details.globalPosition.dx < MediaQuery.sizeOf(context).width * 2 / 3) return;
    HapticFeedback.selectionClick();
    _hideTimer?.cancel();
    setState(() {
      _fast = true;
      _controlsVisible = false;
    });
    unawaited(controller.setPlaybackSpeed(_fastSpeed));
  }

  void _stopFast() {
    if (!_fast) return;
    setState(() => _fast = false);
    final controller = _controller;
    if (controller != null) unawaited(controller.setPlaybackSpeed(1));
  }

  Future<void> _download() async {
    final highlight = _current;
    if (!_canAct(highlight) || _saving) return;
    setState(() {
      _saving = true;
      _downloadProgress = null;
    });
    void progress(double value) {
      if (mounted && _saving) setState(() => _downloadProgress = value);
    }

    try {
      // No celular: só copia da pasta do app para a galeria. Se não: baixa da nuvem.
      final local = _isLocal(highlight) && await _localExists(highlight.localPath!);
      if (local) {
        final file = File(highlight.localPath!);
        await (widget.saveFileToGallery != null ? widget.saveFileToGallery!(file) : _media.saveFileToGallery(file));
      } else {
        if (highlight.hasLocalVideo) _localMissing.add(highlight.id);
        if (!_canFetch(highlight)) throw const HighlightMediaFailure('Esse lance ainda está sendo enviado.');
        final path = highlight.videoPath!;
        await (widget.saveToGallery != null
            ? widget.saveToGallery!(path, progress)
            : _media.saveToGallery(path, onProgress: progress));
      }
      if (mounted) showHomeMessage(context, 'Lance salvo na galeria.');
    } catch (e) {
      if (mounted) showHomeMessage(context, HighlightMediaFailure.from(e).message);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _downloadProgress = null;
        });
        _scheduleHide();
      }
    }
  }

  Future<void> _share() async {
    final highlight = _current;
    if (!_canAct(highlight) || _sharing) return;
    setState(() => _sharing = true);
    try {
      final file = _file ?? await _videoOf(highlight);
      await (widget.shareVideo ?? _shareWithSystem)(file, highlight, widget.sessionName);
    } catch (e) {
      if (mounted) showHomeMessage(context, HighlightMediaFailure.from(e).message);
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
        _scheduleHide();
      }
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
        body: _items.isEmpty ? SafeArea(child: _buildEmpty()) : _buildPlayer(),
      ),
    );
  }

  /// Fechar, a sessão e o contador à esquerda; baixar e compartilhar à direita, só com ícone.
  Widget _topBar({String? counter, List<Widget> actions = const []}) {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.sessionName.isNotEmpty)
                  Text(
                    widget.sessionName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ClippoText.label.copyWith(color: ClippoBrand.captureTextMuted),
                  ),
                if (counter != null) ...[
                  const SizedBox(height: ClippoSpace.labelToValue),
                  Text(
                    counter,
                    style: ClippoText.label.copyWith(color: ClippoBrand.onWine, fontFeatures: ClippoText.tabular),
                  ),
                ],
              ],
            ),
          ),
          for (final action in actions) ...[
            const SizedBox(width: ClippoSpace.spaceS),
            action,
          ],
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

  /// Como os players de vídeo conhecidos: o vídeo ocupa a tela toda, deitado ou em pé, e os
  /// controles ficam por cima dele. Com o vídeo tocando eles somem sozinhos; tocar no vídeo
  /// traz de volta (ou esconde). Pausado, carregando ou com erro, ficam à vista.
  Widget _buildPlayer() {
    final highlight = _current;
    final controller = _controller;
    final value = controller?.value;
    final total = (value != null && value.duration > Duration.zero) ? value.duration : highlight.duration;
    final position = _seekingTo ?? value?.position ?? Duration.zero;
    final buffered = _bufferedFraction(value, total);
    final progress = total.inMilliseconds <= 0 ? 0.0 : position.inMilliseconds / total.inMilliseconds;
    final canAct = _canAct(highlight);
    final ready = _stage == _Stage.ready && controller != null;
    final visible = _controlsVisible || !_controlsCanHide;

    // A mesma chave sempre: virar o celular não recria as páginas nem perde o lance.
    final pages = PageView.builder(
      key: _pagesKey,
      controller: _pageController,
      // Com zoom, arrastar move o vídeo; sem zoom, troca de lance.
      physics: _zoomed || _pinching ? const NeverScrollableScrollPhysics() : null,
      itemCount: _items.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final isCurrent = index == _currentIndex;
        final Widget content;
        if (isCurrent && ready) {
          content = InteractiveViewer(
            transformationController: _zoom,
            minScale: 1,
            maxScale: _maxZoom,
            panEnabled: _zoomed,
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          );
        } else {
          content = AspectRatio(
            aspectRatio: 16 / 9,
            child: _VideoPlaceholder(
              stage: isCurrent ? _stage : _Stage.loading,
              message: isCurrent ? _message : null,
              onRetry: isCurrent && _stage == _Stage.error ? _load : null,
            ),
          );
        }
        // Toque em qualquer ponto (inclusive nas faixas pretas) mostra ou esconde os controles.
        // Segurar no terço direito toca em 2x enquanto o dedo estiver lá.
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onVideoTap,
          onLongPressStart: isCurrent && ready ? _startFast : null,
          onLongPressEnd: isCurrent && ready ? (_) => _stopFast() : null,
          onLongPressCancel: isCurrent && ready ? _stopFast : null,
          child: Center(child: content),
        );
      },
    );

    final controls = SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _topBar(
            counter: '${_currentIndex + 1} de ${_items.length}',
            actions: [
              _CircleAction(
                icon: 'download',
                semanticLabel: _saving ? clippoDownloadProgress(_downloadProgress) : 'Baixar',
                enabled: canAct,
                busy: _saving,
                progress: _downloadProgress,
                onPressed: _download,
              ),
              _CircleAction(
                icon: 'share',
                semanticLabel: _sharing ? 'Preparando…' : 'Compartilhar',
                enabled: canAct,
                busy: _sharing,
                onPressed: _share,
              ),
            ],
          ),
          // Trocar de lance é deslizando. No meio: voltar 5 s, play/pause e avançar 5 s.
          Expanded(
            child: ready
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ClippoSpace.gutter),
                    child: Row(
                      children: [
                        _CircleAction(
                          icon: 'back-5',
                          semanticLabel: 'Voltar 5 segundos',
                          onPressed: () => _skipBy(forward: false),
                        ),
                        Expanded(
                          child: Center(
                            child: _PlayPauseButton(
                              playing: _playing,
                              loading: _buffering,
                              enabled: true,
                              onPressed: _togglePlay,
                            ),
                          ),
                        ),
                        _CircleAction(
                          icon: 'forward-5',
                          semanticLabel: 'Avançar 5 segundos',
                          onPressed: () => _skipBy(forward: true),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ClippoSpace.gutter,
              ClippoSpace.spaceM,
              ClippoSpace.gutter,
              ClippoSpace.spaceM,
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
                _ProgressBar(
                  progress: progress,
                  buffered: buffered,
                  elapsedLabel: clippoPlayerProgress(position),
                  totalLabel: clippoPlayerProgress(total),
                  onSeek: ready ? _seekToFraction : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          onPointerDown: _fingerDown,
          onPointerUp: _fingerUp,
          onPointerCancel: _fingerUp,
          child: pages,
        ),
        // Com os controles escondidos, o "carregando" continua à vista no meio do vídeo.
        if (ready && _buffering && !visible) const IgnorePointer(child: Center(child: _BufferingBadge())),
        if (_fast)
          const IgnorePointer(
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: ClippoSpace.spaceL),
                  child: _FastBadge(),
                ),
              ),
            ),
          ),
        IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: ClippoMotion.reduced(context) ? Duration.zero : ClippoMotion.enable,
            curve: ClippoMotion.standard,
            child: ExcludeSemantics(
              excluding: !visible,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Sombra em cima e embaixo para os controles aparecerem sobre qualquer vídeo.
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            ClippoBrand.captureOverlay,
                            Colors.transparent,
                            Colors.transparent,
                            ClippoBrand.captureScrim,
                          ],
                          stops: [0, 0.22, 0.6, 1],
                        ),
                      ),
                    ),
                  ),
                  controls,
                ],
              ),
            ),
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
    this.busy = false,
    this.progress,
  });

  final String icon;
  final String semanticLabel;
  final VoidCallback onPressed;
  final bool enabled;

  /// Trabalhando (baixando, preparando): um anel gira em volta do ícone e o toque não repete.
  final bool busy;

  /// Quanto já foi (0 a 1) enquanto [busy]; nulo, o anel gira sem parar.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: enabled ? 1 : ClippoOpacity.disabled,
          child: ClippoPressable(
            onTap: enabled && !busy ? onPressed : null,
            child: SizedBox.square(
              dimension: ClippoSize.minTouchTarget,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
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
                    if (busy)
                      SizedBox.square(
                        dimension: ClippoSize.control,
                        child: CircularProgressIndicator(
                          value: progress?.clamp(0.0, 1.0),
                          strokeWidth: ClippoSize.border,
                          color: ClippoBrand.peach,
                        ),
                      ),
                  ],
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
    required this.enabled,
    required this.onPressed,
    this.loading = false,
  });

  final bool playing;
  final bool enabled;
  final VoidCallback onPressed;

  /// O vídeo está carregando: o botão mostra que está trabalhando, em vez de "pausar".
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: loading ? 'Carregando o vídeo' : (playing ? 'Pausar' : 'Reproduzir'),
      child: ExcludeSemantics(
        child: Opacity(
          opacity: enabled ? 1 : ClippoOpacity.disabled,
          child: ClippoPressable(
            onTap: enabled ? onPressed : null,
            child: Container(
              width: ClippoSize.playerPlayButton,
              height: ClippoSize.playerPlayButton,
              decoration: const BoxDecoration(color: ClippoBrand.wine, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: loading
                  ? const SizedBox.square(
                      dimension: ClippoSize.spinner,
                      child: CircularProgressIndicator(strokeWidth: ClippoSize.border, color: ClippoBrand.onWine),
                    )
                  : ClippoSvgIcon(playing ? 'pause' : 'play', size: ClippoSize.icon, color: ClippoBrand.onWine),
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
    this.buffered = 0,
    required this.elapsedLabel,
    required this.totalLabel,
    required this.onSeek,
  });

  final double progress;

  /// Até onde o vídeo já chegou do Storage (0 a 1), desenhado atrás do progresso.
  final double buffered;
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
              // 48 dp de altura para o dedo (eram 24); o traço continua fino no meio.
              child: SizedBox(
                height: ClippoSize.minTouchTarget,
                child: Center(child: ClipRRect(
                  borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                  child: SizedBox(
                    height: ClippoSize.meter,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: ClippoBrand.captureChipBorder),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: buffered.clamp(0.0, 1.0),
                          child: const Opacity(
                            opacity: ClippoOpacity.disabled,
                            child: ColoredBox(color: ClippoBrand.captureTextMuted),
                          ),
                        ),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: const ColoredBox(color: ClippoBrand.peach),
                        ),
                      ],
                    ),
                  ),
                )),
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

/// Até onde o vídeo já chegou, de 0 a 1: o fim do trecho baixado que contém a posição atual.
double _bufferedFraction(VideoPlayerValue? value, Duration total) {
  if (value == null || total <= Duration.zero) return 0;
  var end = Duration.zero;
  for (final range in value.buffered) {
    if (range.start <= value.position && range.end > end) end = range.end;
  }
  return end.inMilliseconds / total.inMilliseconds;
}

/// "2x" no topo enquanto a pessoa segura o lado direito da tela.
class _FastBadge extends StatelessWidget {
  const _FastBadge();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Velocidade 2x',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: ClippoSpace.spaceM, vertical: ClippoSpace.spaceS),
          decoration: BoxDecoration(
            color: ClippoBrand.captureOverlay,
            borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('2x', style: ClippoText.label.copyWith(color: ClippoBrand.onWine, fontFeatures: ClippoText.tabular)),
              const SizedBox(width: ClippoSpace.spaceS),
              const ClippoSvgIcon('fast-forward', size: ClippoSize.checkIcon, color: ClippoBrand.onWine),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sobre o vídeo enquanto ele espera chegar mais um pedaço ou pula para outro ponto.
class _BufferingBadge extends StatelessWidget {
  const _BufferingBadge();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Carregando o vídeo',
      child: Container(
        width: ClippoSize.navButton,
        height: ClippoSize.navButton,
        decoration: const BoxDecoration(color: ClippoBrand.captureOverlay, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: const SizedBox.square(
          dimension: ClippoSize.spinner,
          child: CircularProgressIndicator(strokeWidth: ClippoSize.border, color: ClippoBrand.peach),
        ),
      ),
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
