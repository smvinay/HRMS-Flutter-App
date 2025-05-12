import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const String domainName = 'https://app.attendify.ai/SmartAttendance/public/index.php/';
  static const String loginUrl = domainName + "AuthController/talogin";

  static Future<Map<String, dynamic>> loginUser(String username, String password, String captcha) async {
    try {
      var response = await http.post(
        Uri.parse(loginUrl),
        body: {
          "email": username,
          "password": password,
          "captcha": captcha
        },
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {"status": false, "message": "Error: ${e.toString()}"};
    }
  }
}
