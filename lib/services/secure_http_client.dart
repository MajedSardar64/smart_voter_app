import 'dart:io';

class SecureHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);

    // HttpCanary বা কোনো থার্ড-পার্টি প্রক্সি দিয়ে ফেক সার্টিফিকেট ডিটেক্ট হলে সাথে সাথে কানেকশন ব্লক করবে
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
          return false; // কোনো অবস্থাতেই ভুয়া সার্টিফিকেট গ্রহণ করবে না
        };

    client.connectionTimeout = const Duration(seconds: 15);
    return client;
  }
}
