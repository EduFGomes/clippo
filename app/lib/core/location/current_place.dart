import 'package:flutter/widgets.dart' show Locale;

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'package:clippo/core/validation/input_validation.dart';

/// Por que não deu para usar a localização, com a frase pronta para ir embaixo do campo Local.
class LocationFailure implements Exception {
  const LocationFailure(this.message, {this.blocked = false});

  final String message;

  /// A permissão foi negada de vez: só nas configurações do celular dá para liberar.
  final bool blocked;

  @override
  String toString() => message;
}

/// "Usar localização atual" no campo Local (decidido pelo grupo em 12/11/2026): o GPS só é
/// pedido quando a pessoa toca no botão, nunca sozinho. O resultado é um texto comum, que a
/// pessoa pode editar ou apagar (o local não precisa ser um lugar real).
///
/// A posição vira o nome do bairro pelo serviço do próprio Android (sem custo), que precisa
/// de internet.
class CurrentPlace {
  const CurrentPlace();

  /// Quanto esperar o GPS responder.
  static const Duration timeout = Duration(seconds: 15);

  Future<String> label() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure('Ligue a localização do celular e tente de novo.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        'A localização está bloqueada para o Clippo. Libere nas configurações do celular ou digite o local.',
        blocked: true,
      );
    }
    if (permission == LocationPermission.denied) {
      throw const LocationFailure('Sem a permissão de localização. Digite o local.');
    }

    final Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: timeout),
      );
    } catch (_) {
      throw const LocationFailure('Não deu para achar onde você está. Tente de novo ou digite o local.');
    }

    final List<Placemark> places;
    try {
      // Nomes em português (rua, bairro), como no resto do app.
      places = await Geocoding(locale: const Locale('pt', 'BR'))
          .placemarkFromCoordinates(position.latitude, position.longitude);
    } catch (_) {
      throw const LocationFailure('Não deu para achar o nome do lugar. Confira a internet ou digite o local.');
    }
    final label = places.isEmpty
        ? null
        : placeLabel(
            street: places.first.thoroughfare,
            neighborhood: places.first.subLocality,
            city: places.first.locality ?? places.first.subAdministrativeArea,
          );
    if (label == null) {
      throw const LocationFailure('Não deu para achar o nome do lugar. Digite o local.');
    }
    return label;
  }
}

/// "Vila Mariana": só o bairro, que é curto e é como se fala de onde foi a partida (decidido
/// em 12/11/2026; "Rua, Bairro" ficava comprido). Sem bairro, a cidade; sem os dois, a rua.
/// Cabe no limite do campo Local ([locationMax]), cortado numa palavra inteira. Nulo quando
/// não há nada útil.
String? placeLabel({String? street, String? neighborhood, String? city}) {
  String? clean(String? s) {
    final t = s?.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t == null || t.isEmpty ? null : t;
  }

  var label = clean(neighborhood) ?? clean(city) ?? clean(street);
  if (label == null) return null;
  if (label.length > locationMax) {
    final cut = label.substring(0, locationMax);
    final space = cut.lastIndexOf(' ');
    label = (space > 0 ? cut.substring(0, space) : cut).replaceAll(RegExp(r'[,\s]+$'), '');
  }
  return label;
}
