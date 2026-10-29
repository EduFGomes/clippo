import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Região das Cloud Functions. Precisa ser a mesma de backend/functions/src/config.ts.
const String functionsRegion = 'us-east1';

/// true = conecta no Emulator local (projeto demo-clippo, sem custo).
/// Para usar o projeto real no futuro: flutter run --dart-define=USE_EMULATOR=false
const bool useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: true);

/// Endereço do computador que roda o Emulator.
/// - Emulador do Android Studio: 10.0.2.2 (é o "localhost" do computador visto de dentro do emulador).
/// - Celular de verdade na mesma rede: o IP do computador, ex. --dart-define=EMULATOR_HOST=192.168.0.10
const String emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');

/// Inicia o Firebase e, no modo local, aponta Auth, Firestore e Functions para o Emulator.
Future<void> setupFirebase() async {
  if (!useEmulator) {
    // Projeto real: será configurado com `flutterfire configure` quando o clippo-dev existir.
    throw UnimplementedError('Projeto real ainda não configurado. Use o Emulator.');
  }

  // Projetos "demo-*" só existem no Emulator, então as chaves abaixo são de mentira de propósito.
  // A apiKey falsa precisa ter o formato de uma real ("AIza" + 35 caracteres): no Android o
  // Firebase Installations (usado pelas Functions) recusa qualquer outra com "Please set a valid API key".
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyDemoClippoEmulatorKey000000000000',
      appId: '1:000000000000:android:0000000000000000',
      messagingSenderId: '000000000000',
      projectId: 'demo-clippo',
    ),
  );

  await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8180);
  FirebaseFunctions.instanceFor(region: functionsRegion).useFunctionsEmulator(emulatorHost, 5001);
}
