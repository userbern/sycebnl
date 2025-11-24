import 'package:flutter/material.dart';
import '../models/user_session.dart';
import '../services/auth_service.dart';

class MonnaiePageEdit extends StatefulWidget {
  final UserSession userSession;

  const MonnaiePageEdit({Key? key, required this.userSession})
    : super(key: key);

  @override
  State<MonnaiePageEdit> createState() => _MonnaiePageEditState();
}

class _MonnaiePageEditState extends State<MonnaiePageEdit> {
  final List<Map<String, dynamic>> currencies = [
    {'code': 'XOF', 'label': 'Franc CFA (XOF)', 'symbol': 'Fr'},
    {'code': 'EUR', 'label': 'Euro (EUR)', 'symbol': '€'},
    {'code': 'USD', 'label': 'Dollar US (USD)', 'symbol': '\$'},
    {'code': 'GBP', 'label': 'Livre Sterling (GBP)', 'symbol': '£'},
  ];

  late String selectedCurrency = 'XOF';
  bool isLoading = false;
  String? errorMessage;
  late String currentCurrencyCode = 'XOF';

  @override
  void initState() {
    super.initState();
    _loadCurrentCurrency();
  }

  Future<void> _loadCurrentCurrency() async {
    try {
      setState(() => isLoading = true);

      final entites = await AuthService.getEntites();
      if (entites.isNotEmpty) {
        final currency = entites.first.currency ?? 'XOF';
        setState(() {
          selectedCurrency = currency;
          currentCurrencyCode = currency;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => errorMessage = 'Erreur: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _saveCurrency() async {
    if (selectedCurrency == currentCurrencyCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun changement à enregistrer'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final entites = await AuthService.getEntites();
      if (entites.isNotEmpty) {
        await AuthService.updateEntite(
          id: entites.first.id,
          currency: selectedCurrency,
        );

        if (!mounted) return;
        setState(() {
          currentCurrencyCode = selectedCurrency;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Monnaie mise à jour avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => errorMessage = 'Erreur: ${e.toString()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (!widget.userSession.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Monnaie'),
          backgroundColor: Colors.indigo,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 80, color: Colors.grey[400]),
              SizedBox(height: screenHeight * 0.02),
              const Text(
                'Accès refusé',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              const Text(
                'Seuls les administrateurs peuvent configurer la monnaie',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monnaie de tenue de compte'),
        backgroundColor: Colors.indigo,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                child: SingleChildScrollView(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    padding: EdgeInsets.all(screenHeight * 0.03),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Icône principale
                        Center(
                          child: Container(
                            padding: EdgeInsets.all(screenHeight * 0.015),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.attach_money,
                              size: 40,
                              color: Colors.indigo,
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.015),

                        // Titre centré
                        const Text(
                          'Configuration de la monnaie',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.008),
                        Text(
                          'Sélectionnez la monnaie pour la tenue de vos comptes',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),

                        // Message d'erreur
                        if (errorMessage != null)
                          Container(
                            padding: EdgeInsets.all(screenHeight * 0.02),
                            margin: EdgeInsets.only(
                              bottom: screenHeight * 0.03,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                  size: 24,
                                ),
                                SizedBox(width: screenHeight * 0.015),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Carte principale
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(screenHeight * 0.02),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Monnaie actuelle
                                Container(
                                  padding: EdgeInsets.all(screenHeight * 0.015),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue.shade50,
                                        Colors.blue.shade100,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.info_outline,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Monnaie actuelle',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.blue.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            SizedBox(height: 3),
                                            Text(
                                              currencies.firstWhere(
                                                (c) =>
                                                    c['code'] ==
                                                    currentCurrencyCode,
                                              )['label'],
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        currencies.firstWhere(
                                          (c) =>
                                              c['code'] == currentCurrencyCode,
                                        )['symbol'],
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.02),

                                // Label pour sélection
                                Text(
                                  'Choisir une nouvelle monnaie',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.01),

                                // Options de monnaie (cartes cliquables)
                                ...currencies.map((currency) {
                                  final isSelected =
                                      selectedCurrency == currency['code'];
                                  final isCurrent =
                                      currentCurrencyCode == currency['code'];

                                  return Container(
                                    margin: EdgeInsets.only(
                                      bottom: screenHeight * 0.01,
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          selectedCurrency = currency['code'];
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color:
                                              isSelected
                                                  ? Colors.indigo.shade50
                                                  : Colors.grey.shade50,
                                          border: Border.all(
                                            color:
                                                isSelected
                                                    ? Colors.indigo
                                                    : Colors.grey.shade300,
                                            width: isSelected ? 2 : 1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color:
                                                    isSelected
                                                        ? Colors.indigo
                                                        : Colors.grey.shade300,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  currency['symbol'],
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        isSelected
                                                            ? Colors.white
                                                            : Colors
                                                                .grey
                                                                .shade600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    currency['label'],
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          isSelected
                                                              ? FontWeight.bold
                                                              : FontWeight.w500,
                                                      color:
                                                          isSelected
                                                              ? Colors
                                                                  .indigo
                                                                  .shade900
                                                              : Colors.black87,
                                                    ),
                                                  ),
                                                  if (isCurrent)
                                                    Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                            top: 4,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors
                                                                .green
                                                                .shade100,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        'En cours d\'utilisation',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Colors
                                                                  .green
                                                                  .shade700,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            if (isSelected)
                                              Icon(
                                                Icons.check_circle,
                                                color: Colors.indigo,
                                                size: 24,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),

                        // Boutons d'action
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close, size: 18),
                                label: const Text('Annuler'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey.shade700,
                                  side: BorderSide(color: Colors.grey.shade300),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed:
                                    selectedCurrency == currentCurrencyCode
                                        ? null
                                        : _saveCurrency,
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                ),
                                label: const Text('Enregistrer'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  disabledForegroundColor: Colors.grey.shade500,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  elevation:
                                      selectedCurrency == currentCurrencyCode
                                          ? 0
                                          : 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
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
    );
  }
}
