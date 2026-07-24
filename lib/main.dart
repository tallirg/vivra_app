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
  String _userRole = 'tourist'; // Variable para controlar la vista actual

  // 🌟 Variables globales que necesitan las pestañas (URL de producción)
  final String _baseUrl = 'https://vivra-915z.onrender.com/api';
  final List<String> _favoritosLocales = [];

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    String? token = await storage.read(key: 'auth_token');
    String? role = await storage.read(key: 'user_role');
    
    setState(() {
      _userToken = token;
      _userRole = role ?? 'tourist'; // Si no hay sesión, asumimos turista por defecto
      _isLoggedIn = token != null && token.isNotEmpty;
    });
  }

  // Actualizamos para recibir y guardar el rol
  void _onLoginSuccess(String token, String role, String userId) async {
    await storage.write(key: 'auth_token', value: token);
    await storage.write(key: 'user_role', value: role);
    await storage.write(key: 'user_id', value: userId); // <-- Guardamos el ID del usuario
    setState(() {
      _userToken = token;
      _userRole = role;
      _isLoggedIn = true;
      _currentIndex = 0;
    });
  }

  void _onLogout() async {
    await storage.delete(key: 'auth_token');
    await storage.delete(key: 'user_role');
    setState(() {
      _userToken = null;
      _userRole = 'tourist'; // Volvemos a vista de turista al salir
      _isLoggedIn = false;
      _currentIndex = 0;
    });
  }

  // Función para manejar los favoritos locales
  void _toggleFavorite(String id) {
    setState(() {
      if (_favoritosLocales.contains(id)) {
        _favoritosLocales.remove(id);
      } else {
        _favoritosLocales.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 DEFINIMOS LAS PANTALLAS DINÁMICAMENTE (CON TODOS SUS PARÁMETROS EXACTOS)
    final List<Widget> pages = _userRole == 'provider'
        ? [
            const ProviderDashboardTab(),       
            const ProviderExperiencesTab(),     
            const ProviderReservationsTab(),    
            MessagesTab(isLoggedIn: _isLoggedIn, onGoToLogin: () => setState(() => _currentIndex = 4)), 
            ProfileTab(onLogout: _onLogout),    
          ]
        : [
            ExploreTab(
              baseUrl: _baseUrl,
              favoritosLocales: _favoritosLocales,
              onFavoriteToggle: _toggleFavorite,
              isLoggedIn: _isLoggedIn,
            ), 
            FavoritesTab(
              baseUrl: _baseUrl,
              favoritosLocales: _favoritosLocales,
            ),
            ReservationsTab(
              isLoggedIn: _isLoggedIn,
              onGoToLogin: () => setState(() => _currentIndex = 4),
              baseUrl: _baseUrl,
            ),
            MessagesTab(
              isLoggedIn: _isLoggedIn, 
              onGoToLogin: () => setState(() => _currentIndex = 4)
            ),
            _isLoggedIn 
              ? ProfileTab(onLogout: _onLogout) 
              : LoginTab(baseUrl: _baseUrl, onLoginSuccess: _onLoginSuccess),
          ];

    // 🌟 DEFINIMOS LOS BOTONES DINÁMICAMENTE
    final List<BottomNavigationBarItem> navItems = _userRole == 'provider'
        ? const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Panel'),
            BottomNavigationBarItem(icon: Icon(Icons.local_activity), label: 'Mis Exp.'),
            BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Reservas'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Mensajes'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
          ]
        : const [
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Explora'),
            BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: 'Favoritos'),
            BottomNavigationBarItem(icon: Icon(Icons.confirmation_number_outlined), label: 'Reservas'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Mensajes'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
          ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: navItems,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey[600],
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
            content: Text('No se pudo conectar con el servidor.'),
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
// PESTAÑA 3: RESERVACIONES (CONECTADA A LA API)
// -----------------------------------------------------------------
class ReservationsTab extends StatefulWidget {
  final bool isLoggedIn;
  final VoidCallback onGoToLogin;
  final String baseUrl;

  const ReservationsTab({
    super.key,
    required this.isLoggedIn,
    required this.onGoToLogin,
    required this.baseUrl,
  });

  @override
  State<ReservationsTab> createState() => _ReservationsTabState();
}

class _ReservationsTabState extends State<ReservationsTab> {
  final Dio _dio = Dio();
  final _storage = const FlutterSecureStorage();
  List<dynamic> _reservas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.isLoggedIn) {
      _fetchReservas();
    }
  }

  @override
  void didUpdateWidget(covariant ReservationsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoggedIn && (!oldWidget.isLoggedIn || _reservas.isEmpty)) {
      setState(() => _loading = true);
      _fetchReservas();
    }
  }

  Future<void> _fetchReservas() async {
    try {
      final list = await TouristService().getMyBookings();
      if (mounted) {
        setState(() {
          _reservas = list;
        });
      }
    } catch (e) {
      debugPrint('Error obteniendo reservas: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Tus Reservaciones'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.confirmation_number_outlined, size: 80, color: Colors.grey),
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
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Iniciar Sesión'),
                )
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tus Reservaciones'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reservas.isEmpty
              ? const Center(child: Text('No tienes reservaciones activas.'))
              : RefreshIndicator(
                  onRefresh: _fetchReservas,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reservas.length,
                    itemBuilder: (context, index) {
                      final reserva = _reservas[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReservationDetailScreen(reserva: reserva),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// -----------------------------------------------------------------
// PESTAÑA 4: MENSAJES (ESTRUCTURA DE DOS PESTAÑAS: IA + PRESTADORES)
// -----------------------------------------------------------------
class MessagesTab extends StatelessWidget {
  final bool isLoggedIn;
  final VoidCallback onGoToLogin;

  const MessagesTab({
    super.key,
    required this.isLoggedIn,
    required this.onGoToLogin,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Si no ha iniciado sesión, se le pide ingresar
    if (!isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mensajes'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Inicia sesión para conversar con el asistente virtual o con los prestadores.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: onGoToLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Iniciar Sesión'),
                )
              ],
            ),
          ),
        ),
      );
    }

    // 2. Si TIENE sesión, le mostramos la barra superior con 2 Pestañas
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mensajes'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.smart_toy_outlined), text: 'Asistente IA'),
              Tab(icon: Icon(Icons.people_outline), text: 'Prestadores'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            // Pestaña 1: Conversación con Groq (Chatbot)
            AiChatSubTab(),

            // Pestaña 2: Chats directos con prestadores
            Center(
              child: Text(
                'Tus conversaciones con prestadores aparecerán aquí',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------
// SUB-PESTAÑA 1: CHATBOT INTERACTIVO DE IA (CONECTADO A GROQ)
// -----------------------------------------------------------------
class AiChatSubTab extends StatefulWidget {
  const AiChatSubTab({super.key});

  @override
  State<AiChatSubTab> createState() => _AiChatSubTabState();
}

class _AiChatSubTabState extends State<AiChatSubTab> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final String _baseUrl = 'https://vivra-915z.onrender.com/api';

  final List<Map<String, String>> _messages = [
    {
      'sender': 'bot',
      'text': '¡Hola! 👋 Soy tu asistente virtual en Vivra. ¿Tienes alguna duda sobre nuestras experiencias o qué hacer en Oaxaca?'
    }
  ];

  bool _isTyping = false;

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isTyping) return;

    _messageController.clear();

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      String? token = await _storage.read(key: 'auth_token');

      final response = await _dio.post(
        '$_baseUrl/chat',
        data: {'message': text},
        options: Options(
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        String reply = response.data['reply'] ?? 'No recibí respuesta.';
        setState(() {
          _messages.add({'sender': 'bot', 'text': reply});
        });
      } else {
        _showErrorBotMessage('Ocurrió un inconveniente al consultar con el asistente.');
      }
    } catch (e) {
      debugPrint('Error en el Chatbot: $e');
      _showErrorBotMessage('Lo siento, tuve problemas de conexión. Intenta de nuevo.');
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
        _scrollToBottom();
      }
    }
  }

  void _showErrorBotMessage(String error) {
    if (mounted) {
      setState(() {
        _messages.add({'sender': 'bot', 'text': error});
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        // Lista de mensajes (Burbujas)
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              final isUser = message['sender'] == 'user';

              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? primaryColor : Colors.grey[200],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 0),
                      bottomRight: Radius.circular(isUser ? 0 : 16),
                    ),
                  ),
                  child: Text(
                    message['text'] ?? '',
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Indicador de "Escribiendo..."
        if (_isTyping)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                ),
                const SizedBox(width: 10),
                Text(
                  'El asistente está escribiendo...',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),

        // Campo para escribir mensaje y botón enviar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Pregunta sobre experiencias en Oaxaca...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: primaryColor,
                  radius: 22,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
            const Text('Usuario Vivra', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
  final Function(String, String, String) onLoginSuccess;

  const LoginTab({super.key, required this.baseUrl, required this.onLoginSuccess});

  @override
  State<LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<LoginTab> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dio = Dio();
  bool _isLoading = false;
  bool _obscurePassword = true;

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
        String token = response.data['token'] ?? response.data['access_token'] ?? '';
        String role = response.data['role'] ?? response.data['rol'] ?? 'tourist';
        
        // Extraemos el ID del usuario que devuelve Laravel
        var user = response.data['user'] ?? response.data['usuario'];
        String userId = user != null ? user['id'].toString() : (response.data['user_id']?.toString() ?? '');
        
        if (token.isNotEmpty) {
          widget.onLoginSuccess(token, role, userId); 
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
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController, 
              obscureText: _obscurePassword, 
              decoration: InputDecoration(
                labelText: 'Contraseña', 
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(), 
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedScheduleId = null; 
        _quantity = 1; 
        _isLoadingSchedules = true;
      });

      int expId = int.tryParse(widget.experience['id'].toString()) ?? 0;
      final schedules = await TouristService().getSchedules(expId);

      final filteredSchedules = schedules.where((s) => s['day_of_week'] == picked.weekday).toList();

      setState(() {
        _availableSchedules = filteredSchedules;
        _isLoadingSchedules = false;
      });
    }
  }

  int _calculateTotalPrice() {
    String priceStr = widget.experience['price']?.toString() ?? widget.experience['precio']?.toString() ?? '0';
    String extraPriceStr = widget.experience['extra_person_price']?.toString() ?? '0';
    String includedStr = widget.experience['included_persons']?.toString() ?? '1';

    int basePrice = double.tryParse(priceStr)?.toInt() ?? 0;
    int extraPrice = double.tryParse(extraPriceStr)?.toInt() ?? 0;
    int included = double.tryParse(includedStr)?.toInt() ?? 1;
    
    int extraPersons = (_quantity - included > 0) ? (_quantity - included) : 0;
    return basePrice + (extraPersons * extraPrice);
  }

  @override
  Widget build(BuildContext context) {
    String title = widget.experience['name'] ?? widget.experience['titulo'] ?? 'Experiencia';
    String desc = widget.experience['description'] ?? widget.experience['descripcion'] ?? 'Sin descripción';
    int totalPrice = _calculateTotalPrice();

    int maxStock = 99; 
    if (_selectedScheduleId != null) {
      final schedule = _availableSchedules.firstWhere(
        (s) => s['id'] == _selectedScheduleId, 
        orElse: () => null
      );
      if (schedule != null) {
        maxStock = int.tryParse(schedule['stock'].toString()) ?? 99;
      }
    }

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
                            final timeString = schedule['start_time'].toString().substring(0, 5); 
                            
                            return ChoiceChip(
                              label: Text(timeString),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedScheduleId = selected ? schedule['id'] : null;
                                  
                                  if (selected) {
                                    int scheduleStock = int.tryParse(schedule['stock'].toString()) ?? 99;
                                    if (_quantity > scheduleStock) {
                                      _quantity = scheduleStock;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Ajustamos tus lugares a $scheduleStock (Cupo máximo del horario)'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  }
                                });
                              },
                              selectedColor: Theme.of(context).colorScheme.secondary,
                            );
                          }).toList(),
                        ),
              const SizedBox(height: 20),
            ],

            const Text('3. ¿Cuántos asisten?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  icon: Icon(Icons.remove_circle_outline, size: 30, color: _quantity > 1 ? Colors.black : Colors.grey),
                ),
                Text('$_quantity', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: _quantity < maxStock ? () => setState(() => _quantity++) : null,
                  icon: Icon(
                    Icons.add_circle_outline, 
                    size: 30, 
                    color: _quantity < maxStock ? Colors.black : Colors.grey
                  ),
                ),
                if (_selectedScheduleId != null && _quantity == maxStock)
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Text('(Cupo lleno)', style: TextStyle(color: Colors.red, fontSize: 12)),
                  )
              ],
            ),
            const SizedBox(height: 32),

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
                
                if (_quantity > maxStock) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Solo quedan $maxStock lugares disponibles.'), backgroundColor: Colors.red)
                  );
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
  final _formKey = GlobalKey<FormState>();

  void _processPayment() async {
    if (_paymentMethod == 'tarjeta') {
      if (!_formKey.currentState!.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor revisa los datos de tu tarjeta.'), backgroundColor: Colors.orange),
        );
        return;
      }
    }

    setState(() => _isProcessing = true);

    await Future.delayed(const Duration(seconds: 2));

    final service = TouristService();
    int expId = int.tryParse(widget.experience['id'].toString()) ?? 0;
    
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

  Widget _buildRealisticBarcode() {
    final widths = [3.0, 1.0, 4.0, 2.0, 1.0, 5.0, 2.0, 1.0, 3.0, 4.0, 1.0, 2.0];
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ]
      ),
      child: Column(
        children: [
          const Text('REFERENCIA DE PAGO', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(28, (index) {
              return Container(
                width: widths[index % widths.length],
                height: 80,
                color: Colors.black,
                margin: const EdgeInsets.only(right: 2.5),
              );
            }),
          ),
          const SizedBox(height: 16),
          const Text(
            '9876  5432  1098  7654', 
            style: TextStyle(fontSize: 18, letterSpacing: 2, fontFamily: 'monospace', fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Válido por 24 horas', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
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

            if (_paymentMethod == 'tarjeta') 
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Número de Tarjeta', border: OutlineInputBorder(), prefixIcon: Icon(Icons.credit_card)),
                      keyboardType: TextInputType.number,
                      maxLength: 16, 
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'El número es requerido';
                        if (value.length < 16) return 'Debe tener 16 dígitos';
                        if (int.tryParse(value) == null) return 'Solo se aceptan números';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(labelText: 'Vencimiento (MM/AA)', border: OutlineInputBorder()),
                            maxLength: 5,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Requerido';
                              if (!RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$').hasMatch(value)) {
                                return 'Formato incorrecto';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(labelText: 'CVV', border: OutlineInputBorder()),
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Requerido';
                              if (value.length < 3) return 'Mín. 3 dígitos';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Nombre del Titular', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'El nombre es requerido';
                        if (value.trim().length < 4) return 'Ingresa tu nombre completo';
                        return null;
                      },
                    ),
                  ],
                ),
              ) 
            else 
              Center(
                child: Column(
                  children: [
                    const Text('Presenta este ticket en las cajas de cualquier tienda afiliada (OXXO, 7-Eleven, Farmacias del Ahorro) para pagar tu reserva.', textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    _buildRealisticBarcode(),
                  ],
                ),
              ),

            const SizedBox(height: 32),
            
            _isProcessing
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _processPayment,
                    child: Text(_paymentMethod == 'tarjeta' ? 'Pagar \$${widget.totalPrice} MXN' : 'Confirmar y Generar Orden', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------
// PANTALLA DE DETALLE DE LA RESERVA
// -----------------------------------------------------------------
class ReservationDetailScreen extends StatelessWidget {
  final dynamic reserva;

  const ReservationDetailScreen({super.key, required this.reserva});

  @override
  Widget build(BuildContext context) {
    final experience = reserva['experience'] ?? {};
    final schedule = reserva['schedule'] ?? {};
    
    String title = experience['name'] ?? experience['titulo'] ?? 'Experiencia';
    String location = experience['location'] ?? 'Ubicación no especificada';
    String date = reserva['booking_date'] ?? 'Pendiente';
    String time = schedule['start_time'] != null ? schedule['start_time'].toString().substring(0, 5) : 'Por definir';
    String quantity = reserva['quantity']?.toString() ?? '1';
    String totalPrice = reserva['total_price']?.toString() ?? '0';
    String status = reserva['status'] == 'confirmed' ? 'Confirmada' : (reserva['status'] ?? 'Pendiente');
    String imageUrl = experience['image'] ?? experience['imagen'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Reserva'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholderImage(context),
                ),
              )
            else
              _buildPlaceholderImage(context),
            
            const SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: status == 'Confirmada' ? Colors.green[100] : Colors.orange[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: status == 'Confirmada' ? Colors.green[800] : Colors.orange[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text('Información del evento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow(Icons.calendar_month, 'Fecha', date),
                    const Divider(),
                    _buildDetailRow(Icons.access_time, 'Hora de inicio', time),
                    const Divider(),
                    _buildDetailRow(Icons.group, 'Personas', quantity),
                    const Divider(),
                    _buildDetailRow(Icons.location_on, 'Ubicación', location),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('Resumen de Pago', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Pagado:', style: TextStyle(fontSize: 16)),
                  Text(
                    '\$$totalPrice MXN',
                    style: const TextStyle(fontSize: 22, color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Abriendo chat con el prestador... (En desarrollo)')),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Contactar al Prestador'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(Icons.landscape, size: 80, color: Theme.of(context).colorScheme.primary),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[700], size: 24),
          const SizedBox(width: 12),
          Text('$label:', style: const TextStyle(fontSize: 16, color: Colors.black54)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// MÓDULO DEL PRESTADOR DE SERVICIOS (PLANTILLAS)
// =================================================================

class ProviderDashboardTab extends StatelessWidget {
  const ProviderDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Panel de Inicio del Prestador (Próximamente)', style: TextStyle(fontSize: 18)));
  }
}

// =================================================================
// MÓDULO DEL PRESTADOR DE SERVICIOS
// =================================================================

  class ProviderExperiencesTab extends StatefulWidget {
    const ProviderExperiencesTab({super.key});

    @override
    State<ProviderExperiencesTab> createState() => _ProviderExperiencesTabState();
  }

class _ProviderExperiencesTabState extends State<ProviderExperiencesTab> {
  final Dio _dio = Dio();
  final _storage = const FlutterSecureStorage();
  List<dynamic> _misExperiencias = [];
  bool _loading = true;
  
  final String _baseUrl = 'https://vivra-915z.onrender.com/api'; 
  int? _myUserId;
  String? _myToken;

  @override
  void initState() {
    super.initState();
    _fetchMisExperiencias();
  }

  Future<void> _fetchMisExperiencias() async {
    setState(() => _loading = true);
    try {
      String? token = await _storage.read(key: 'auth_token');
      String? savedUserId = await _storage.read(key: 'user_id');
      
      int myUserId = int.tryParse(savedUserId ?? '0') ?? 0;

      _myUserId = myUserId;
      _myToken = token;

      final expResponse = await _dio.get('$_baseUrl/experiencias');

      if (expResponse.statusCode == 200) {
        dynamic data = expResponse.data;
        List<dynamic> allExperiences = (data is List) ? data : (data['data'] ?? []);

        if (mounted) {
          setState(() {
            _misExperiencias = allExperiences.where((exp) {
              int brandId = int.tryParse(exp['brand_id']?.toString() ?? '0') ?? 0;
              return brandId == myUserId;
            }).toList();
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error cargando mis experiencias: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteExperience(int id) async {
  if (id == 0) return;

  try {
    String? token = _myToken ?? await _storage.read(key: 'auth_token');

    // Enviamos POST con '_method': 'DELETE' para Method Spoofing en Laravel
    final response = await _dio.post(
      '$_baseUrl/experiencias/$id',
      data: {
        '_method': 'DELETE',
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ),
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Experiencia eliminada con éxito 🎉'), backgroundColor: Colors.green),
        );
        _fetchMisExperiencias();
      }
    }
  } catch (e) {
    debugPrint('🔥 Error al eliminar: $e');
    String errorMessage = 'Error al eliminar la experiencia.';

    if (e is DioException) {
      final msg = e.response?.data != null ? e.response?.data['message'] : null;
      errorMessage = 'Error (${e.response?.statusCode}): ${msg ?? "No se pudo eliminar"}';
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
      );
    }
  }
}

void _confirmDelete(dynamic expId) {
  int id = int.tryParse(expId?.toString() ?? '0') ?? 0;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Borrar experiencia?'),
      content: const Text('Esta acción no se puede deshacer.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await _deleteExperience(id);
          }, 
          child: const Text('Borrar', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tus Experiencias'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _misExperiencias.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_activity, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No tienes experiencias publicadas aún.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () async {
                        // 1. Verificamos o recuperamos el token guardado
                        String? token = _myToken ?? await _storage.read(key: 'auth_token');
                        
                        if (token == null || token.isEmpty) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No hay una sesión activa. Por favor vuelve a ingresar.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          return;
                        }

                        // 2. Intentamos obtener la información del usuario enviando 'Accept: application/json'
                        int? userId = _myUserId;
                        if (userId == null) {
                          try {
                            final userResponse = await _dio.get(
                              '$_baseUrl/user',
                              options: Options(
                                headers: {
                                  'Authorization': 'Bearer $token',
                                  'Accept': 'application/json', // <-- ENCABEZADO CLAVE PARA LARAVEL
                                },
                              ),
                            );
                            userId = userResponse.data['id'];
                            _myUserId = userId;
                            _myToken = token;
                          } catch (e) {
                            if (e is DioException) {
                              debugPrint('🔥 CÓDIGO ERROR: ${e.response?.statusCode}');
                              debugPrint('🔥 DETALLE LARAVEL: ${e.response?.data}');
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al obtener usuario (${(e is DioException) ? e.response?.statusCode : "red"})'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            return;
                          }
                        }

                        // 3. Abrimos la pantalla para crear la experiencia
                        if (context.mounted && userId != null) {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreateExperienceScreen(
                                brandId: userId!,
                                baseUrl: _baseUrl,
                                token: token,
                              ),
                            ),
                          );

                          if (result == true) {
                            _fetchMisExperiencias();
                          }
                        }
                      },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Crear mi primera experiencia'),
                      )
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchMisExperiencias,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _misExperiencias.length,
                    itemBuilder: (context, index) {
                      final exp = _misExperiencias[index];
                      String title = exp['name'] ?? exp['titulo'] ?? 'Sin título';
                      String price = exp['price']?.toString() ?? exp['precio']?.toString() ?? '0';
                      String? imageUrl = exp['image'] ?? exp['imagen'];
                      bool isActive = exp['active'] == 1 || exp['active'] == true || exp['active'] == '1';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: imageUrl != null && imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl, 
                                      height: 140, 
                                      width: double.infinity, 
                                      fit: BoxFit.cover,
                                      errorBuilder: (_,__,___) => _buildPlaceholderImage(context)
                                    )
                                  : _buildPlaceholderImage(context),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text('\$$price MXN / persona', style: const TextStyle(fontSize: 15, color: Colors.green, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isActive ? Colors.green[100] : Colors.red[100],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.circle, size: 10, color: isActive ? Colors.green[700] : Colors.red[700]),
                                              const SizedBox(width: 6),
                                              Text(isActive ? 'Activa' : 'Inactiva', style: TextStyle(color: isActive ? Colors.green[800] : Colors.red[800], fontSize: 12, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        tooltip: 'Editar',
                                        onPressed: () async {
                                          String? token = _myToken ?? await _storage.read(key: 'auth_token');
                                          String? savedUserId = await _storage.read(key: 'user_id');
                                          int userId = _myUserId ?? int.tryParse(savedUserId ?? '0') ?? 0;

                                          if (context.mounted && token != null) {
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => CreateExperienceScreen(
                                                  brandId: userId,
                                                  baseUrl: _baseUrl,
                                                  token: token,
                                                  experience: exp, // <-- Pasamos el mapa con los datos de la experiencia actual
                                                ),
                                              ),
                                            );

                                            if (result == true) {
                                              _fetchMisExperiencias(); // Recargamos para reflejar los cambios editados
                                            }
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        tooltip: 'Borrar',
                                        onPressed: () => _confirmDelete(exp['id'] ?? 0),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: _misExperiencias.isNotEmpty 
        ? FloatingActionButton.extended(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            onPressed: () async {
              String? token = _myToken ?? await _storage.read(key: 'auth_token');
              String? savedUserId = await _storage.read(key: 'user_id');
              int userId = _myUserId ?? int.tryParse(savedUserId ?? '0') ?? 0;

              if (token == null || token.isEmpty || userId == 0) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor, cierra sesión y vuelve a ingresar para sincronizar tu usuario.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
                return;
              }

              if (context.mounted) {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateExperienceScreen(
                      brandId: userId,
                      baseUrl: _baseUrl,
                      token: token,
                    ),
                  ),
                );

                if (result == true) {
                  _fetchMisExperiencias();
                }
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Nueva'),
          )
        : null,
    );
  }

  Widget _buildPlaceholderImage(BuildContext context) {
    return Container(
      height: 140,
      width: double.infinity,
      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      child: Icon(Icons.landscape, size: 60, color: Theme.of(context).colorScheme.primary),
    );
  }
}

// =================================================================
// MONITOR DE RESERVACIONES (PRESTADOR DE SERVICIOS)
// =================================================================

class ProviderReservationsTab extends StatefulWidget {
  const ProviderReservationsTab({super.key});

  @override
  State<ProviderReservationsTab> createState() => _ProviderReservationsTabState();
}

class _ProviderReservationsTabState extends State<ProviderReservationsTab> {
  final Dio _dio = Dio();
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = 'https://vivra-915z.onrender.com/api';

  List<dynamic> _reservaciones = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchReservaciones();
  }

  Future<void> _fetchReservaciones() async {
    setState(() => _loading = true);
    try {
      String? token = await _storage.read(key: 'auth_token');

      if (token == null || token.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Solicitamos a la API las reservas recibidas por este prestador
      final response = await _dio.get(
        '$_baseUrl/provider/reservaciones',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        dynamic data = response.data;
        List<dynamic> list = (data is List) ? data : (data['data'] ?? []);

        if (mounted) {
          setState(() {
            _reservaciones = list;
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error obteniendo reservaciones del prestador: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
      case 'confirmada':
        return Colors.green;
      case 'pending':
      case 'pendiente':
        return Colors.orange;
      case 'cancelled':
      case 'cancelada':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _formatStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
        return 'Confirmada';
      case 'pending':
        return 'Pendiente';
      case 'cancelled':
        return 'Cancelada';
      default:
        return status ?? 'Desconocido';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitor de Reservaciones'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reservaciones.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'Aún no tienes reservaciones recibidas.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _fetchReservaciones,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualizar'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchReservaciones,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reservaciones.length,
                    itemBuilder: (context, index) {
                      final reserva = _reservaciones[index];
                      final experience = reserva['experience'] ?? {};
                      final user = reserva['user'] ?? {};
                      final schedule = reserva['schedule'] ?? {};

                      String expName = experience['name'] ?? experience['titulo'] ?? 'Experiencia';
                      String touristName = user['name'] ?? user['email'] ?? 'Turista no registrado';
                      String bookingDate = reserva['booking_date'] ?? 'Sin fecha';
                      String startTime = schedule['start_time'] != null
                          ? schedule['start_time'].toString().substring(0, 5)
                          : 'N/A';
                      int quantity = int.tryParse(reserva['quantity']?.toString() ?? '1') ?? 1;
                      String totalPrice = reserva['total_price']?.toString() ?? '0';
                      String status = reserva['status']?.toString() ?? 'pending';

                      Color statusColor = _getStatusColor(status);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cabecera con título de la experiencia y Badge de Estado
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      expName,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: statusColor, width: 1),
                                    ),
                                    child: Text(
                                      _formatStatusText(status),
                                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),

                              // Detalles del turista y evento
                              Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 20, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text('Reservado por: ', style: TextStyle(color: Colors.grey[700])),
                                  Expanded(
                                    child: Text(
                                      touristName,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_month, size: 20, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text('Fecha: ', style: TextStyle(color: Colors.grey[700])),
                                  Text(bookingDate, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 16),
                                  const Icon(Icons.access_time, size: 20, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(startTime, style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.groups, size: 20, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Text('Lugares: ', style: TextStyle(color: Colors.grey[700])),
                                      Text('$quantity persona(s)', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  Text(
                                    '\$$totalPrice MXN',
                                    style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// -----------------------------------------------------------------
// PANTALLA PARA CREAR UNA NUEVA EXPERIENCIA (PRESTADOR)
// -----------------------------------------------------------------
class CreateExperienceScreen extends StatefulWidget {
  final int brandId;
  final String baseUrl;
  final String token;
  final dynamic experience; // Si es null = Crear nueva, si viene objeto = Editar

  const CreateExperienceScreen({
    super.key,
    required this.brandId,
    required this.baseUrl,
    required this.token,
    this.experience,
  });

  @override
  State<CreateExperienceScreen> createState() => _CreateExperienceScreenState();
}



class _CreateExperienceScreenState extends State<CreateExperienceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dio = Dio();
  bool _isSaving = false;

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController(text: '10');
  final _locationController = TextEditingController();
  final _includedPersonsController = TextEditingController(text: '1');
  final _extraPriceController = TextEditingController(text: '0');
  final _imageUrlController = TextEditingController();

  int _selectedCategoryId = 1;

  @override
  void initState() {
    super.initState();
    // Si viene información previa, precargamos todos los controladores para Editar
    if (widget.experience != null) {
      final exp = widget.experience;
      _titleController.text = exp['name'] ?? exp['titulo'] ?? '';
      _descController.text = exp['description'] ?? exp['descripcion'] ?? '';
      _priceController.text = (exp['price'] ?? exp['precio'] ?? 0).toString();
      _stockController.text = (exp['stock'] ?? 10).toString();
      _includedPersonsController.text = (exp['included_persons'] ?? 1).toString();
      _extraPriceController.text = (exp['extra_person_price'] ?? 0).toString();
      _locationController.text = exp['location'] ?? exp['ubicacion'] ?? '';
      _imageUrlController.text = exp['image'] ?? exp['imagen'] ?? '';

      int catId = int.tryParse(exp['category_id']?.toString() ?? '1') ?? 1;
      _selectedCategoryId = [1, 2, 3].contains(catId) ? catId : 1;
    }
  }

  Future<void> _saveExperience() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final bool isEditing = widget.experience != null;
      final dynamic expId = isEditing ? widget.experience['id'] : null;

      final Map<String, dynamic> payload = {
        'name': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'price': double.tryParse(_priceController.text) ?? 0,
        'stock': int.tryParse(_stockController.text) ?? 0,
        'location': _locationController.text.trim(),
        'included_persons': int.tryParse(_includedPersonsController.text) ?? 1,
        'extra_person_price': double.tryParse(_extraPriceController.text) ?? 0,
        'image': _imageUrlController.text.trim(),
        'brand_id': widget.brandId,
        'category_id': _selectedCategoryId,
        'active': 1,
      };

      // Si estamos editando, agregamos '_method': 'PUT' para Laravel
      if (isEditing) {
        payload['_method'] = 'PUT';
      }

      final String url = isEditing
          ? '${widget.baseUrl}/experiencias/$expId'
          : '${widget.baseUrl}/experiencias';

      final options = Options(
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Accept': 'application/json',
        },
      );

      // Siempre usamos .post() para evitar bloqueos HTTP en el servidor
      final response = await _dio.post(url, data: payload, options: options);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditing ? '¡Experiencia actualizada! 🎉' : '¡Experiencia creada con éxito! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      debugPrint('Error guardando la experiencia: $e');
      String errorMessage = 'Error al guardar en el servidor.';

      if (e is DioException) {
        debugPrint('🔥 CÓDIGO DE ERROR: ${e.response?.statusCode}');
        debugPrint('🔥 RESPUESTA DE LARAVEL: ${e.response?.data}');
        
        if (e.response?.data != null && e.response?.data['message'] != null) {
          errorMessage = 'Error (${e.response?.statusCode}): ${e.response?.data['message']}';
        } else {
          errorMessage = 'Error (${e.response?.statusCode}) en la solicitud.';
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.experience != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Experiencia' : 'Nueva Experiencia'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Información General', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título del tour o clase', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Descripción detallada', border: OutlineInputBorder()),
                maxLines: 3,
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Gastronomía')),
                  DropdownMenuItem(value: 2, child: Text('Artesanías')),
                  DropdownMenuItem(value: 3, child: Text('Aventura')),
                ],
                onChanged: (value) => setState(() => _selectedCategoryId = value!),
              ),
              const Divider(height: 48),

              const Text('Precios y Logística', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(
                  labelText: 'Capacidad máxima / Cupo (Stock)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.groups),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Precio Base (\$)', border: OutlineInputBorder(), prefixText: '\$ '),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _includedPersonsController,
                      decoration: const InputDecoration(labelText: 'Personas incluidas', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _extraPriceController,
                      decoration: const InputDecoration(labelText: 'Precio P. Extra (\$)', border: OutlineInputBorder(), prefixText: '\$ '),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Ubicación / Punto de encuentro', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const Divider(height: 48),

              const Text('Multimedia', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(labelText: 'URL de la imagen (Opcional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.image)),
              ),
              const SizedBox(height: 32),

              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveExperience,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isEditing ? Theme.of(context).colorScheme.primary : Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(55),
                      ),
                      child: Text(isEditing ? 'Guardar Cambios' : 'Publicar Experiencia', style: const TextStyle(fontSize: 18)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}