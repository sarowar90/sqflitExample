import 'dart:math';
import '../models/greeting.dart';

class GreetingService {
  GreetingService._();
  static final GreetingService instance = GreetingService._();

  static const List<Map<String, dynamic>> _greetings = [
    {'id': 1, 'message': 'Hello! How are you doing today?', 'language': 'English', 'category': 'casual'},
    {'id': 2, 'message': 'Good morning! Have a wonderful day!', 'language': 'English', 'category': 'morning'},
    {'id': 3, 'message': 'Hey there! Great to see you!', 'language': 'English', 'category': 'casual'},
    {'id': 4, 'message': 'Bonjour! Comment ça va?', 'language': 'French', 'category': 'casual'},
    {'id': 5, 'message': 'Hola! ¿Cómo estás?', 'language': 'Spanish', 'category': 'casual'},
    {'id': 6, 'message': 'Namaste! Aap kaise hain?', 'language': 'Hindi', 'category': 'casual'},
    {'id': 7, 'message': 'Welcome! Wishing you a productive day!', 'language': 'English', 'category': 'formal'},
    {'id': 8, 'message': 'Konnichiwa! Genki desu ka?', 'language': 'Japanese', 'category': 'casual'},
    {'id': 9, 'message': 'Good evening! Hope your day went well!', 'language': 'English', 'category': 'evening'},
    {'id': 10, 'message': 'Ciao! Come stai?', 'language': 'Italian', 'category': 'casual'},
    {'id': 11, 'message': 'Greetings! May your day be filled with joy!', 'language': 'English', 'category': 'formal'},
    {'id': 12, 'message': 'Salut! Wie geht es dir?', 'language': 'German', 'category': 'casual'},
  ];

  final Random _random = Random();

  // Returns a single random greeting
  Greeting getRandom() {
    final map = _greetings[_random.nextInt(_greetings.length)];
    return Greeting.fromMap(map);
  }

  // Returns all greetings
  List<Greeting> getAll() {
    return _greetings.map(Greeting.fromMap).toList();
  }

  // Returns a random greeting filtered by language
  Greeting? getRandomByLanguage(String language) {
    final filtered = _greetings
        .where((g) => g['language'].toString().toLowerCase() == language.toLowerCase())
        .toList();
    if (filtered.isEmpty) return null;
    return Greeting.fromMap(filtered[_random.nextInt(filtered.length)]);
  }

  // Returns a random greeting filtered by category
  Greeting? getRandomByCategory(String category) {
    final filtered = _greetings
        .where((g) => g['category'].toString().toLowerCase() == category.toLowerCase())
        .toList();
    if (filtered.isEmpty) return null;
    return Greeting.fromMap(filtered[_random.nextInt(filtered.length)]);
  }

  // Returns a greeting by id, null if not found
  Greeting? getById(int id) {
    final match = _greetings.where((g) => g['id'] == id).toList();
    if (match.isEmpty) return null;
    return Greeting.fromMap(match.first);
  }
}
