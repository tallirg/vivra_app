import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vivra App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFDF8F5), // Fondo crema de la web
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC76A28), // Terracota de la web
          primary: const Color(0xFFC76A28),
          secondary: const Color(0xFFDDA15E), // Arena suave de la web
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

// -----------------------------------------------------------------
// PANTALLA DE INICIAR SESIÓN
// -----------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dio = Dio();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;

  final String _baseUrl = 'http://192.168.0.76:8000/api';

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Por favor, llena todos los campos', Colors.amber);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _dio.post(
        '$_baseUrl/login',
        data: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200) {
        String token = response.data['token'];
        await _storage.write(key: 'auth_token', value: token);
        
        if (mounted) {
          _showSnackBar('¡Bienvenido a Vivra!', Colors.green);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen(isGuest: false, baseUrl: _baseUrl)),
          );
        }
      }
    } on DioException catch (e) {
      String errorMessage = 'Error al conectar con el servidor';
      if (e.response != null) {
        errorMessage = e.response?.data['message'] ?? 'Credenciales incorrectas';
      }
      _showSnackBar(errorMessage, Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 100),
              Icon(Icons.local_activity, size: 80, color: const Color(0xFFC76A28)),
              const SizedBox(height: 16),
              const Text(
                'Vivra',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFC76A28)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              const Text(
                'Ingresa tus credenciales',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Correo Electrónico',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Ingresar', style: TextStyle(fontSize: 16)),
                    ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RegisterScreen(baseUrl: _baseUrl)),
                  );
                },
                child: const Text('¿No tienes cuenta? Regístrate aquí', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => HomeScreen(isGuest: true, baseUrl: _baseUrl)),
                  );
                },
                child: const Text('Entrar como Invitado', style: TextStyle(fontSize: 15, color: Colors.blueGrey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------
// PANTALLA DE REGISTRO
// -----------------------------------------------------------------
class RegisterScreen extends StatefulWidget {
  final String baseUrl;
  const RegisterScreen({super.key, required this.baseUrl});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dio = Dio();
  bool _isLoading = false;

  Future<void> _register() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Por favor, completa todos los campos', Colors.amber);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _dio.post(
        '${widget.baseUrl}/registro',
        data: {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'role': 'turista', 
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          _showSnackBar('Cuenta creada con éxito. ¡Ya puedes iniciar sesión!', Colors.green);
          Navigator.pop(context); 
        }
      }
    } on DioException catch (e) {
      String errorMessage = 'Error al registrar usuario';
      if (e.response != null) {
        errorMessage = e.response?.data['message'] ?? 'Los datos ingresados no son válidos';
      }
      _showSnackBar(errorMessage, Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Cuenta'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Regístrate como Turista',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Explora y reserva las mejores experiencias de Oaxaca.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre Completo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Correo Electrónico',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 28),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Registrarse', style: TextStyle(fontSize: 16)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------
// PANTALLA PRINCIPAL CON BÚSQUEDA Y CALIFICACIONES CALCULADAS
// -----------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  final bool isGuest;
  final String baseUrl;
  const HomeScreen({super.key, required this.isGuest, required this.baseUrl});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Dio _dio = Dio();
  final _searchController = TextEditingController();

  List<dynamic> _allExperiences = [];
  List<dynamic> _filteredExperiences = [];
  Map<String, Map<String, dynamic>> _ratingsMap = {}; // Guardará { experience_id: { 'promedio': 4.5, 'total': 10 } }
  
  bool _loading = true;
  String _selectedCategory = 'Todos';
  final List<String> _favoritosLocales = [];
  final List<String> _categories = ['Todos', 'Gastronomía', 'Artesanías', 'Aventura'];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // Carga paralela de experiencias y reseñas desde tu servidor Ubuntu
  Future<void> _fetchData() async {
    try {
      // 1. Obtener Experiencias
      final expResponse = await _dio.get('${widget.baseUrl}/experiencias');
      
      // 2. Obtener todas las Reseñas para calcular los promedios
      List<dynamic> allReviews = [];
      try {
        final reviewResponse = await _dio.get('${widget.baseUrl}/reseñas');
        if (reviewResponse.statusCode == 200) {
          allReviews = reviewResponse.data;
        }
      } catch (e) {
        print('Nota: El endpoint /reseñas falló o no tiene datos aún.');
      }

      // 3. Procesar y agrupar calificaciones por ID de experiencia
      Map<String, List<double>> rawRatings = {};
      for (var review in allReviews) {
        String? expId = (review['experience_id'] ?? review['experiencia_id'])?.toString();
        var puntuacionRaw = review['puntuacion'] ?? review['rating'];
        if (expId != null && puntuacionRaw != null) {
          double score = double.tryParse(puntuacionRaw.toString()) ?? 0.0;
          rawRatings.putIfAbsent(expId, () => []).add(score);
        }
      }

      // 4. Calcular los promedios reales
      Map<String, Map<String, dynamic>> calculatedRatings = {};
      rawRatings.forEach((expId, scores) {
        double sum = scores.reduce((a, b) => a + b);
        double avg = sum / scores.length;
        calculatedRatings[expId] = {
          'promedio': double.parse(avg.toStringAsFixed(2)),
          'total': scores.length
        };
      });

      if (expResponse.statusCode == 200) {
        setState(() {
          _allExperiences = expResponse.data;
          _filteredExperiences = expResponse.data;
          _ratingsMap = calculatedRatings;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  // Lógica de filtrado combinado (Búsqueda por texto + Categorías)
  void _filterExperiences() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredExperiences = _allExperiences.where((exp) {
        final title = exp['titulo']?.toString().toLowerCase() ?? '';
        final desc = exp['descripcion']?.toString().toLowerCase() ?? '';
        final cat = exp['categoria']?.toString().toLowerCase() ?? '';

        bool matchesSearch = title.contains(query) || desc.contains(query);
        bool matchesCategory = _selectedCategory == 'Todos' || cat.contains(_selectedCategory.toLowerCase().substring(0, 5));

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isGuest ? 'Vivra - Invitado' : 'Vivra - Turista'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              const FlutterSecureStorage().delete(key: 'auth_token');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 🔍 1. BARRA DE BÚSQUEDA REAL 
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => _filterExperiences(),
                      decoration: const InputDecoration(
                        hintText: 'Empieza la búsqueda...',
                        prefixIcon: Icon(Icons.search, color: Colors.black87),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),

                // 🏷️ 2. Filtros de categorías
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = cat;
                            });
                            _filterExperiences();
                          },
                          selectedColor: Theme.of(context).colorScheme.primary,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                        ),
                      );
                    },
                  ),
                ),

                // 🏞️ 3. Feed de Tarjetas Grandes estilo Airbnb
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Popular entre los viajeros de tu zona',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _filteredExperiences.isEmpty
                              ? const Center(child: Text('No se encontraron experiencias.'))
                              : ListView.builder(
                                  itemCount: _filteredExperiences.length,
                                  itemBuilder: (context, index) {
                                    final exp = _filteredExperiences[index];
                                    final id = exp['id']?.toString() ?? '';
                                    final isFavorited = _favoritosLocales.contains(id);

                                    // Obtener calificación calculada
                                    final ratingData = _ratingsMap[id];
                                    final String ratingText = ratingData != null 
                                        ? '★ ${ratingData['promedio']} (${ratingData['total']} reseñas)'
                                        : 'Sin calificación';

                                    String? imageUrl;
                                    if (exp['imagenes'] != null && (exp['imagenes'] as List).isNotEmpty) {
                                      imageUrl = exp['imagenes'][0]['url'];
                                    }

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 24),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(16),
                                                child: imageUrl != null
                                                    ? Image.network(
                                                        imageUrl,
                                                        height: 220,
                                                        width: double.infinity,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) =>
                                                            Container(
                                                              height: 220,
                                                              color: Colors.grey[200],
                                                              child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                                            ),
                                                      )
                                                    : Container(
                                                        height: 220,
                                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                                        child: Icon(Icons.landscape, size: 60, color: Theme.of(context).colorScheme.primary),
                                                      ),
                                              ),
                                              Positioned(
                                                top: 12,
                                                left: 12,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                                  child: const Text('Populares', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                ),
                                              ),
                                              Positioned(
                                                top: 8,
                                                right: 8,
                                                child: IconButton(
                                                  icon: Icon(
                                                    isFavorited ? Icons.favorite : Icons.favorite_border,
                                                    color: isFavorited ? Colors.red : Colors.white,
                                                    size: 28,
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      isFavorited ? _favoritosLocales.remove(id) : _favoritosLocales.add(id);
                                                    });
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      exp['titulo'] ?? 'Tour',
                                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    // ⭐ Mostrar estrellas calculadas dinámicamente
                                                    Text(
                                                      ratingText,
                                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Desde \$${exp['precio'] ?? 0} MXN',
                                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Ambos perfiles ven el botón "Ver" para ir a los detalles completos
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => ExperienceDetailScreen(
                                                        experience: exp,
                                                        ratingText: ratingText,
                                                        isGuest: widget.isGuest,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: const Text('Ver'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// -----------------------------------------------------------------
// NUEVA PANTALLA DE DETALLE COMPLETO (ESTILO AIRBNB DETALLES)
// -----------------------------------------------------------------
class ExperienceDetailScreen extends StatelessWidget {
  final dynamic experience;
  final String ratingText;
  final bool isGuest;

  const ExperienceDetailScreen({
    super.key,
    required this.experience,
    required this.ratingText,
    required this.isGuest,
  });

  @override
  Widget build(BuildContext context) {
    // Agrupar lista completa de imágenes si las hay
    List<dynamic> imagenes = experience['imagenes'] ?? [];
    String? mainImageUrl = imagenes.isNotEmpty ? imagenes[0]['url'] : null;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🖼️ Header superior con la Imagen Grande y botones flotantes
                  Stack(
                    children: [
                      mainImageUrl != null
                          ? Image.network(
                              mainImageUrl,
                              height: 320,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              height: 320,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                              child: Icon(Icons.landscape, size: 80, color: Theme.of(context).colorScheme.primary),
                            ),
                      // Flecha de regreso superior
                      Positioned(
                        top: 40,
                        left: 16,
                        child: CircleAvatar(
                          backgroundColor: Colors.white.withOpacity(0.9),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.black87),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Contenido de la información técnica del tour
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título de la experiencia
                        Text(
                          experience['titulo'] ?? 'Tour Auténtico',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        
                        // Calificación e información de zona
                        Row(
                          children: [
                            const Icon(Icons.star, size: 18, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              ratingText,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '•  ${experience['categoria'] ?? 'Oaxaca'}',
                              style: const TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Divider(color: Colors.black12),
                        ),

                        // Descripción extendida del tour
                        const Text(
                          'Acerca de esta experiencia',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          experience['descripcion'] ?? 'No hay una descripción detallada disponible en este momento.',
                          style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        
                        // Ubicación si existe
                        if (experience['ubicacion'] != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  experience['ubicacion'],
                                  style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 💳 BARRA FLOTANTE INFERIOR DE COMPRA ESTILO AIRBNB
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: Colors.black12, width: 0.5)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -4)),
              ],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Columna de precios en Pesos Mexicanos
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\$${experience['precio'] ?? 0} MXN',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const Text(
                        'por participante',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                  
                  // Botón Dinámico de Acción final
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 204, 123, 11), // Rojo clásico Airbnb para destacar
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (isGuest) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Debes iniciar sesión con tu cuenta de Turista para comprar.'),
                            backgroundColor: Colors.amber,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('¡Reservando tu lugar para: ${experience['titulo']}!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    child: Text(
                      isGuest ? 'Iniciar Sesión' : 'Comprar',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}