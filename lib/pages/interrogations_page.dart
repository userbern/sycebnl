import 'package:flutter/material.dart';
import '../models/user_session.dart';
import '../models/compte.dart';

class InterrogationsPage extends StatefulWidget {
  final UserSession userSession;
  final bool showAppBar;

  const InterrogationsPage({
    super.key,
    required this.userSession,
    this.showAppBar = true,
  });

  @override
  State<InterrogationsPage> createState() => _InterrogationsPageState();
}

class _InterrogationsPageState extends State<InterrogationsPage> {
  final _numeroCompteController = TextEditingController();
  final _dateDebutController = TextEditingController();
  final _dateFinController = TextEditingController();
  NatureCompte? _selectedNature;
  TypeCompte? _selectedType;
  bool isLoading = false;

  @override
  void dispose() {
    _numeroCompteController.dispose();
    _dateDebutController.dispose();
    _dateFinController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  Future<void> _rechercher() async {
    setState(() => isLoading = true);

    // Simulation d'une recherche
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() => isLoading = false);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Recherche effectuée')));
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar:
          widget.showAppBar
              ? AppBar(
                title: const Text('Interrogations'),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              )
              : null,
      body: Column(
        children: [
          // En-tête
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(screenHeight * 0.02),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade700, Colors.indigo.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Interrogations',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Consultation des écritures comptables',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Formulaire de recherche
          Padding(
            padding: EdgeInsets.all(screenHeight * 0.02),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Critères de recherche',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _numeroCompteController,
                            decoration: InputDecoration(
                              labelText: 'Numéro de compte',
                              hintText: 'Ex: 401000',
                              prefixIcon: const Icon(Icons.account_balance),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _dateDebutController,
                            decoration: InputDecoration(
                              labelText: 'Date début',
                              hintText: 'JJ/MM/AAAA',
                              prefixIcon: const Icon(Icons.calendar_today),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            readOnly: true,
                            onTap:
                                () =>
                                    _selectDate(context, _dateDebutController),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _dateFinController,
                            decoration: InputDecoration(
                              labelText: 'Date fin',
                              hintText: 'JJ/MM/AAAA',
                              prefixIcon: const Icon(Icons.calendar_today),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            readOnly: true,
                            onTap:
                                () => _selectDate(context, _dateFinController),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Filtres par nature et type
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<NatureCompte?>(
                            value: _selectedNature,
                            decoration: InputDecoration(
                              labelText: 'Nature du compte',
                              prefixIcon: const Icon(Icons.category),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('-- Toutes les natures --'),
                              ),
                              for (final nature in NatureCompte.values)
                                DropdownMenuItem(
                                  value: nature,
                                  child: Text(nature.toLabel()),
                                ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedNature = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<TypeCompte?>(
                            value: _selectedType,
                            decoration: InputDecoration(
                              labelText: 'Type de compte',
                              prefixIcon: const Icon(Icons.type_specimen),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('-- Tous les types --'),
                              ),
                              for (final type in TypeCompte.values)
                                DropdownMenuItem(
                                  value: type,
                                  child: Text(type.toLabel()),
                                ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedType = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Container()), // Espacement
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            _numeroCompteController.clear();
                            _dateDebutController.clear();
                            _dateFinController.clear();
                            setState(() {
                              _selectedNature = null;
                              _selectedType = null;
                            });
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('Réinitialiser'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: isLoading ? null : _rechercher,
                          icon:
                              isLoading
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Icon(Icons.search),
                          label: const Text('Rechercher'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            elevation: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Zone de résultats
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune recherche effectuée',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Utilisez les critères ci-dessus pour interroger les écritures',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
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
