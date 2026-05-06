import 'package:flutter/material.dart';
import '../models/user_session.dart';
import '../models/saisie_comptable.dart';
import '../services/database_service.dart';
import '../services/saisie_comptable_service.dart';

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
  DateTime? _dateDebutInterrog;
  DateTime? _dateFinInterrog;
  List<LigneEcriture> _interrogationResultats = [];
  String? _interrogationMessage;
  bool isLoadingInterrog = false;

  // Lettrages
  final _numeroCompteLettrageController = TextEditingController();
  List<LigneEcriture> _lettrageResultats = [];
  final Set<int> _selectedLettrageIds = <int>{};
  String? _lettrageMessage;
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
    void Function(DateTime picked) onPicked,
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
        onPicked(picked);
      });
    }
  }

  String _formatMontant(double value) {
    final formatted = value
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(?<=\d)(?=(\d{3})+(?!\d))'), (match) => ' ');
    return '$formatted FCFA';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _rechercher() async {
    final numeroCompte = _numeroCompteInterrogController.text.trim();
    if (numeroCompte.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir un numéro de compte'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isLoadingInterrog = true;
      _interrogationMessage = null;
    });

    try {
      await DatabaseService.ensureDatabaseOpen();
      final resultats = await SaisieComptableService.getEcrituresParCompte(
        numeroCompte: numeroCompte,
        dateDebut: _dateDebutInterrog,
        dateFin: _dateFinInterrog,
      );

      if (!mounted) return;
      setState(() {
        _interrogationResultats = resultats;
        _interrogationMessage =
            resultats.isEmpty
                ? 'Aucune écriture trouvée pour ce compte.'
                : '${resultats.length} écriture(s) chargée(s).';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resultats.isEmpty
                ? 'Aucune écriture trouvée'
                : 'Interrogation terminée',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _interrogationResultats = [];
        _interrogationMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur d’interrogation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoadingInterrog = false);
      }
    }
  }

  Future<void> _chargerLettrage() async {
    final numeroCompte = _numeroCompteLettrageController.text.trim();
    if (numeroCompte.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir un numéro de compte'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isLoadingLettrage = true;
      _lettrageMessage = null;
    });

    try {
      await DatabaseService.ensureDatabaseOpen();
      final resultats = await SaisieComptableService.getEcrituresNonLettrees(
        numeroCompte: numeroCompte,
      );

      if (!mounted) return;
      setState(() {
        _lettrageResultats = resultats;
        _selectedLettrageIds.clear();
        _lettrageMessage =
            resultats.isEmpty
                ? 'Aucune écriture non lettrée trouvée.'
                : '${resultats.length} écriture(s) disponible(s) pour lettrage.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lettrageResultats = [];
        _selectedLettrageIds.clear();
        _lettrageMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de chargement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoadingLettrage = false);
      }
    }
  }

  Future<void> _lettrer() async {
    final numeroCompte = _numeroCompteLettrageController.text.trim();
    if (numeroCompte.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir un numéro de compte'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (selectedMode == 'manuel' && _selectedLettrageIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionnez au moins deux écritures à lettrer'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isLoadingLettrage = true);

    try {
      await DatabaseService.ensureDatabaseOpen();

      if (selectedMode == 'automatique') {
        final codes = await SaisieComptableService.lettrerAutomatiquement(
          numeroCompte: numeroCompte,
        );
        await _chargerLettrage();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              codes.isEmpty
                  ? 'Aucune paire automatique trouvée'
                  : 'Lettrage automatique effectué sur ${codes.length} groupe(s)',
            ),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      final code = await SaisieComptableService.lettrerEcritures(
        numeroCompte: numeroCompte,
        ecritureIds: _selectedLettrageIds.toList(),
      );
      await _chargerLettrage();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lettrage manuel enregistré: $code'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de lettrage: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoadingLettrage = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar:
          widget.showAppBar
              ? AppBar(
                title: const Text('Interrogations & Lettrages'),
                backgroundColor: Colors.blue.shade400,
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
                colors: [Colors.white, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
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
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.analytics,
                        color: Colors.black,
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
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Consultation et rapprochement des écritures',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
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
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
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
                        color: Colors.blue,
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
                                  (picked) => _dateDebutInterrog = picked,
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
                                  (picked) => _dateFinInterrog = picked,
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
                            _dateDebutInterrog = null;
                            _dateFinInterrog = null;
                            _interrogationResultats = [];
                            _interrogationMessage = null;
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
                            backgroundColor: Colors.blue,
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
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenHeight * 0.02,
              vertical: screenHeight * 0.01,
            ),
            child:
                _interrogationResultats.isEmpty
                    ? SizedBox(
                      height: 260,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _interrogationMessage ??
                                  'Aucune recherche effectuée',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    : Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _interrogationMessage ??
                                        'Résultats de l’interrogation',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Solde: ${_formatMontant(_interrogationResultats.fold<double>(0, (sum, item) => sum + item.montantDebit - item.montantCredit))}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _interrogationResultats.length,
                              separatorBuilder:
                                  (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                return _buildEcritureTile(
                                  _interrogationResultats[index],
                                  showCheckbox: false,
                                  showLettrageActions: false,
                                );
                              },
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
                        color: Colors.blue,
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
                            activeColor: Colors.blue,
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
                            activeColor: Colors.blue,
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
                          child: OutlinedButton.icon(
                            onPressed:
                                isLoadingLettrage ? null : _chargerLettrage,
                            icon:
                                isLoadingLettrage
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.refresh),
                            label: const Text('Charger'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                              backgroundColor: Colors.blue,
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
            child:
                _lettrageResultats.isEmpty
                    ? Card(
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
                                  color: Colors.blue.shade700,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Informations sur le lettrage',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                            _buildInfoItem(
                              'Lettrage manuel',
                              'Sélectionnez les écritures non lettrées puis enregistrez un rapprochement commun.',
                              Icons.touch_app,
                            ),
                            const SizedBox(height: 12),
                            _buildInfoItem(
                              'Lettrage automatique',
                              'Regroupe les écritures qui s’équilibrent par montant et référence.',
                              Icons.auto_awesome,
                            ),
                            const SizedBox(height: 12),
                            _buildInfoItem(
                              'Délettrage',
                              'L’opération inverse peut être exécutée depuis le service si besoin.',
                              Icons.link_off,
                            ),
                            if (_lettrageMessage != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _lettrageMessage!,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                    : Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _lettrageMessage ??
                                        'Écritures disponibles pour lettrage',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Sélection: ${_selectedLettrageIds.length}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _lettrageResultats.length,
                              separatorBuilder:
                                  (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                return _buildEcritureTile(
                                  _lettrageResultats[index],
                                  showCheckbox: true,
                                  showLettrageActions: true,
                                );
                              },
                            ),
                            if (_lettrageMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _lettrageMessage!,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
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
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue.shade700, size: 20),
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

  Widget _buildEcritureTile(
    LigneEcriture ecriture, {
    required bool showCheckbox,
    required bool showLettrageActions,
  }) {
    final isSelected = _selectedLettrageIds.contains(ecriture.id);
    final solde = ecriture.montantDebit - ecriture.montantCredit;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap:
            showCheckbox && ecriture.id != null
                ? () {
                  setState(() {
                    if (isSelected) {
                      _selectedLettrageIds.remove(ecriture.id);
                    } else {
                      _selectedLettrageIds.add(ecriture.id!);
                    }
                  });
                }
                : null,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.blue.shade300 : Colors.grey.shade200,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showCheckbox)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Checkbox(
                    value: isSelected,
                    onChanged:
                        ecriture.id == null
                            ? null
                            : (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedLettrageIds.add(ecriture.id!);
                                } else {
                                  _selectedLettrageIds.remove(ecriture.id);
                                }
                              });
                            },
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ecriture.libelle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (ecriture.isLettrie)
                          Chip(
                            label: Text(
                              ecriture.lettrageCode ?? 'Lettrée',
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.green.shade50,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Text('Date: ${_formatDate(ecriture.dateComptable)}'),
                        Text('Pièce: ${ecriture.numeroDocument}'),
                        Text('Compte: ${ecriture.numeroCompte}'),
                        if (ecriture.reference != null &&
                            ecriture.reference!.trim().isNotEmpty)
                          Text('Réf: ${ecriture.reference}'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Text(
                          'Débit: ${_formatMontant(ecriture.montantDebit)}',
                          style: const TextStyle(color: Colors.green),
                        ),
                        Text(
                          'Crédit: ${_formatMontant(ecriture.montantCredit)}',
                          style: const TextStyle(color: Colors.red),
                        ),
                        Text(
                          'Solde ligne: ${_formatMontant(solde)}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (showLettrageActions) const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
