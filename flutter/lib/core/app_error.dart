enum AppErrorKind { forbidden, notFound, server, connection }

class AppErrorInfo {
  const AppErrorInfo(this.kind);

  final AppErrorKind kind;

  int get statusCode => switch (kind) {
        AppErrorKind.forbidden => 403,
        AppErrorKind.notFound => 404,
        AppErrorKind.server => 500,
        AppErrorKind.connection => 503,
      };
}
