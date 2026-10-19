library;

export 'learning_database_connection_stub.dart'
    if (dart.library.io) 'learning_database_connection_native.dart'
    if (dart.library.js_interop) 'learning_database_connection_web.dart';
