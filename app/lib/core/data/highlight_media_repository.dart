import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

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

/// Envio e leitura dos vídeos e miniaturas dos lances no Storage (D17 em
/// docs/arquitetura.md › Acesso aos vídeos no Storage).
///
/// As regras do Storage liberam o vídeo só para os participantes da sessão. Por isso o
/// app **não usa `getDownloadURL()`**: essa URL tem um token que funciona para qualquer
/// pessoa, sem login, e furaria a R11. O vídeo é baixado pelo SDK (que passa pelas
/// regras) para uma pasta de cache do app, e o player toca o arquivo local.
class HighlightMediaRepository {
  HighlightMediaRepository({FirebaseStorage? storage, Future<Directory> Function()? cacheDir})
      : _storage = (() => storage ?? FirebaseStorage.instance),
        _cacheDir = cacheDir ?? getTemporaryDirectory;

  /// Teto do vídeo, igual ao de storage.rules e de highlights/validation.ts.
  static const int maxVideoBytes = 100 * 1024 * 1024;

  /// Teto da miniatura, igual ao de storage.rules.
  static const int maxThumbnailBytes = 1024 * 1024;

  static final RegExp _pathPattern = RegExp(
    r'^sessions/[A-Za-z0-9_-]{6,64}/highlights/[A-Za-z0-9_-]{6,64}/(video\.mp4|thumb\.jpg)$',
  );

  final FirebaseStorage Function() _storage;
  final Future<Directory> Function() _cacheDir;

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

  /// O vídeo do lance como arquivo local, baixado uma vez e guardado no cache.
  Future<File> videoFile(String storagePath) async {
    checkPath(storagePath, expectedFile: 'video.mp4');
    final dir = Directory('${(await _cacheDir()).path}/clippo-videos');
    final file = File('${dir.path}/${storagePath.replaceAll('/', '_')}');
    if (await file.exists() && await file.length() > 0) return file;
    await dir.create(recursive: true);
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
  Future<void> saveToGallery(String storagePath) async => saveFileToGallery(await videoFile(storagePath));

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
