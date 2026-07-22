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
class ReservationsTab extends StatelessWidget {
  final bool isLoggedIn;
  final VoidCallback onGoToLogin;

  const ReservationsTab({super.key, required this.isLoggedIn, required this.onGoToLogin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tus Reservaciones'), backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
      body: !isLoggedIn
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.confirmation_number_outlined, size: 80, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('Inicia sesión para consultar tus reservaciones.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
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
          : const Center(child: Text('No tienes reservaciones activas por el momento.')),
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
        String token = response.data['token'] ?? 'token_valido';
        widget.onLoginSuccess(token);
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
            TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder())),
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
// PANTALLA DE DETALLE
// -----------------------------------------------------------------
class ExperienceDetailScreen extends StatelessWidget {
  final dynamic experience;
  final bool isLoggedIn;

  const ExperienceDetailScreen({super.key, required this.experience, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    String title = experience['name'] ?? experience['titulo'] ?? 'Experiencia';
    var price = experience['price'] ?? experience['precio'] ?? 0;
    String desc = experience['description'] ?? experience['descripcion'] ?? 'Sin descripción';

    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Precio: \$$price MXN', style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(desc, style: const TextStyle(fontSize: 15)),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC76A28),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isLoggedIn ? '¡Reservando $title!' : 'Debes iniciar sesión para comprar.')),
                );
              },
              child: Text(isLoggedIn ? 'Comprar' : 'Iniciar Sesión para Reservar'),
            ),
          ],
        ),
      ),
    );
  }
}