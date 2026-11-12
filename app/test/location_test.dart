import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/location/current_place.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/validation/input_validation.dart';
import 'package:clippo/core/widgets/clippo_location_button.dart';

Widget _app(Widget child) =>
    MaterialApp(theme: clippoTheme(Brightness.light), home: Scaffold(body: Center(child: child)));

void main() {
  group('nome do lugar', () {
    test('rua e bairro; sem rua, bairro e cidade', () {
      expect(placeLabel(street: 'Rua das Flores', neighborhood: 'Vila Mariana', city: 'São Paulo'),
          'Rua das Flores, Vila Mariana');
      expect(placeLabel(neighborhood: 'Vila Mariana', city: 'São Paulo'), 'Vila Mariana, São Paulo');
      expect(placeLabel(city: 'Campinas'), 'Campinas');
    });

    test('sem nada útil, nulo; espaços e repetidos limpos', () {
      expect(placeLabel(), isNull);
      expect(placeLabel(street: '  ', neighborhood: ''), isNull);
      expect(placeLabel(street: ' Av.  Paulista ', neighborhood: 'Av. Paulista'), 'Av. Paulista');
    });

    test('nome longo é cortado numa palavra inteira, dentro do limite do campo', () {
      final label = placeLabel(
        street: 'Avenida Doutor Ricardo Jafet Engenheiro Armando de Arruda Pereira',
        neighborhood: 'Jardim da Saúde',
      )!;
      expect(label.length, lessThanOrEqualTo(locationMax));
      expect(label.endsWith(' '), isFalse);
      expect(label.endsWith(','), isFalse);
      expect(validateLocation(label), isNull);
    });
  });

  group('botão "Usar localização atual"', () {
    testWidgets('achou: entrega o nome; enquanto busca, avisa e não aceita outro toque', (tester) async {
      final gps = Completer<String>();
      String? place;
      var asked = 0;
      await tester.pumpWidget(_app(ClippoLocationButton(
        findPlace: () {
          asked++;
          return gps.future;
        },
        onPlace: (p) => place = p,
        onError: (_) => fail('não devia dar erro'),
      )));

      await tester.tap(find.text('Usar localização atual'));
      await tester.pump();
      expect(find.text('Buscando onde você está…'), findsOneWidget);
      await tester.tap(find.text('Buscando onde você está…'));
      expect(asked, 1);

      gps.complete('Rua das Flores, Vila Mariana');
      await tester.pumpAndSettle();
      expect(place, 'Rua das Flores, Vila Mariana');
      expect(find.text('Usar localização atual'), findsOneWidget);
    });

    testWidgets('não deu: a frase vai para a tela', (tester) async {
      String? error;
      await tester.pumpWidget(_app(ClippoLocationButton(
        findPlace: () async => throw const LocationFailure('Ligue a localização do celular e tente de novo.'),
        onPlace: (_) => fail('não devia achar'),
        onError: (e) => error = e,
      )));
      await tester.tap(find.text('Usar localização atual'));
      await tester.pump();
      expect(error, 'Ligue a localização do celular e tente de novo.');
    });
  });
}
