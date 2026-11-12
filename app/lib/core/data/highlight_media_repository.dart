import 'dart:io';

import 'package:flutter/foundation.dart' show ValueChanged;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import 'package:clippo/core/firebase/firebase_setup.dart';

/// Erro ao enviar, baixar ou salvar o vídeo de um lance, com a mensagem pronta para a tela.
class HighlightMediaFailure implements Exception {
  const HighlightMediaFailure(this.message, {this.code});

  final String message;

  /// Código do Firebase. Nunca aparece na interface.
  final String? code;

  factory HighlightMediaFailure.from(Object error) {
    if (error is HighlightMediaFailure) return error;
    if (error is FirebaseException) {
      switch (error.code) {
        case 'unauthorized':
        case 'unauthenticated':
          return HighlightMediaFailure('Você não tem acesso a esse lance.', code: error.code);
        case 'object-not-found':
          return HighlightMediaFailure('Esse lance ainda está sendo enviado.', code: error.code);
        case 'retry-limit-exceeded':
        case 'canceled':
          return HighlightMediaFailure('A conexão caiu. Tente de novo.', code: error.code);
        default:
          return HighlightMediaFailure('Não foi possível carregar o lance.', code: error.code);
      }
    }
    return const HighlightMediaFailure('Não foi possível carregar o lance.');
  }

  @override
  String toString() => code == null ? message : '$message ($code)';
}

/// Onde o player busca o vídeo aos poucos (streaming): o endereço do arquivo no Storage e os
/// cabeçalhos que provam quem está pedindo. Sem link público: sem eles, o Storage recusa.
class HighlightVideoStream {
  const HighlightVideoStream({required this.url, required this.headers});

  final Uri url;
  final Map<String, String> headers;
}

/// Envio e leitura dos vídeos e miniaturas dos lances no Storage (D17 em
/// docs/arquitetura.md › Acesso aos vídeos no Storage).
///
/// As regras do Storage liberam o vídeo só para os participantes da sessão. Por isso o
/// app **não usa `getDownloadURL()`**: essa URL tem um token que funciona para qualquer
/// pessoa, sem login, e furaria a R11. Para assistir, o player busca o vídeo aos poucos
/// ([videoStream]) com o login e o App Check de quem pede, e as regras valem para cada
/// pedaço. Para baixar e compartilhar, o SDK (que também passa pelas regras) baixa o arquivo
/// inteiro para uma pasta de cache do app ([videoFile]). A miniatura vem do mesmo jeito
/// ([thumbnailFile]).
class HighlightMediaRepository {
  HighlightMediaRepository({
    FirebaseStorage? storage,
    Future<Directory> Function()? cacheDir,
    Future<String?> Function()? idToken,
    Future<String?> Function()? appCheckToken,
    String? emulatorOrigin,
  })  : _storage = (() => storage ?? FirebaseStorage.instance),
        _cacheDir = cacheDir ?? getTemporaryDirectory,
        _idToken = idToken ?? _currentIdToken,
        _appCheckToken = appCheckToken ?? (useEmulator ? _noAppCheck : _currentAppCheckToken),
        _emulatorOrigin = emulatorOrigin ?? (useEmulator ? 'http://$emulatorHost:9199' : null);

  static Future<String?> _currentIdToken() async => FirebaseAuth.instance.currentUser?.getIdToken();
  static Future<String?> _currentAppCheckToken() => FirebaseAppCheck.instance.getToken();
  static Future<String?> _noAppCheck() async => null;

  /// Teto do vídeo, igual ao de storage.rules e de highlights/validation.ts.
  static const int maxVideoBytes = 100 * 1024 * 1024;

  /// Teto da miniatura, igual ao de storage.rules.
  static const int maxThumbnailBytes = 1024 * 1024;

  static final RegExp _pathPattern = RegExp(
    r'^sessions/[A-Za-z0-9_-]{6,64}/highlights/[A-Za-z0-9_-]{6,64}/(video\.mp4|thumb\.jpg)$',
  );

  final FirebaseStorage Function() _storage;
  final Future<Directory> Function() _cacheDir;
  final Future<String?> Function() _idToken;
  final Future<String?> Function() _appCheckToken;

  /// O Storage do Emulator (`http://host:9199`); nulo no projeto real.
  final String? _emulatorOrigin;

  /// Envia o MP4 do lance para o caminho que o `saveSession` devolveu.
  ///
  /// O gatilho `onVideoUploaded` marca o highlight como `uploaded` quando o arquivo chega;
  /// só depois disso o app pode apagar a cópia local (R13). Seguro repetir: se o lance já
  /// está `uploaded`, as regras recusam e o vídeo certo continua lá.
  Future<void> uploadVideo({required String storagePath, required File localFile}) =>
      _upload(storagePath, localFile, 'video/mp4', maxVideoBytes, 'video.mp4');

  /// Envia a miniatura JPEG do lance (`thumb.jpg`, ao lado do vídeo).
  Future<void> uploadThumbnail({required String storagePath, required File localFile}) =>
      _upload(storagePath, localFile, 'image/jpeg', maxThumbnailBytes, 'thumb.jpg');

  Future<void> _upload(String path, File file, String contentType, int maxBytes, String name) async {
    checkPath(path, expectedFile: name);
    final size = await file.length();
    if (size == 0 || size > maxBytes) {
      throw const HighlightMediaFailure('Esse arquivo não pode ser enviado.');
    }
    try {
      await _storage().ref(path).putFile(file, SettableMetadata(contentType: contentType));
    } catch (e) {
      throw HighlightMediaFailure.from(e);
    }
  }

  /// Para o player tocar o vídeo enquanto ele chega (streaming), sem baixar tudo antes.
  ///
  /// É a mesma API que o SDK usa por baixo (`/v0/b/{bucket}/o/{caminho}?alt=media`), com o
  /// login (`Authorization: Firebase <token>`) e o App Check (`X-Firebase-AppCheck`) de quem
  /// pede: as regras do Storage (D17) valem para cada pedaço, e nada funciona sem login.
  Future<HighlightVideoStream> videoStream(String storagePath) async {
    checkPath(storagePath, expectedFile: 'video.mp4');
    final idToken = await _idToken();
    if (idToken == null || idToken.isEmpty) {
      throw const HighlightMediaFailure('Entre na sua conta para assistir.');
    }
    final appCheck = await _appCheckToken();
    final origin = _emulatorOrigin ?? 'https://firebasestorage.googleapis.com';
    final bucket = Uri.encodeComponent(_storage().bucket);
    return HighlightVideoStream(
      url: Uri.parse('$origin/v0/b/$bucket/o/${Uri.encodeComponent(storagePath)}?alt=media'),
      headers: {
        'Authorization': 'Firebase $idToken',
        if (appCheck != null && appCheck.isNotEmpty) 'X-Firebase-AppCheck': appCheck,
      },
    );
  }

  /// O vídeo já baixado antes (pelo "Baixar" ou "Compartilhar"), ou nulo. Tocar dele é instantâneo.
  Future<File?> cachedVideoFile(String storagePath) async {
    checkPath(storagePath, expectedFile: 'video.mp4');
    final file = await _cacheFileOf(storagePath);
    return await file.exists() && await file.length() > 0 ? file : null;
  }

  Future<File> _cacheFileOf(String storagePath) async =>
      File('${(await _cacheDir()).path}/clippo-videos/${storagePath.replaceAll('/', '_')}');

  /// O vídeo do lance como arquivo local, baixado uma vez e guardado no cache.
  ///
  /// [onProgress] recebe de 0 a 1 enquanto o arquivo chega (o "Baixando 40 %" do Player).
  /// Já no cache, chama 1 na hora.
  Future<File> videoFile(String storagePath, {ValueChanged<double>? onProgress}) async {
    final cached = await cachedVideoFile(storagePath);
    if (cached != null) {
      onProgress?.call(1);
      return cached;
    }
    final file = await _cacheFileOf(storagePath);
    await file.parent.create(recursive: true);
    final partial = File('${file.path}.part');
    try {
      final task = _storage().ref(storagePath).writeToFile(partial);
      final events = onProgress == null
          ? null
          : task.snapshotEvents.listen((s) {
              if (s.totalBytes > 0) onProgress((s.bytesTransferred / s.totalBytes).clamp(0.0, 1.0));
            }, onError: (Object _) {});
      try {
        await task;
      } finally {
        await events?.cancel();
      }
      onProgress?.call(1);
      return await partial.rename(file.path);
    } catch (e) {
      if (await partial.exists()) await partial.delete();
      throw HighlightMediaFailure.from(e);
    }
  }

  final Map<String, Future<File>> _thumbnailLoads = {};

  /// A miniatura do lance como arquivo local, baixada uma vez e guardada no cache.
  ///
  /// Como o vídeo, **sem `getDownloadURL()`**: o SDK baixa com o login e o App Check de quem
  /// pede, e as regras do Storage (D17) decidem. Falha (com [HighlightMediaFailure]) quando a
  /// miniatura ainda não subiu ou o lance é antigo e não tem uma: a tela mostra o desenho de
  /// quadra no lugar.
  Future<File> thumbnailFile(String storagePath) {
    checkPath(storagePath, expectedFile: 'thumb.jpg');
    // Vários cards pedindo a mesma miniatura ao mesmo tempo dividem um download só.
    // (Bloco, e não `=>`: o `remove` devolve este mesmo Future, e o whenComplete esperaria por ele.)
    return _thumbnailLoads[storagePath] ??= _loadThumbnail(storagePath).whenComplete(() {
      _thumbnailLoads.remove(storagePath);
    });
  }

  Future<File> _loadThumbnail(String storagePath) async {
    final file = File('${(await _cacheDir()).path}/clippo-thumbs/${storagePath.replaceAll('/', '_')}');
    if (await file.exists() && await file.length() > 0) return file;
    await file.parent.create(recursive: true);
    final partial = File('${file.path}.part');
    try {
      await _storage().ref(storagePath).writeToFile(partial);
      return await partial.rename(file.path);
    } catch (e) {
      if (await partial.exists()) await partial.delete();
      throw HighlightMediaFailure.from(e);
    }
  }

  /// "Baixar": salva o vídeo do lance na galeria do celular (R11: todo participante baixa).
  Future<void> saveToGallery(String storagePath, {ValueChanged<double>? onProgress}) async =>
      saveFileToGallery(await videoFile(storagePath, onProgress: onProgress));

  /// "Baixar" de um vídeo que já está no celular (o MP4 da pasta do app, antes de subir):
  /// só copia para a galeria, sem passar pela nuvem.
  Future<void> saveFileToGallery(File file) async {
    try {
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      await Gal.putVideo(file.path, album: 'Clippo');
    } on GalException catch (e) {
      throw HighlightMediaFailure('Não foi possível salvar na galeria.', code: e.type.name);
    }
  }

  /// Confere o caminho antes de chamar o Storage (o mesmo padrão de storage.rules).
  static void checkPath(String path, {required String expectedFile}) {
    if (!_pathPattern.hasMatch(path) || !path.endsWith('/$expectedFile')) {
      throw const HighlightMediaFailure('Não foi possível carregar o lance.');
    }
  }
}

HighlightMediaRepository? _highlightMediaRepository;

/// Instância única usada pelo app. Só acesse depois de setupFirebase() (main.dart).
HighlightMediaRepository get highlightMediaRepository =>
    _highlightMediaRepository ??= HighlightMediaRepository();
