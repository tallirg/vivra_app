import 'api_service.dart';

class TouristService {
  final ApiService _api = ApiService();

  // 1. Crear Reseña
  Future<bool> createReview(int experienceId, int rating, String comment) async {
    try {
      final response = await _api.client.post('/reviews', data: {
        'experience_id': experienceId,
        'rating': rating,
        'comment': comment,
      });
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // 2. Editar sus Reseñas
  Future<bool> updateReview(int reviewId, int rating, String comment) async {
    try {
      final response = await _api.client.put('/reviews/$reviewId', data: {
        'rating': rating,
        'comment': comment,
      });
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 3. Borrar sus Reseñas
  Future<bool> deleteReview(int reviewId) async {
    try {
      final response = await _api.client.delete('/reviews/$reviewId');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 4. Comprar/Reservar Experiencia
  Future<bool> buyExperience(int experienceId, String date, int slots) async {
    try {
      final response = await _api.client.post('/bookings', data: {
        'experience_id': experienceId,
        'booking_date': date,
        'slots': slots,
      });
      return response.statusCode == 201; // Mapea a BookingController@store
    } catch (e) {
      return false;
    }
  }
} 