import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:clippo/app.dart';
import 'package:clippo/core/device/screen_orientation.dart';
import 'package:clippo/core/firebase/firebase_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  // Em pé em todo o app; só a Gravação e a tela cheia do Player giram.
  await ClippoOrientation.portrait();
  await setupFirebase();
  runApp(const ClippoApp());
}

/// A licença OFL pede que o texto dela acompanhe as fontes embutidas.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final family in ['Anton', 'Archivo']) {
      final text = await rootBundle.loadString('assets/fonts/$family-OFL.txt');
      yield LicenseEntryWithLineBreaks([family], text);
    }
  });
}
