import 'package:dio/dio.dart';

final globalDio = Dio(
  BaseOptions(
    validateStatus: (status) => status != null && status < 500,
  ),
);
