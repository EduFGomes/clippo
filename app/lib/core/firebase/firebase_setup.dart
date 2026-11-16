import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;

import 'package:clippo/core/widgets/clippo_avatar.dart';
import 'package:clippo/firebase_options.dart';

/// Região das Cloud Functions chamáveis. Precisa ser a mesma de REGION em backend/functions/src/config.ts
/// (só o Storage fica em us-east1, e o app não chama nenhuma função de lá).
const String functionsRegion = 'southamerica-east1';

/// true = conecta no Emulator local (projeto demo-clippo, sem custo). É o padrão.
/// Projeto real (clippo-dev): flutter run --dart-define=USE_EMULATOR=false
const bool useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: true);

/// Endereço do computador que roda o Emulator.
/// - Emulador do Android Studio: 10.0.2.2 (é o "localhost" do computador visto de dentro do emulador).
/// - Celular de verdade na mesma rede: o IP do computador, ex. --dart-define=EMULATOR_HOST=192.168.0.10
const String emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');

/// Token de depuração do App Check deste computador/celular (só em builds de debug).
/// Cada pessoa gera o seu e cadastra no console (App Check › Apps › Gerenciar tokens de
/// depuração). É segredo: passe por --dart-define=APP_CHECK_DEBUG_TOKEN=..., nunca no código.
/// Vazio = o SDK gera um e mostra no log ("Enter this debug secret into the allow list...").
const String appCheckDebugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');

/// App Check prova para o Firebase que a chamada veio do app de verdade, e não de um script
/// usando as chaves de firebase_options.dart. Só no projeto real: o Emulator não confere.
/// - Release: Play Integrity (precisa do app no Google Play Console e do SHA-256 no Firebase).
/// - Debug: provedor de depuração, liberado pelo token cadastrado no console.
Future<void> _activateAppCheck() async {
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kReleaseMode
        ? const AndroidPlayIntegrityProvider()
        : AndroidDebugProvider(
            debugToken: appCheckDebugToken.isEmpty ? null : appCheckDebugToken,
          ),
  );
}

/// Inicia o Firebase e, no modo local, aponta Auth, Firestore, Functions e Storage para o Emulator.
Future<void> setupFirebase() async {
  if (!useEmulator) {
    // Projeto real clippo-dev. As chaves vêm de lib/firebase_options.dart, gerado por
    // `flutterfire configure --project=clippo-dev --platforms=android` (rode de novo se o app mudar).
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await _activateAppCheck();
    return;
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
      storageBucket: 'demo-clippo.appspot.com',
    ),
  );

  // A foto do perfil vem com o endereço do Storage do Emulator visto pela Function (127.0.0.1);
  // o celular alcança o computador por [emulatorHost].
  ClippoAvatar.resolveUrl =
      (url) => url.replaceFirst(RegExp(r'^http://(127\.0\.0\.1|localhost):'), 'http://$emulatorHost:');

  await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8180);
  FirebaseFunctions.instanceFor(region: functionsRegion).useFunctionsEmulator(emulatorHost, 5001);
  await FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
}
