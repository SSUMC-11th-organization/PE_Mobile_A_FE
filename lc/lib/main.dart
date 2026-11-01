import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/movie_log_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 저장된 Token을 읽기 전에 .env 로드를 끝내야 한다.
  await dotenv.load(fileName: '.env');
  runApp(const MovieLogApp());
}
