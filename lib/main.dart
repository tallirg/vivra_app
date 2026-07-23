import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'services/tourist_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vivra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFDF8F5), // Fondo crema de la web
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC76A28), // Terracota de la web
          primary: const Color(0xFFC76A28),
          secondary: const Color(0xFFDDA15E),
        ),
        useMaterial3: true,
      ),
      home: const MainNavigationShell(),
    );
  }
}

// -----------------------------------------------------------------
// SHELL CON NAVEGACIÓN INFERIOR (BOTTOM NAVIGATION BAR)
// -----------------------------------------------------------------
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  final storage = const FlutterSecureStorage();
  bool _isLoggedIn = false;
  String? _userToken;
  
  // IP de tu servidor Ubuntu
  final String _baseUrl = 'https://vivra-915z.onrender.com/api';
  final List<String> _favoritosLocales = [];

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    String? token = await storage.read(key: 'auth_token');
    setState(() {
      _userToken = token;
      _isLoggedIn = token != null && token.isNotEmpty;
    });
  }

  void _onLoginSuccess(String token) async {
    await storage.write(key: 'auth_token', value: token);
    setState(() {
      _userToken = token;
      _isLoggedIn = true;
      _currentIndex = 0; // Regresa a la pestaña de Explora al iniciar sesión
    });
  }

  void _onLogout() async {
    await storage.delete(key: 'auth_token');
    setState(() {
      _userToken = null;
      _isLoggedIn = false;
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      // 1. Explora
      ExploreTab(
        baseUrl: _baseUrl,
        favoritosLocales: _favoritosLocales,
        isLoggedIn: _isLoggedIn,
        onFavoriteToggle: (id) {
          setState(() {
            _favoritosLocales.contains(id)
                ? _favoritosLocales.remove(id)
                : _favoritosLocales.add(id);
          });
        },
      ),
      // 2. Favoritos
      FavoritesTab(
        baseUrl: _baseUrl,
        favoritosLocales: _favoritosLocales,
      ),
      // 3. Reservaciones
      ReservationsTab(
        isLoggedIn: _isLoggedIn,
        onGoToLogin: () => setState(() => _currentIndex = 4),
      ),
      // 4. Mensajes
      MessagesTab(
        isLoggedIn: _isLoggedIn,
        onGoToLogin: () => setState(() => _currentIndex = 4),
      ),
      // 5. Perfil / Iniciar Sesión
      _isLoggedIn
          ? ProfileTab(onLogout: _onLogout)
          : LoginTab(baseUrl: _baseUrl, onLoginSuccess: _onLoginSuccess),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          _checkAuthStatus();
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey[600],
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Explora',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite, color: Colors.red),
            label: 'Favoritos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_number_outlined),
            label: 'Reservas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Mensajes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------
// PESTAÑA 1: EXPLORA (PANTALLA PRINCIPAL)
// -----------------------------------------------------------------
class ExploreTab extends StatefulWidget {
  final String baseUrl;
  final List<String> favoritosLocales;
  final Function(String) onFavoriteToggle;
  final bool isLoggedIn;

  const ExploreTab({
    super.key,
    required this.baseUrl,
    required this.favoritosLocales,
    required this.onFavoriteToggle,
    required this.isLoggedIn,
  });

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  final Dio _dio = Dio();
  final _searchController = TextEditingController();

  List<dynamic> _allExperiences = [];
  List<dynamic> _filteredExperiences = [];
  bool _loading = true;
  String _selectedCategory = 'Todos';
  final List<String> _categories = ['Todos', 'Gastronomía', 'Artesanías', 'Aventura'];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // ⏱️ Timeout de 5 segundos para evitar bloqueos
      _dio.options.connectTimeout = const Duration(seconds: 5);
      _dio.options.receiveTimeout = const Duration(seconds: 5);

      final expResponse = await _dio.get('${widget.baseUrl}/experiencias');

      if (expResponse.statusCode == 200) {
        dynamic responseData = expResponse.data;
        List<dynamic> extractedList = [];

        if (responseData is List) {
          extractedList = responseData;
        } else if (responseData is Map && responseData['data'] is List) {
          extractedList = responseData['data'];
        }

        extractedList = extractedList.where((exp) {
          var active = exp['active'] ?? exp['activo'] ?? exp['status'];
          if (active == null) return true;
          if (active is bool) return active;
          if (active is int) return active == 1;
          if (active is String) {
            String a = active.toLowerCase();
            return a == '1' || a == 'active' || a == 'activa';
          }
          return true;
        }).toList();

        if (mounted) {
          setState(() {
            _allExperiences = extractedList;
            _filteredExperiences = extractedList;
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error conectando a la API: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo conectar con el servidor local.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u');
  }

  void _filterExperiences() {
    String query = _normalizeText(_searchController.text);
    String selCatNormalized = _normalizeText(_selectedCategory);

    setState(() {
      _filteredExperiences = _allExperiences.where((exp) {
        final title = _normalizeText(exp['name'] ?? exp['titulo'] ?? '');
        final desc = _normalizeText(exp['description'] ?? exp['descripcion'] ?? '');
        
        var catObj = exp['category'] ?? exp['categoria'];
        String catName = '';
        if (catObj is Map) {
          catName = _normalizeText(catObj['name'] ?? catObj['nombre'] ?? '');
        } else {
          catName = _normalizeText(catObj?.toString() ?? '');
        }

        bool matchesSearch = query.isEmpty || title.contains(query) || desc.contains(query);
        bool matchesCategory = _selectedCategory == 'Todos' ||
            catName.contains(selCatNormalized.substring(0, selCatNormalized.length > 4 ? 4 : selCatNormalized.length));

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // 🔍 Barra de Búsqueda
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

                  // 🏷️ Categorías
                  Container(
                    height: 55,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() => _selectedCategory = cat);
                              _filterExperiences();
                            },
                            selectedColor: Theme.of(context).colorScheme.primary,
                            labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                          ),
                        );
                      },
                    ),
                  ),

                  // 🏞️ Lista de Experiencias
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _filteredExperiences.isEmpty
                          ? const Center(child: Text('No se encontraron experiencias.'))
                          : ListView.builder(
                              itemCount: _filteredExperiences.length,
                              itemBuilder: (context, index) {
                                final exp = _filteredExperiences[index];
                                final id = exp['id']?.toString() ?? index.toString();
                                final isFavorited = widget.favoritosLocales.contains(id);
                                String expTitle = exp['name'] ?? exp['titulo'] ?? 'Experiencia';
                                var price = exp['price'] ?? exp['precio'] ?? 0;
                                String? imageUrl = exp['image'] ?? exp['imagen'];

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(16),
                                            child: imageUrl != null && imageUrl.isNotEmpty
                                                ? Image.network(
                                                    imageUrl,
                                                    height: 200,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => Container(
                                                      height: 200,
                                                      color: Colors.grey[200],
                                                      child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                                    ),
                                                  )
                                                : Container(
                                                    height: 200,
                                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                                    child: Icon(Icons.landscape, size: 60, color: Theme.of(context).colorScheme.primary),
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
                                              onPressed: () => widget.onFavoriteToggle(id),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(expTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                                Text('Desde \$$price MXN', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Theme.of(context).colorScheme.primary,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => ExperienceDetailScreen(experience: exp, isLoggedIn: widget.isLoggedIn),
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
                  ),
                ],
              ),
      ),
    );
  }
}

// -----------------------------------------------------------------
// PESTAÑA 2: FAVORITOS
// -----------------------------------------------------------------
class FavoritesTab extends StatelessWidget {
  final String baseUrl;
  final List<String> favoritosLocales;

  const FavoritesTab({super.key, required this.baseUrl, required this.favoritosLocales});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tus Favoritos'), backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
      body: favoritosLocales.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Aún no has guardado experiencias favoritas.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: favoritosLocales.length,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: Text('Experiencia Favorita #${favoritosLocales[index]}'),
                    subtitle: const Text('Guardado en tu dispositivo'),
                  ),
                );
              },
            ),
    );
  }
}

// -----------------------------------------------------------------
// PESTAÑA 3: RESERVACIONES
// -----------------------------------------------------------------
class ReservationsTab extends StatefulWidget {
  final bool isLoggedIn;
  final VoidCallback onGoToLogin;

  const ReservationsTab({
    super.key,
    required this.isLoggedIn,
    required this.onGoToLogin,
  });

  @override
  State<ReservationsTab> createState() => _ReservationsTabState();
}

class _ReservationsTabState extends State<ReservationsTab> {
  bool _loading = false;
  List<dynamic> _bookings = [];

  // 1. ESTO ES VITAL: Es lo primero que se ejecuta al cargar la pestaña
  @override
  void initState() {
    super.initState();

    // Si el usuario está logueado, ve por los datos inmediatamente
    if (widget.isLoggedIn) {
      _loadBookings();
    }
  }

  @override
  void didUpdateWidget(covariant ReservationsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si antes no estaba logueado y ahora sí, o si está logueado pero aún no tenemos datos
    if (widget.isLoggedIn && (!oldWidget.isLoggedIn || _bookings.isEmpty)) {
      _loadBookings();
    }
  }

  // 2. LA FUNCIÓN QUE CONECTA CON EL SERVICIO
  Future<void> _loadBookings() async {
    print('🚀 _loadBookings() EJECUTÁNDOSE');

    setState(() {
      _loading = true;
    });

    final reservas = await TouristService().getMyBookings();

    print('🚀 Reservas recibidas: ${reservas.length}');
    print(reservas);

    setState(() {
      _bookings = reservas;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tus Reservaciones'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: !widget.isLoggedIn
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.confirmation_number_outlined,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Inicia sesión para consultar tus reservaciones.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: widget.onGoToLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Iniciar Sesión'),
                    ),
                  ],
                ),
              ),
            )
          : _loading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : _bookings.isEmpty
                  ? const Center(
                      child: Text(
                        'No tienes reservaciones activas por el momento.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: _bookings.length,
                      itemBuilder: (context, index) {
                        final reserva = _bookings[index];

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: const Icon(Icons.event_available, color: Colors.green, size: 30),
                            title: Text(
                              reserva['experience']?['name'] ?? reserva['experience']?['titulo'] ?? 'Experiencia',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('Fecha: ${reserva['booking_date'] ?? 'Pendiente'}'),
                                // Protegemos la lectura del horario por si es una reserva vieja de prueba
                                Text('Hora: ${reserva['schedule'] != null ? reserva['schedule']['start_time'].toString().substring(0, 5) : 'N/A'}'),
                                Text('Lugares: ${reserva['quantity'] ?? 1}'),
                                const SizedBox(height: 4),
                                Text(
                                  'Estado: ${reserva['status'] == 'confirmed' ? 'Confirmada' : reserva['status']}',
                                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
    );
  }
}

// -----------------------------------------------------------------
// PESTAÑA 4: MENSAJES
// -----------------------------------------------------------------
class MessagesTab extends StatelessWidget {
  final bool isLoggedIn;
  final VoidCallback onGoToLogin;

  const MessagesTab({super.key, required this.isLoggedIn, required this.onGoToLogin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mensajes con Prestadores'), backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
      body: !isLoggedIn
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('Inicia sesión para conversar con los guías y prestadores.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: onGoToLogin,
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
                      child: const Text('Iniciar Sesión'),
                    )
                  ],
                ),
              ),
            )
          : const Center(child: Text('No tienes conversaciones iniciadas.')),
    );
  }
}

// -----------------------------------------------------------------
// PESTAÑA 5: PERFIL (USUARIO CONECTADO)
// -----------------------------------------------------------------
class ProfileTab extends StatelessWidget {
  final VoidCallback onLogout;

  const ProfileTab({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil'), backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 60)),
            const SizedBox(height: 16),
            const Text('Turista Vivra', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Sesión Activa', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: onLogout,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC76A28), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(50)),
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar Sesión', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------
// PESTAÑA 5 (ALTERNATIVA): FORMULARIO DE INICIO DE SESIÓN
// -----------------------------------------------------------------
class LoginTab extends StatefulWidget {
  final String baseUrl;
  final Function(String) onLoginSuccess;

  const LoginTab({super.key, required this.baseUrl, required this.onLoginSuccess});

  @override
  State<LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<LoginTab> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dio = Dio();
  bool _isLoading = false;
  bool _obscurePassword = true; // 👁️ Nueva variable para controlar el ojito

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Llena todos los campos')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _dio.post(
        '${widget.baseUrl}/login',
        data: {'email': _emailController.text.trim(), 'password': _passwordController.text},
      );

      if (response.statusCode == 200) {
        // Buscamos 'token' o 'access_token'
        String token = response.data['token'] ?? response.data['access_token'] ?? '';
        
        if (token.isNotEmpty) {
          widget.onLoginSuccess(token);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: El servidor no envió el token'), backgroundColor: Colors.red)
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credenciales incorrectas'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar Sesión'), backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.local_activity, size: 70, color: Color(0xFFC76A28)),
            const SizedBox(height: 16),
            const Text('Accede a tu cuenta de Vivra', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController, 
              decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder())
            ),
            const SizedBox(height: 16),
            
            // 👁️ Campo de contraseña actualizado con el ojito
            TextField(
              controller: _passwordController, 
              obscureText: _obscurePassword, 
              decoration: InputDecoration(
                labelText: 'Contraseña', 
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    // Cambiamos el estado al presionar el botón
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              )
            ),
            
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('Ingresar'),
                  ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------
// PANTALLA DE DETALLE (ACTUALIZADA CON CALENDARIO Y HORARIOS)
// -----------------------------------------------------------------
class ExperienceDetailScreen extends StatefulWidget {
  final dynamic experience;
  final bool isLoggedIn;

  const ExperienceDetailScreen({super.key, required this.experience, required this.isLoggedIn});

  @override
  State<ExperienceDetailScreen> createState() => _ExperienceDetailScreenState();
}

class _ExperienceDetailScreenState extends State<ExperienceDetailScreen> {
  DateTime? _selectedDate;
  List<dynamic> _availableSchedules = [];
  int? _selectedScheduleId;
  int _quantity = 1;
  bool _isLoadingSchedules = false;

  // Función para abrir el calendario
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(), // No se puede reservar en el pasado
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedScheduleId = null; // Reseteamos la hora si cambia de día
        _isLoadingSchedules = true;
      });

      // Consultamos a Laravel por los horarios de esta experiencia
      int expId = int.tryParse(widget.experience['id'].toString()) ?? 0;
      final schedules = await TouristService().getSchedules(expId);

      // Filtramos para asegurar que el día de la semana coincide (opcional, si Laravel no lo filtró)
      // day_of_week en tu BD: 1=Lunes, 7=Domingo. En Flutter: 1=Lunes, 7=Domingo.
      final filteredSchedules = schedules.where((s) => s['day_of_week'] == picked.weekday).toList();

      setState(() {
        _availableSchedules = filteredSchedules;
        _isLoadingSchedules = false;
      });
    }
  }

  // Calculadora de precio dinámico (Corregida)
    int _calculateTotalPrice() {
      // Ahora busca tanto 'price' como 'precio'
      String priceStr = widget.experience['price']?.toString() ?? widget.experience['precio']?.toString() ?? '0';
      int basePrice = int.tryParse(priceStr) ?? 0;
      
      int included = int.tryParse(widget.experience['included_persons']?.toString() ?? '1') ?? 1;
      int extraPrice = int.tryParse(widget.experience['extra_person_price']?.toString() ?? '0') ?? 0;
      
      int extraPersons = (_quantity - included > 0) ? (_quantity - included) : 0;
      return basePrice + (extraPersons * extraPrice);
    }

  @override
  Widget build(BuildContext context) {
    String title = widget.experience['name'] ?? widget.experience['titulo'] ?? 'Experiencia';
    String desc = widget.experience['description'] ?? widget.experience['descripcion'] ?? 'Sin descripción';
    int totalPrice = _calculateTotalPrice();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(desc, style: const TextStyle(fontSize: 15)),
            const Divider(height: 40),

            // 1. Selector de Fecha
            const Text('1. Elige una fecha:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month),
              label: Text(_selectedDate == null 
                  ? 'Seleccionar fecha en el calendario' 
                  : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
            ),
            const SizedBox(height: 20),

            // 2. Selector de Horarios (Chips)
            if (_selectedDate != null) ...[
              const Text('2. Horarios disponibles:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _isLoadingSchedules 
                  ? const CircularProgressIndicator()
                  : _availableSchedules.isEmpty
                      ? const Text('Lo sentimos, no hay horarios para este día.', style: TextStyle(color: Colors.red))
                      : Wrap(
                          spacing: 10,
                          children: _availableSchedules.map((schedule) {
                            final isSelected = _selectedScheduleId == schedule['id'];
                            // Cortamos los segundos del horario (ej. 10:00:00 -> 10:00)
                            final timeString = schedule['start_time'].toString().substring(0, 5); 
                            
                            return ChoiceChip(
                              label: Text(timeString),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() => _selectedScheduleId = selected ? schedule['id'] : null);
                              },
                              selectedColor: Theme.of(context).colorScheme.secondary,
                            );
                          }).toList(),
                        ),
              const SizedBox(height: 20),
            ],

            // 3. Contador de Personas
            const Text('3. ¿Cuántos asisten?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  icon: const Icon(Icons.remove_circle_outline, size: 30),
                ),
                Text('$_quantity', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => setState(() => _quantity++),
                  icon: const Icon(Icons.add_circle_outline, size: 30),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Resumen y Botón de compra
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total a pagar:', style: TextStyle(fontSize: 16)),
                  Text('\$$totalPrice MXN', style: const TextStyle(fontSize: 22, color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC76A28),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(55),
              ),
              onPressed: () {
                if (!widget.isLoggedIn) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes iniciar sesión para reservar.')));
                  return;
                }
                if (_selectedDate == null || _selectedScheduleId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor elige una fecha y un horario.'), backgroundColor: Colors.orange));
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentScreen(
                      experience: widget.experience,
                      isLoggedIn: widget.isLoggedIn,
                      bookingDate: '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
                      scheduleId: _selectedScheduleId!,
                      quantity: _quantity,
                      totalPrice: totalPrice,
                    ),
                  ),
                );
              },
              child: const Text('Completar Reserva', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------
// PANTALLA DE PAGO 
// -----------------------------------------------------------------
class PaymentScreen extends StatefulWidget {
  final dynamic experience;
  final bool isLoggedIn;
  final String bookingDate;
  final int scheduleId;
  final int quantity;
  final int totalPrice;

  const PaymentScreen({
    super.key, 
    required this.experience, 
    required this.isLoggedIn,
    required this.bookingDate,
    required this.scheduleId,
    required this.quantity,
    required this.totalPrice,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _paymentMethod = 'tarjeta'; 
  bool _isProcessing = false;

  void _processPayment() async {
    setState(() => _isProcessing = true);

    await Future.delayed(const Duration(seconds: 2));

    final service = TouristService();
    int expId = int.tryParse(widget.experience['id'].toString()) ?? 0;
    
    // Enviamos los datos completos al backend
    bool success = await service.buyExperience(expId, widget.scheduleId, widget.bookingDate, widget.quantity);

    setState(() => _isProcessing = false);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Pago exitoso y reserva confirmada! 🎉'), backgroundColor: Colors.green),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Cruce de horarios o lugares insuficientes.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = widget.experience['name'] ?? widget.experience['titulo'] ?? 'Experiencia';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Completar Pago'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumen de reserva', style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              child: ListTile(
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Fecha: ${widget.bookingDate}\nLugares: ${widget.quantity}'),
                trailing: Text('\$${widget.totalPrice} MXN', style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),

            Text('Método de pago', style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Tarjeta'),
                    value: 'tarjeta',
                    groupValue: _paymentMethod,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: (value) => setState(() => _paymentMethod = value!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Efectivo'),
                    value: 'efectivo',
                    groupValue: _paymentMethod,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: (value) => setState(() => _paymentMethod = value!),
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),

            if (_paymentMethod == 'tarjeta') ...[
              const TextField(
                decoration: InputDecoration(labelText: 'Número de Tarjeta', border: OutlineInputBorder(), prefixIcon: Icon(Icons.credit_card)),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                children: const [
                  Expanded(child: TextField(decoration: InputDecoration(labelText: 'Vencimiento (MM/AA)', border: OutlineInputBorder()))),
                  SizedBox(width: 16),
                  Expanded(child: TextField(decoration: InputDecoration(labelText: 'CVV', border: OutlineInputBorder()), obscureText: true)),
                ],
              ),
              const SizedBox(height: 16),
              const TextField(decoration: InputDecoration(labelText: 'Nombre del Titular', border: OutlineInputBorder())),
            ] else ...[
              Center(
                child: Column(
                  children: [
                    const Text('Presenta este código en cualquier tienda afiliada (OXXO, 7-Eleven) para pagar tu reserva.', textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    const Icon(Icons.qr_code_2, size: 150),
                    const SizedBox(height: 8),
                    const Text('9876 5432 1098 7654', style: TextStyle(fontSize: 18, letterSpacing: 2, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
            
            _isProcessing
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(55),
                    ),
                    onPressed: _processPayment,
                    child: Text(_paymentMethod == 'tarjeta' ? 'Pagar \$${widget.totalPrice} MXN' : 'Confirmar y Generar Orden', style: const TextStyle(fontSize: 18)),
                  ),
          ],
        ),
      ),
    );
  }
}