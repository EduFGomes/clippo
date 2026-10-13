import 'package:flutter/material.dart';

import 'package:clippo/app.dart';
import 'package:clippo/core/firebase/firebase_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupFirebase();
  runApp(const ClippoApp());
}
