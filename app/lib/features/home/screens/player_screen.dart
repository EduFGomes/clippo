import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'package:clippo/core/data/favorites_repository.dart';
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

/// Player: o vídeo de um lance em tela cheia sobre o preto (docs/produto.md › 4.4).
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

  /// Controle de visibilidade das opções sobre o vídeo em tela cheia (opacidade transparente).
  bool _overlayVisible = true;

  /// Reações por highlight ID: mapa de emoji e contagem (em memória).
  final Map<String, Map<String, int>> _reactions = <String, Map<String, int>>{};

  /// Reação atual do usuário por highlight ID.
  final Map<String, String> _userReactions = <String, String>{};

  /// Comentários por highlight ID (em memória).
  final Map<String, List<_Comment>> _comments = <String, List<_Comment>>{};

  Highlight get _current => _items[_currentIndex];

  void _toggleFavorite(Highlight highlight) {
    setState(() {
      favoritesRepository.toggleFavorite(highlight);
      if (favoritesRepository.isFavorite(highlight.id)) {
        showHomeMessage(context, 'Lance favoritado e visível no seu perfil!');
      } else {
        showHomeMessage(context, 'Removido dos favoritos.');
      }
    });
  }

  void _addReaction(String id, String emoji) {
    setState(() {
      final counts = _reactions.putIfAbsent(id, () => <String, int>{});
      counts[emoji] = (counts[emoji] ?? 0) + 1;
      _userReactions[id] = emoji;
    });
  }

  void _openReactionsSheet(String id) {
    final emojis = [
      '🔥', '👏', '⚽', '🎯', '❤️', '😱',
      '🧤', '⚡', '💪', '🎩', '🤩', '🚀',
      '👀', '🎉', '🏆', '💯', '🤯', '👟',
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ClippoBrand.wine,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ClippoRadius.radiusField)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(ClippoSpace.gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Escolha um emoji para reagir',
                style: ClippoText.titleS.copyWith(color: ClippoBrand.onWine),
              ),
              const SizedBox(height: ClippoSpace.spaceS),
              Text(
                'Qualquer pessoa pode reagir e repetir o emoji.',
                style: ClippoText.body.copyWith(color: ClippoBrand.captureTextMuted),
              ),
              const SizedBox(height: ClippoSpace.spaceM),
              Wrap(
                spacing: ClippoSpace.spaceM,
                runSpacing: ClippoSpace.spaceM,
                alignment: WrapAlignment.center,
                children: [
                  for (final emoji in emojis)
                    InkWell(
                      borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                      onTap: () {
                        Navigator.of(context).pop();
                        _addReaction(id, emoji);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(ClippoSpace.spaceM),
                        decoration: BoxDecoration(
                          color: ClippoBrand.wineDeep,
                          shape: BoxShape.circle,
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: ClippoSpace.spaceM),
            ],
          ),
        );
      },
    );
  }

  void _openCommentsSheet(String id) {
    final list = _comments.putIfAbsent(id, () => [
      _Comment(author: 'Rafa Costa', text: 'Golaço demais! 🔥', timeAgo: 'há 10 min'),
      _Comment(author: 'Bruno Lima', text: 'Boa jogada!', timeAgo: 'há 25 min'),
    ]);
    final controller = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ClippoBrand.wine,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ClippoRadius.radiusField)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                ClippoSpace.gutter,
                ClippoSpace.gutter,
                ClippoSpace.gutter,
                MediaQuery.of(ctx).viewInsets.bottom + ClippoSpace.gutter,
              ),
              child: SizedBox(
                height: 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Comentários (${list.length})',
                      style: ClippoText.titleS.copyWith(color: ClippoBrand.onWine),
                    ),
                    const SizedBox(height: ClippoSpace.spaceM),
                    Expanded(
                      child: list.isEmpty
                          ? Center(
                              child: Text(
                                'Nenhum comentário ainda. Seja o primeiro!',
                                style: ClippoText.body.copyWith(color: ClippoBrand.captureTextMuted),
                              ),
                            )
                          : ListView.separated(
                              itemCount: list.length,
                              separatorBuilder: (_, _) => const SizedBox(height: ClippoSpace.spaceS),
                              itemBuilder: (ctx, i) {
                                final c = list[i];
                                return Container(
                                  padding: const EdgeInsets.all(ClippoSpace.spaceM),
                                  decoration: BoxDecoration(
                                    color: ClippoBrand.wineDeep,
                                    borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            c.author,
                                            style: ClippoText.label.copyWith(
                                              color: ClippoBrand.onWine,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            c.timeAgo,
                                            style: ClippoText.label.copyWith(
                                              color: ClippoBrand.captureTextMuted,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: ClippoSpace.spaceXs),
                                      Text(
                                        c.text,
                                        style: ClippoText.body.copyWith(color: ClippoBrand.onWine),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: ClippoSpace.spaceM),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            style: ClippoText.input.copyWith(color: ClippoBrand.onWine),
                            decoration: InputDecoration(
                              hintText: 'Adicionar um comentário...',
                              hintStyle: ClippoText.body.copyWith(color: ClippoBrand.captureTextMuted),
                              filled: true,
                              fillColor: ClippoBrand.wineDeep,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: ClippoSpace.spaceM,
                                vertical: ClippoSpace.spaceS,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: ClippoSpace.spaceS),
                        IconButton(
                          icon: const Icon(Icons.send, color: ClippoBrand.peach),
                          onPressed: () {
                            final text = controller.text.trim();
                            if (text.isEmpty) return;
                            setSheetState(() {
                              list.add(_Comment(author: 'Você', text: text, timeAgo: 'agora'));
                            });
                            controller.clear();
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

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
    _seekingTo = null;
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
  }

  void _onTick() {
    if (!mounted) return;
    final value = _controller?.value;
    final target = _seekingTo;
    // O pulo terminou: o vídeo chegou perto de onde a pessoa tocou e já não está carregando.
    if (target != null && value != null && !value.isBuffering && (value.position - target).abs() < _seekTolerance) {
      _seekingTo = null;
    }
    setState(() {});
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
    final target = total * fraction.clamp(0.0, 1.0);
    // A barra vai na hora para onde a pessoa tocou, mesmo antes de o vídeo chegar lá.
    setState(() => _seekingTo = target);
    controller.seekTo(target).whenComplete(() {
      // Rede de segurança: o pulo acabou e nada está carregando, mesmo que a posição não bata.
      if (!mounted || _seekingTo != target || !identical(controller, _controller)) return;
      if (!controller.value.isBuffering) setState(() => _seekingTo = null);
    });
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

  Widget _topBar({String? counter, VoidCallback? onDownload, bool canDownload = false}) {
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
          // Botão de baixar no canto superior direito
          if (onDownload != null)
            Semantics(
              button: true,
              label: 'Baixar',
              child: InkWell(
                borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                onTap: onDownload,
                child: Tooltip(
                  message: _saving ? clippoDownloadProgress(_downloadProgress) : 'Baixar',
                  child: Container(
                    width: ClippoSize.minTouchTarget,
                    height: ClippoSize.minTouchTarget,
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        _saving ? Icons.downloading : Icons.download,
                        color: canDownload ? ClippoBrand.onWine : ClippoBrand.captureTextMuted,
                        size: ClippoSize.fieldIcon,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
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
    final position = _seekingTo ?? value?.position ?? Duration.zero;
    final buffered = _bufferedFraction(value, total);
    final progress = total.inMilliseconds <= 0 ? 0.0 : position.inMilliseconds / total.inMilliseconds;
    final canFetch = _canAct(highlight);
    final ready = _stage == _Stage.ready && controller != null;

    final isFav = favoritesRepository.isFavorite(highlight.id);
    final userEmoji = _userReactions[highlight.id];
    final counts = _reactions[highlight.id] ?? <String, int>{};
    final commentsCount = (_comments[highlight.id]?.length) ?? 0;
    final counter = '${_currentIndex + 1} de ${_items.length}';

    final videoContent = PageView.builder(
      key: _pagesKey,
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
                onTap: () {
                  setState(() => _overlayVisible = !_overlayVisible);
                },
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _overlayVisible = !_overlayVisible),
          child: Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _VideoPlaceholder(
                stage: isCurrent ? _stage : _Stage.loading,
                message: isCurrent ? _message : null,
                onRetry: isCurrent && _stage == _Stage.error ? _load : null,
              ),
            ),
          ),
        );
      },
    );

    final bar = _ProgressBar(
      progress: progress,
      buffered: buffered,
      elapsedLabel: clippoPlayerProgress(position),
      totalLabel: clippoPlayerProgress(total),
      onSeek: ready ? _seekToFraction : null,
    );

    // Visualização em tela cheia com overlay com opacidade transparente ao tocar
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Vídeo ocupando toda a tela
        videoContent,

        // 2. Indicador de buffer / pausa central se visível
        if (_buffering)
          const Center(child: _BufferingBadge())
        else if (!_playing && ready)
          Center(
            child: GestureDetector(
              onTap: _togglePlay,
              child: const _PlayBadge(),
            ),
          ),

        // 3. Controles superiores (Topo com contador, fechar, etc.)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: _overlayVisible ? 1.0 : 0.0,
            duration: ClippoMotion.focus,
            child: IgnorePointer(
              ignoring: !_overlayVisible,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: _topBar(
                  counter: counter,
                  canDownload: canFetch,
                  onDownload: canFetch ? (_saving ? null : _download) : () => showHomeMessage(context, 'O vídeo ainda está sendo processado.'),
                ),
              ),
            ),
          ),
        ),

        // 4. Barra lateral de ações interativas (Favoritar, Reagir, Comentar)
        Positioned(
          right: ClippoSpace.gutter,
          bottom: 230,
          child: AnimatedOpacity(
            opacity: _overlayVisible ? 1.0 : 0.0,
            duration: ClippoMotion.focus,
            child: IgnorePointer(
              ignoring: !_overlayVisible,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Favoritar
                  Semantics(
                    button: true,
                    label: isFav ? 'Remover favorito' : 'Favoritar lance',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                      onTap: () => _toggleFavorite(highlight),
                      child: Container(
                        padding: const EdgeInsets.all(ClippoSpace.spaceM),
                        decoration: BoxDecoration(
                          color: isFav ? ClippoBrand.peach : Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFav ? Icons.star : Icons.star_border,
                          color: isFav ? ClippoBrand.wine : ClippoBrand.onWine,
                          size: ClippoSize.fieldIcon,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: ClippoSpace.spaceS),
                  Text(
                    'Favoritar',
                    style: ClippoText.label.copyWith(color: ClippoBrand.onWine, fontSize: 10),
                  ),
                  const SizedBox(height: ClippoSpace.spaceL),

                  // Reagir
                  Semantics(
                    button: true,
                    label: 'Reagir ao lance',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                      onTap: () => _openReactionsSheet(highlight.id),
                      child: Container(
                        padding: const EdgeInsets.all(ClippoSpace.spaceM),
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          userEmoji ?? '🔥',
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: ClippoSpace.spaceS),
                  Text(
                    counts.values.fold<int>(0, (a, b) => a + b).toString(),
                    style: ClippoText.label.copyWith(color: ClippoBrand.onWine, fontSize: 11),
                  ),
                  const SizedBox(height: ClippoSpace.spaceL),

                  // Comentar
                  Semantics(
                    button: true,
                    label: 'Comentários',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                      onTap: () => _openCommentsSheet(highlight.id),
                      child: Container(
                        padding: const EdgeInsets.all(ClippoSpace.spaceM),
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline,
                          color: ClippoBrand.onWine,
                          size: ClippoSize.fieldIcon,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: ClippoSpace.spaceS),
                  Text(
                    commentsCount.toString(),
                    style: ClippoText.label.copyWith(color: ClippoBrand.onWine, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 5. Controles inferiores (título do lance, barra do vídeo, botão de play e botões de baixar/compartilhar)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedOpacity(
            opacity: _overlayVisible ? 1.0 : 0.0,
            duration: ClippoMotion.focus,
            child: IgnorePointer(
              ignoring: !_overlayVisible,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  ClippoSpace.gutter,
                  ClippoSpace.spaceL,
                  ClippoSpace.gutter,
                  ClippoSpace.screenBottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                            ],
                          ),
                        ),
                        const SizedBox(width: ClippoSpace.spaceM),
                        // Botão padrão de compartilhar no canto inferior
                        Semantics(
                          button: true,
                          label: 'Compartilhar',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                            onTap: canFetch ? (_sharing ? null : _share) : () => showHomeMessage(context, 'O vídeo ainda está sendo processado.'),
                            child: Container(
                              width: ClippoSize.avatarLarge,
                              height: ClippoSize.avatarLarge,
                              decoration: const BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.share,
                                  color: canFetch ? ClippoBrand.onWine : ClippoBrand.captureTextMuted,
                                  size: ClippoSize.fieldIcon,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ClippoSpace.spaceM),
                    bar,
                    const SizedBox(height: ClippoSpace.spaceM),
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
                          loading: _stage == _Stage.loading || (ready && _buffering),
                          enabled: ready,
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
            ),
          ),
        ),
      ],
    );
  }
}

class _Comment {
  _Comment({required this.author, required this.text, required this.timeAgo});
  final String author;
  final String text;
  final String timeAgo;
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
          child: ClippoPressable(
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
