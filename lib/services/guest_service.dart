import 'api_service.dart';

class GuestService {
  final ApiService _api = ApiService();

  // 1. Ver Experiencias (Público)
  Future<List<dynamic>> getExperiences() async {
    final response = await _api.client.get('/experiences');
    return response.data; // Mapea directo al ExperienceController@index
  }

  // 2. Ver Reseñas de una experiencia (Público)
  Future<List<dynamic>> getReviews(int experienceId) async {
    final response = await _api.client.get('/experiences/$experienceId/reviews');
    return response.data; // Mapea a ReviewController@index
  }

  // 3. Crear Usuario / Registro de cuenta tipo Turista
  Future<bool> registerTourist(String name, String email, String password) async {
    try {
      final response = await _api.client.post('/register', data: {
        'name': name,
        'email': email,
        'password': password,
        'role': 'turista', // Forzamos el rol desde el flujo móvil
      });
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}