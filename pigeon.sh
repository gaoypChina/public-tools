#!/bin/bash

flutter pub run pigeon \
  --input pigeon/app.dart \
  --dart_out lib/pigeon/app.dart \
  --objc_header_out macos/Runner/pigeon/app.h \
  --objc_source_out macos/Runner/pigeon/app.m \
  --objc_prefix PBC