import 'package:flutter/material.dart';

import '../models/compte.dart';
import '../models/journal.dart';
import '../models/tiers.dart';
import '../services/auth_service_local.dart';

/// Écran de consultation/gestion du plan comptable, des tiers et des
/// journaux en mode réseau (client distant), utilisable en autonome (poussé
/// depuis [NetworkSessionPage]) ou par onglet individuel embarqué dans
/// [HomePage] (voir `home_page.dart`, cas réseau des index 4/5/6).
///
/// N'utilise que les opérations déjà exposées par le serveur pour ces trois
/// tables (voir `RemoteRepository`) : liste, création. La modification et la
/// suppression ne sont pas proposées ici — `AuthService.deleteCompte`/
/// `deleteTiers` s'appuient sur une requête SQL brute (vérification des
/// écritures liées) non disponible en mode réseau.
class NetworkDataPage extends StatefulWidget {
  const NetworkDataPage({super.key});

  @override
  State<NetworkDataPage> createState() => _NetworkDataPageState();
}

class _NetworkDataPageState extends State<NetworkDataPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan comptable, tiers, journaux'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Comptes'),
            Tab(text: 'Tiers'),
            Tab(text: 'Journaux'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          NetworkComptesView(),
          NetworkTiersView(),
          NetworkJournauxView(),
        ],
      ),
    );
  }
}

void _showMessage(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
    ),
  );
}

String _padNumeroCompte(String numero, TypeCompte type) {
  const longueurCompteGeneral = 7;
  if (type == TypeCompte.total) return numero;
  if (numero.length >= longueurCompteGeneral) return numero;
  return numero.padRight(longueurCompteGeneral, '0');
}

/// Onglet « Comptes » du mode réseau : liste + création, via
/// [AuthService.getComptes]/[AuthService.createCompte] (déjà compatibles
/// `RemoteRepository`). Embarquable seul dans [HomePage] ou dans
/// [NetworkDataPage].
class NetworkComptesView extends StatefulWidget {
  const NetworkComptesView({super.key});

  @override
  State<NetworkComptesView> createState() => _NetworkComptesViewState();
}

class _NetworkComptesViewState extends State<NetworkComptesView> {
  List<Compte> _comptes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final comptes = await AuthService.getComptes();
      if (!mounted) return;
      setState(() {
        _comptes = comptes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showCreateDialog() {
    final numeroController = TextEditingController();
    final intituleController = TextEditingController();
    TypeCompte selectedType = TypeCompte.detail;
    NatureCompte? calculatedNature;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nouveau compte'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: numeroController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'N° Compte'),
                  autofocus: true,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Champ requis'
                      : null,
                  onChanged: (v) => setDialogState(() =>
                      calculatedNature = calculateNatureFromNumeroCompte(v.trim())),
                ),
                TextFormField(
                  controller: intituleController,
                  decoration: const InputDecoration(labelText: 'Intitulé'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Champ requis'
                      : null,
                ),
                DropdownButtonFormField<TypeCompte>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: TypeCompte.values
                      .map((t) =>
                          DropdownMenuItem(value: t, child: Text(t.toLabel())))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedType = v);
                  },
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    calculatedNature != null
                        ? 'Nature : ${calculatedNature!.toLabel()}'
                        : 'Nature : saisissez un numéro valide',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                if (calculatedNature == null) {
                  _showMessage(context, 'Numéro de compte invalide', isError: true);
                  return;
                }
                try {
                  await AuthService.createCompte(
                    numeroCompte:
                        _padNumeroCompte(numeroController.text.trim(), selectedType),
                    intitule: intituleController.text.trim(),
                    type: selectedType.toDbString(),
                    nature: calculatedNature!.toDbString(),
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  await _load();
                  if (mounted) _showMessage(context, 'Compte créé avec succès');
                } catch (e) {
                  if (context.mounted) {
                    _showMessage(context, 'Erreur: $e', isError: true);
                  }
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : _comptes.isEmpty
                  ? const Center(child: Text('Aucun compte'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _comptes.length,
                        itemBuilder: (context, i) {
                          final c = _comptes[i];
                          return ListTile(
                            leading: const Icon(Icons.account_balance_outlined),
                            title: Text('${c.numeroCompte} — ${c.intitule}'),
                            subtitle: Text(c.nature.toLabel()),
                          );
                        },
                      ),
                    ),
      floatingActionButton: _isLoading || _error != null
          ? null
          : FloatingActionButton(
              onPressed: _showCreateDialog,
              child: const Icon(Icons.add),
            ),
    );
  }
}

/// Onglet « Tiers » du mode réseau : liste + création, via
/// [AuthService.getTiers]/[AuthService.createTiers].
class NetworkTiersView extends StatefulWidget {
  const NetworkTiersView({super.key});

  @override
  State<NetworkTiersView> createState() => _NetworkTiersViewState();
}

class _NetworkTiersViewState extends State<NetworkTiersView> {
  List<Tiers> _tiers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final tiers = await AuthService.getTiers();
      if (!mounted) return;
      setState(() {
        _tiers = tiers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showCreateDialog() {
    final numeroController = TextEditingController();
    final intituleController = TextEditingController();
    final compteCollectifController = TextEditingController();
    final nifController = TextEditingController();
    final adresseController = TextEditingController();
    TypeTiers selectedType = TypeTiers.client;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nouveau tiers'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: numeroController,
                    decoration: const InputDecoration(labelText: 'N° Compte'),
                    autofocus: true,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Champ requis'
                        : null,
                  ),
                  TextFormField(
                    controller: intituleController,
                    decoration: const InputDecoration(labelText: 'Intitulé'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Champ requis'
                        : null,
                  ),
                  TextFormField(
                    controller: compteCollectifController,
                    decoration:
                        const InputDecoration(labelText: 'Compte collectif'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Champ requis'
                        : null,
                  ),
                  DropdownButtonFormField<TypeTiers>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: TypeTiers.values
                        .map((t) => DropdownMenuItem(
                            value: t, child: Text(t.toLabel())))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedType = v);
                    },
                  ),
                  TextFormField(
                    controller: nifController,
                    decoration: const InputDecoration(labelText: 'NIF'),
                  ),
                  TextFormField(
                    controller: adresseController,
                    decoration: const InputDecoration(labelText: 'Adresse'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await AuthService.createTiers(
                    numeroCompte: numeroController.text.trim(),
                    intitule: intituleController.text.trim(),
                    type: selectedType.toDbString(),
                    compteCollectif: compteCollectifController.text.trim(),
                    nif: nifController.text.trim().isEmpty
                        ? null
                        : nifController.text.trim(),
                    adresse: adresseController.text.trim().isEmpty
                        ? null
                        : adresseController.text.trim(),
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  await _load();
                  if (mounted) _showMessage(context, 'Tiers créé avec succès');
                } catch (e) {
                  if (context.mounted) {
                    _showMessage(context, 'Erreur: $e', isError: true);
                  }
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : _tiers.isEmpty
                  ? const Center(child: Text('Aucun tiers'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _tiers.length,
                        itemBuilder: (context, i) {
                          final t = _tiers[i];
                          return ListTile(
                            leading: const Icon(Icons.people_outline),
                            title: Text('${t.numeroCompte} — ${t.intitule}'),
                            subtitle: Text(t.type.toLabel()),
                          );
                        },
                      ),
                    ),
      floatingActionButton: _isLoading || _error != null
          ? null
          : FloatingActionButton(
              onPressed: _showCreateDialog,
              child: const Icon(Icons.add),
            ),
    );
  }
}

/// Onglet « Journaux » du mode réseau : liste + création, via
/// [AuthService.getJournaux]/[AuthService.createJournal].
class NetworkJournauxView extends StatefulWidget {
  const NetworkJournauxView({super.key});

  @override
  State<NetworkJournauxView> createState() => _NetworkJournauxViewState();
}

class _NetworkJournauxViewState extends State<NetworkJournauxView> {
  List<Journal> _journaux = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final journaux = await AuthService.getJournaux();
      if (!mounted) return;
      setState(() {
        _journaux = journaux;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showCreateDialog() {
    final codeController = TextEditingController();
    final libelleController = TextEditingController();
    final compteTresorerieController = TextEditingController();
    TypeJournal selectedType = TypeJournal.financier;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nouveau journal'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Code'),
                  autofocus: true,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Champ requis'
                      : null,
                ),
                TextFormField(
                  controller: libelleController,
                  decoration: const InputDecoration(labelText: 'Intitulé'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Champ requis'
                      : null,
                ),
                DropdownButtonFormField<TypeJournal>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: TypeJournal.values
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(t.toLabel())))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedType = v);
                  },
                ),
                if (selectedType == TypeJournal.financier)
                  TextFormField(
                    controller: compteTresorerieController,
                    decoration: const InputDecoration(
                        labelText: 'Compte de trésorerie'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await AuthService.createJournal(
                    code: codeController.text.trim(),
                    libelle: libelleController.text.trim(),
                    type: selectedType.toDbString(),
                    numeroCompteFresorerie:
                        compteTresorerieController.text.trim().isEmpty
                            ? null
                            : compteTresorerieController.text.trim(),
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  await _load();
                  if (mounted) _showMessage(context, 'Journal créé avec succès');
                } catch (e) {
                  if (context.mounted) {
                    _showMessage(context, 'Erreur: $e', isError: true);
                  }
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Erreur: $_error'))
              : _journaux.isEmpty
                  ? const Center(child: Text('Aucun journal'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _journaux.length,
                        itemBuilder: (context, i) {
                          final j = _journaux[i];
                          return ListTile(
                            leading: const Icon(Icons.menu_book_outlined),
                            title: Text('${j.code} — ${j.intitule}'),
                            subtitle: Text(j.type.toLabel()),
                          );
                        },
                      ),
                    ),
      floatingActionButton: _isLoading || _error != null
          ? null
          : FloatingActionButton(
              onPressed: _showCreateDialog,
              child: const Icon(Icons.add),
            ),
    );
  }
}
