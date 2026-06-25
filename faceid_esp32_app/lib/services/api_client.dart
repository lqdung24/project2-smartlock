import 'package:dio/dio.dart';
import 'package:faceid_esp32_app/config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  final Dio dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  String? _inMemoryAccessToken;

  ApiClient() 
    : dio = Dio(BaseOptions(baseUrl: AppConfig.serverBaseUrl)) {

    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          _inMemoryAccessToken ??= await _secureStorage.read(key: 'access_token');
          
          if (_inMemoryAccessToken != null) {
            options.headers['Authorization'] = 'Bearer $_inMemoryAccessToken';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401 && e.requestOptions.path != AppConfig.refreshTokenEndpoint) {
            try {
              final refreshToken = await _secureStorage.read(key: 'refresh_token');
              if (refreshToken == null) {
                await performLogout();
                return handler.next(e);
              }

              final refreshDio = Dio(BaseOptions(baseUrl: dio.options.baseUrl));
              final response = await refreshDio.post(
                AppConfig.refreshTokenEndpoint,
                data: {'refresh_token': refreshToken},
              );

              if (response.statusCode == 200 || response.statusCode == 201) {
                final newAccessToken = response.data['data']['access_token'];
                final newRefreshToken = response.data['data']['refresh_token'];
                
                await saveTokens(newAccessToken, newRefreshToken);
                setInMemoryToken(newAccessToken);

                e.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                final clonedRequest = await dio.fetch(e.requestOptions);
                return handler.resolve(clonedRequest);
              }
            } on DioException catch (refreshError) {
              if (refreshError.response?.statusCode == 401) {
                await performLogout();
              }
              return handler.next(e);
            }
          }
          return handler.next(e);
        },
      ),
    );
  }
  
  Future<void> performLogout() async {
    setInMemoryToken(null);
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
  }
  
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _secureStorage.write(key: 'access_token', value: accessToken);
    await _secureStorage.write(key: 'refresh_token', value: refreshToken);
  }
  
  void setInMemoryToken(String? token) {
     _inMemoryAccessToken = token;
  }
}
