class Greeting {
  final int id;
  final String message;
  final String language;
  final String category;

  const Greeting({
    required this.id,
    required this.message,
    required this.language,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'message': message,
      'language': language,
      'category': category,
    };
  }

  factory Greeting.fromMap(Map<String, dynamic> map) {
    return Greeting(
      id: map['id'] as int,
      message: map['message'] as String,
      language: map['language'] as String,
      category: map['category'] as String,
    );
  }

  @override
  String toString() =>
      'Greeting(id: $id, language: $language, category: $category, message: $message)';
}
