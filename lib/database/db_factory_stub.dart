/// Native/default platforms (Android, iOS, desktop): sqflite already ships a
/// working platform factory, so there is nothing to configure.
///
/// This stub is swapped for `db_factory_web.dart` on the web via a conditional
/// import in [ChatDatabase], keeping web-only code out of native builds.
void configureDatabaseFactoryForWeb() {}
