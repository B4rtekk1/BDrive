import 'package:dio/dio.dart';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:serverapp/models/file_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:path/path.dart' as path;

class ApiService {
  final Dio dio = Dio();
  late final String baseUrl;
  late final String apiKey;
  bool isInitialized = false;
  static Logger logger = Logger();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        "850161344748-mdre4qoto13gbmrdvm82jsc630jv2hsa.apps.googleusercontent.com",
    serverClientId:
        "850161344748-lc6gvdshh3tee896is6h1si9ajccovoh.apps.googleusercontent.com",
    scopes: [
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
  );

  ApiService() {
    baseUrl = dotenv.env["BASE_URL"] ?? '';
    apiKey = dotenv.env["API_KEY"] ?? '';

    if (baseUrl.isEmpty || apiKey.isEmpty) {
      logger.e("Environment variables are not set");
      throw Exception("Environment variables are not set");
    }

    dio.options.headers = {
      "X-Api-Key": apiKey,
      "Authorization": "",
    };
  }

  Future<void> init() async {
    if (!isInitialized) {
      await _addTokenHeader();
      isInitialized = true;
      logger.i("ApiService initialized with headers: ${dio.options.headers}");
    }
  }

  Future<void> _addTokenHeader() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      dio.options.headers["Authorization"] = "Bearer $token";
      logger.i("Token set in headers: $token");
    } else {
      logger.i("No token found in SharedPreferences");
    }
  }

  Future<bool> login(String identifier, String password) async {
    try {
      final response = await dio.post(
        "$baseUrl/login",
        data: {"identifier": identifier, "password": password},
        options: Options(headers: {"Content-Type": "application/json"}),
      );
      if (response.statusCode == 200) {
        final token = response.data["token"];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        dio.options.headers["Authorization"] = "Bearer $token";
        logger.i("Login successful, token saved: $token");
        return true;
      }
      logger.w("Login failed with status code: ${response.statusCode}");
      return false;
    } catch (e) {
      logger.e("Login failed: $e");
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      await init();
      logger.i("Rozpoczynanie logowania przez Google...");
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        logger.i("Logowanie przez Google anulowane przez użytkownika");
        return false;
      }
      logger.i("Użytkownik Google: ${googleUser.email}");
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      if (idToken == null) {
        logger.e("Nie otrzymano tokenu ID od Google");
        return false;
      }

      final response = await dio.post(
        "$baseUrl/google-login",
        data: {"idToken": idToken},
        options: Options(headers: {"Content-Type": "application/json"}),
      );

      if (response.statusCode == 200) {
        final token = response.data["token"];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        dio.options.headers["Authorization"] = "Bearer $token";
        logger.i("Logowanie przez Google zakończone sukcesem, token zapisany: $token");
        return true;
      }
      logger.w("Google login failed with status code: ${response.statusCode}");
      return false;
    } catch (e) {
      logger.e("Logowanie przez Google nie powiodło się: $e");
      return false;
    }
  }

  Future<void> signOutGoogle() async {
    await _googleSignIn.signOut();
    logger.i("Signed out from Google");
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    dio.options.headers["Authorization"] = "";
    isInitialized = false;
    logger.i("Logged out");
  }

  Future<bool> register(String username, String password, String email) async {
    try {
      final response = await dio.post(
        "$baseUrl/register",
        data: {"username": username, "password": password, "email": email},
        options: Options(headers: {"Content-Type": "application/json"}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        logger.i("Registration successful for $username");
        return true;
      }
      logger.w("Registration failed with status code: ${response.statusCode}");
      return false;
    } catch (e) {
      logger.e("Registration failed: $e");
      return false;
    }
  }

  Future<bool> verifyEmailCode(String email, String code) async {
    try {
      final response = await dio.post(
        "$baseUrl/verify-email",
        data: {"email": email, "code": code},
        options: Options(headers: {"Content-Type": "application/json"}),
      );
      if (response.statusCode == 200) {
        logger.i("Email $email verified successfully");
        return true;
      }
      logger.w("Email verification failed with status code: ${response.statusCode}");
      return false;
    } on DioException catch (e) {
      logger.e(
        "Email verification failed: ${e.response?.data['error'] ?? e.message}",
      );
      throw Exception(
        "Verification failed: ${e.response?.data['error'] ?? e.message}",
      );
    }
  }

  Future<List<FileItem>> getFiles({String folderPath = ""}) async {
    await init();
    try {
      final response = await dio.get(
        "$baseUrl/list",
        queryParameters: {"folder": folderPath},
      );
      final filesJson = response.data["files"] as List<dynamic>;
      logger.i("Raw files JSON: $filesJson");
      logger.i("Otrzymano listę plików: ${filesJson.length} elementów");
      return filesJson
          .map((json) => FileItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      logger.e("Błąd podczas pobierania plików: $e");
      return [];
    }
  }

  Future<String> uploadFile(
    File file,
    String folder, {
    Function(int sent, int total)? onSendProgress,
  }) async {
    await init();
    try {
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(
          file.path,
          filename: path.basename(file.path),
        ),
        "folder": folder,
      });
      final response = await dio.post(
        "$baseUrl/upload",
        data: formData,
        onSendProgress: onSendProgress,
      );
      logger.i("Wysłano plik: ${response.data['message']}");
      return response.data["message"];
    } catch (e) {
      logger.e("Błąd podczas wysyłania pliku: $e");
      throw Exception("Błąd wysyłania pliku: $e");
    }
  }

  Future<Uint8List> downloadFileAsBytes(
    String filename, {
    Function(int received, int total)? onProgress,
  }) async {
    await init();
    try {
      logger.i("Pobieranie pliku: $filename z nagłówkami: ${dio.options.headers}");
      final response = await dio.get(
        "$baseUrl/download/$filename",
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: onProgress,
      );

      if (response.data is Uint8List) {
        logger.i("Plik $filename został pomyślnie pobrany jako Uint8List");
        return response.data as Uint8List;
      } else {
        throw Exception(
          "Nie udało się pobrać pliku $filename jako danych binarnych",
        );
      }
    } catch (e) {
      logger.e("Błąd podczas pobierania pliku jako Uint8List: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getFileMetadata(String filename) async {
    await init();
    try {
      logger.i("Pobieranie metadanych dla: $filename z nagłówkami: ${dio.options.headers}");
      final response = await dio.get("$baseUrl/metadata/$filename");
      logger.i("Otrzymano metadane: ${response.data}");
      return response.data as Map<String, dynamic>;
    } catch (e) {
      logger.e("Błąd podczas pobierania metadanych: $e");
      throw Exception("Błąd pobierania metadanych: $e");
    }
  }

  Future<void> downloadFile(
    String filename,
    String savePath, {
    Function(int received, int total)? onProgress,
  }) async {
    await init();
    try {
      final directory = Directory(savePath).parent;
      if (!await directory.exists()) {
        try {
          await directory.create(recursive: true);
        } catch (e) {
          logger.e("Błąd podczas tworzenia folderu: $e");
          throw Exception("Nie można utworzyć folderu docelowego: $e");
        }
      }

      await dio.download(
        "$baseUrl/download/$filename",
        savePath,
        onReceiveProgress: onProgress,
      );

      final file = File(savePath);
      if (await file.exists()) {
        logger.i("Plik $filename został pomyślnie pobrany do $savePath");
      } else {
        throw Exception("Plik $filename nie został zapisany w $savePath");
      }
    } catch (e) {
      logger.e("Błąd podczas pobierania pliku: $e");
      rethrow;
    }
  }

  Future<String> getServerVariable() async {
    await init();
    try {
      final response = await dio.get("$baseUrl/get_variable");
      logger.i("Otrzymano zmienną serwera: ${response.data['server_variable']}");
      return response.data["server_variable"];
    } catch (e) {
      logger.e("Błąd pobierania zmiennej: $e");
      throw Exception("Błąd pobierania zmiennej: $e");
    }
  }

  Future<String> updateServerVariable(String newValue) async {
    await init();
    try {
      final response = await dio.post(
        "$baseUrl/update_variable",
        data: {"new_value": newValue},
      );
      logger.i("Zaktualizowano zmienną serwera: ${response.data['message']}");
      return response.data["message"];
    } catch (e) {
      logger.e("Błąd aktualizacji zmiennej: $e");
      throw Exception("Błąd aktualizacji zmiennej: $e");
    }
  }

  Future<String> getLogs() async {
    await init();
    try {
      final response = await dio.get("$baseUrl/get_logs");
      logger.i("Otrzymano logi serwera");
      return response.data["logs"];
    } catch (e) {
      logger.e("Błąd pobierania logów: $e");
      throw Exception("Błąd pobierania logów: $e");
    }
  }

  Future<String> deleteFile(String filename) async {
    await init();
    try {
      final response = await dio.delete(
        "$baseUrl/delete/$filename",
      );
      logger.i("Usunięto plik: ${response.data['message']}");
      return response.data["message"];
    } catch (e) {
      logger.e("Błąd podczas usuwania pliku: $e");
      throw Exception("Błąd usuwania pliku: $e");
    }
  }
}