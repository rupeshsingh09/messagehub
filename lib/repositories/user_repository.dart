import '../services/api_service.dart';
import '../models/user_model.dart';

class UserRepository {
  Future<Map<String, dynamic>> sendOtp(String phone) {
    return ApiService.sendOtp(phone);
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp, String firstName) {
    return ApiService.verifyOtp(phone, otp, firstName);
  }

  Future<List<ChatUser>> getUsers() async {
    final data = await ApiService.getUsers();
    return data.map((json) => ChatUser.fromJson(json)).toList();
  }

  Future<List<ChatUser>> matchContacts(List<String> phoneNumbers) async {
    final data = await ApiService.matchContacts(phoneNumbers);
    return data.map((json) => ChatUser.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> updateProfilePic(String filePath) {
    return ApiService.updateProfilePic(filePath);
  }

  Future<bool> removeProfilePic() {
    return ApiService.removeProfilePic();
  }

  Future<bool> deleteAccount() {
    return ApiService.deleteAccount();
  }

  Future<Map<String, dynamic>?> getUserDetails(String userId) {
    return ApiService.getUserDetails(userId);
  }

  Future<bool> updateFcmToken(String userId, String token) {
    return ApiService.updateFcmToken(userId, token);
  }

  Future<bool> updateBio(String bio) {
    return ApiService.updateBio(bio);
  }
}
