  import 'api_service.dart';
  import 'package:dio/dio.dart';

  class TouristService {
    final ApiService _api = ApiService();

    // 1. Crear Reseña (Actualizado a la ruta correcta)
    Future<bool> createReview(int experienceId, int rating, String comment) async {
      try {
        final response = await _api.client.post('experiencias/$experienceId/resenas', data: {
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
        final response = await _api.client.put('resenas/$reviewId', data: {
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
        final response = await _api.client.delete('resenas/$reviewId');
        return response.statusCode == 200;
      } catch (e) {
        return false;
      }
    }

    // 4. Comprar/Reservar Experiencia (Actualizado con horarios)
      Future<bool> buyExperience(int experienceId, int scheduleId, String date, int quantity) async {
        try {
          // Mantenemos tu ruta 'carrito-comprar' pero actualizamos los datos que enviamos
          final response = await _api.client.post('carrito-comprar', data: {
            'experience_id': experienceId,
            'schedule_id': scheduleId,
            'booking_date': date,
            'quantity': quantity,
          });
          return response.statusCode == 201;
        } catch (e) {
          if (e is DioException) {
            print('🔥 CÓDIGO: ${e.response?.statusCode}');
            print('🔥 DETALLE DEL ERROR LARAVEL: ${e.response?.data}');
          } else {
            print('🔥 OTRO ERROR: $e');
          }
          return false;
        }
      }

    // 5. OBTENER MIS RESERVAS 
  Future<List<dynamic>> getMyBookings() async {
      try {
        print('🔥 1. SOLICITANDO RESERVAS AL SERVIDOR...');
        final response = await _api.client.get('mis-reservas');
        
        print('🔥 2. RESPUESTA CRUDA DE LARAVEL: ${response.data}');
        
        List<dynamic> reservas = [];
        
        // Intentamos desempacar si viene en caja de 'data'
        if (response.data is Map && response.data.containsKey('data')) {
          reservas = response.data['data'];
          print('🔥 3. DESEMPACADO COMO MAPA. ENCONTRÉ ${reservas.length} RESERVAS.');
        } 
        // Por si Laravel decidió mandarlo suelto como lista
        else if (response.data is List) {
          reservas = response.data;
          print('🔥 3. DESEMPACADO COMO LISTA DIRECTA. ENCONTRÉ ${reservas.length} RESERVAS.');
        } 
        else {
          print('🔥 3. ERROR BIZARRO: No es ni Mapa ni Lista. Es un: ${response.data.runtimeType}');
        }

        return reservas;
      } catch (e) {
        if (e is DioException) {
          print('🔥 ERROR DE RED AL CARGAR: ${e.response?.statusCode}');
          print('🔥 DETALLE DEL ERROR: ${e.response?.data}');
        } else {
          print('🔥 ERROR INTERNO DE FLUTTER: $e');
        }
        return [];
      }
    }
    // Función para obtener los horarios de una experiencia
    Future<List<dynamic>> getSchedules(int experienceId) async {
      try {
        final response = await _api.client.get('experiencias/$experienceId/horarios');
        
        if (response.data is Map && response.data.containsKey('data')) {
          return response.data['data'];
        }
        return response.data;
      } catch (e) {
        print('🔥 ERROR AL CARGAR HORARIOS: $e');
        return []; // Si no hay horarios o hay error, regresamos lista vacía
      }
    }
  }