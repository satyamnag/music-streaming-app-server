library connect;

import 'dart:async';
import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/audio_player/state.dart';
import 'package:sangeet/services/audio_player/playlist_mode.dart';

part 'connect.freezed.dart';
part 'connect.g.dart';

part 'ws_event.dart';
part 'load.dart';
