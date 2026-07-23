import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final Dio client = Dio(BaseOptions(
    // OJO: Es vital que termine con la diagonal al final (/api/)
    baseUrl: 'https://vivra-915z.onrender.com/api/', 
    headers: {
      'Accept': 'application/json', // Esto evita el 404 engañoso de Laravel
      'Content-Type': 'application/json',
    },
  ));
  
  final storage = const FlutterSecureStorage();

  ApiService() {
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Extraemos el token del login y lo adjuntamos como pase VIP
          String? token = await storage.read(key: 'auth_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }
}