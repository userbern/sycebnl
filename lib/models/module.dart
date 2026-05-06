class Module {
  final int? id;
  final String nom;

  Module({this.id, required this.nom});

  factory Module.fromMap(Map<String, dynamic> map) {
    return Module(id: map['id'] as int?, nom: map['nom'] as String? ?? '');
  }

  Map<String, dynamic> toMap() {
    return {if (id != null) 'id': id, 'nom': nom};
  }

  Module copyWith({int? id, String? nom}) {
    return Module(id: id ?? this.id, nom: nom ?? this.nom);
  }
}
