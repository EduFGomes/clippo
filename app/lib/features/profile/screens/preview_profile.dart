import 'package:flutter/material.dart';

import 'package:clippo/app.dart';
import 'package:clippo/features/profile/screens/profile_screen.dart';

void main() {
  runApp(
    ClippoApp(
      home: ProfileScreen(onSignOut: () {}),
    ),
  );
}
