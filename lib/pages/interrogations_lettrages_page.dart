import 'package:flutter/material.dart';
import '../models/user_session.dart';

class InterrogationsLettragesPage extends StatefulWidget {
  final UserSession userSession;
  final bool showAppBar;

  const InterrogationsLettragesPage({
    super.key,
    required this.userSession,
    this.showAppBar = true,
  });

  @override
  State<InterrogationsLettragesPage> createState() =>
      _InterrogationsLettragesPageState();
}

class _InterrogationsLettragesPageState
    extends State<InterrogationsLettragesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Interrogations
  final _numeroCompteInterrogController = TextEditingController();
  final _dateDebutInterrogController = TextEditingController();
  final _dateFinInterrogController = TextEditingController();
  bool isLoadingInterrog = false;

  // Lettrages
  final _numeroCompteLettrageController = TextEditingController();
  bool isLoadingLettrage = false;
  String? selectedMode = 'manuel';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _numeroCompteInterrogController.dispose();
    _dateDebutInterrogController.dispose();
    _dateFinInterrogController.dispose();
    _numeroCompteLettrageController.dispose();
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
    setState(() => isLoadingInterrog = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => isLoadingInterrog = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Recherche effectuée')));
  }

  Future<void> _lettrer() async {
    if (_numeroCompteLettrageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir un numéro de compte'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isLoadingLettrage = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => isLoadingLettrage = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selectedMode == 'automatique'
              ? 'Lettrage automatique effectué'
              : 'Lettrage manuel en cours',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar:
          widget.showAppBar
              ? AppBar(
                title: const Text('Interrogations & Lettrages'),
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
                        Icons.analytics,
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
                            'Interrogations & Lettrages',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Consultation et rapprochement des écritures',
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
          // Onglets
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.indigo,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.indigo,
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.search), text: 'Interrogations'),
                Tab(icon: Icon(Icons.link), text: 'Lettrages'),
              ],
            ),
          ),
          // Contenu des onglets
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInterrogationsTab(screenHeight),
                _buildLettragesTab(screenHeight),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterrogationsTab(double screenHeight) {
    return SingleChildScrollView(
      child: Column(
        children: [
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
                            controller: _numeroCompteInterrogController,
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
                            controller: _dateDebutInterrogController,
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
                                () => _selectDate(
                                  context,
                                  _dateDebutInterrogController,
                                ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _dateFinInterrogController,
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
                                () => _selectDate(
                                  context,
                                  _dateFinInterrogController,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            _numeroCompteInterrogController.clear();
                            _dateDebutInterrogController.clear();
                            _dateFinInterrogController.clear();
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
                          onPressed: isLoadingInterrog ? null : _rechercher,
                          icon:
                              isLoadingInterrog
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
          SizedBox(
            height: 300,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLettragesTab(double screenHeight) {
    return SingleChildScrollView(
      child: Column(
        children: [
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
                      'Mode de lettrage',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Lettrage manuel'),
                            subtitle: const Text(
                              'Sélection manuelle des écritures',
                            ),
                            value: 'manuel',
                            groupValue: selectedMode,
                            onChanged: (value) {
                              setState(() => selectedMode = value);
                            },
                            activeColor: Colors.indigo,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Lettrage automatique'),
                            subtitle: const Text(
                              'Lettrage par montant et référence',
                            ),
                            value: 'automatique',
                            groupValue: selectedMode,
                            onChanged: (value) {
                              setState(() => selectedMode = value);
                            },
                            activeColor: Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _numeroCompteLettrageController,
                            decoration: InputDecoration(
                              labelText: 'Numéro de compte',
                              hintText: 'Ex: 401000, 411000',
                              helperText: 'Comptes clients ou fournisseurs',
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
                          child: ElevatedButton.icon(
                            onPressed: isLoadingLettrage ? null : _lettrer,
                            icon:
                                isLoadingLettrage
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Icon(Icons.link),
                            label: const Text('Lettrer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 20,
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: screenHeight * 0.02),
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.indigo.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Informations sur le lettrage',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildInfoItem(
                      'Lettrage manuel',
                      'Sélection manuelle des écritures à rapprocher',
                      Icons.touch_app,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      'Lettrage automatique',
                      'Rapprochement automatique par montant et référence',
                      Icons.auto_awesome,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      'Délettrage',
                      'Possibilité de délettrer si nécessaire',
                      Icons.link_off,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String description, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.indigo.shade700, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
