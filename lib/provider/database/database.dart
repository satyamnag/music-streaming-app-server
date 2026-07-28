import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/models/database/database.dart';

final databaseProvider = Provider((ref) => AppDatabase());
