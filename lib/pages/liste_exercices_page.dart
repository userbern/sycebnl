import 'package:flutter/material.dart';

class ListeExercicesPage extends StatelessWidget {
  final List<Map<String, dynamic>> exercices;
  final int? activeExerciceId;
  final Future<void> Function(int id) onSwitch;
  final VoidCallback onCreateNew;
  final Future<void> Function(
    int id,
    String code,
    String dateDebut,
    String dateFin,
  ) onEdit;
  final Future<void> Function(int id) onCloture;
  final Future<List<Map<String, dynamic>>> Function(int id)
      onCheckPeriodesEquilibre;

  const ListeExercicesPage({
    super.key,
    required this.exercices,
    required this.activeExerciceId,
    required this.onSwitch,
    required this.onCreateNew,
    required this.onEdit,
    required this.onCloture,
    required this.onCheckPeriodesEquilibre,
  });

  String _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final d = DateTime.parse(iso.substring(0, 10));
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  DateTime? _parseDate(String? iso) {
    if (iso == null) return null;
    try {
      return DateTime.parse(iso.substring(0, 10));
    } catch (_) {
      return null;
    }
  }

  int _dureeMois(String? debut, String? fin) {
    final d = _parseDate(debut);
    final f = _parseDate(fin);
    if (d == null || f == null) return 0;
    return (f.year - d.year) * 12 + (f.month - d.month) + 1;
  }

  int _moisEcoules(String? debut) {
    final d = _parseDate(debut);
    if (d == null) return 0;
    final now = DateTime.now();
    return ((now.year - d.year) * 12 + (now.month - d.month)).clamp(0, 9999);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.calendar_month_outlined,
                      color: Colors.blue.shade700, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Exercices comptables',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${exercices.length} exercice${exercices.length > 1 ? 's' : ''} enregistré${exercices.length > 1 ? 's' : ''}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onCreateNew,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nouvel exercice'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: exercices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun exercice créé',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: onCreateNew,
                          icon: const Icon(Icons.add),
                          label: const Text('Créer le premier exercice'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: exercices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final ex = exercices[i];
                      final isActive = ex['id'] == activeExerciceId;
                      final duree = _dureeMois(
                          ex['date_debut']?.toString(),
                          ex['date_fin']?.toString());
                      final ecoules =
                          _moisEcoules(ex['date_debut']?.toString());
                      return _ExerciceCard(
                        ex: ex,
                        isActive: isActive,
                        dateLabel:
                            '${_fmt(ex['date_debut']?.toString())} → ${_fmt(ex['date_fin']?.toString())}',
                        dureeMois: duree,
                        moisEcoules: ecoules,
                        onSwitch: () => onSwitch(ex['id'] as int),
                        onEdit: () => _showEditDialog(context, ex),
                        onCloture: () => _showClotureDialog(context, ex),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showClotureDialog(
      BuildContext context, Map<String, dynamic> ex) async {
    final id = ex['id'] as int;
    final code = ex['code']?.toString() ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FutureBuilder<List<Map<String, dynamic>>>(
        future: onCheckPeriodesEquilibre(id),
        builder: (ctx, snapshot) {
          final loading = !snapshot.hasData && !snapshot.hasError;
          final periodes = snapshot.data ?? [];

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.lock_outline,
                    color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Text('Clôturer $code'),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (snapshot.hasError)
                          Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red.shade600, size: 18),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Impossible de vérifier les périodes.',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          )
                        else if (periodes.isEmpty)
                          Row(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  color: Colors.green.shade600, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                  'Toutes les périodes sont équilibrées.',
                                  style: TextStyle(fontSize: 13)),
                            ],
                          )
                        else ...[
                          Row(
                            children: [
                              Icon(Icons.warning_amber_outlined,
                                  color: Colors.orange.shade700, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '${periodes.length} période${periodes.length > 1 ? 's' : ''} non équilibrée${periodes.length > 1 ? 's' : ''} :',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...periodes.map((p) => Padding(
                                padding: const EdgeInsets.only(
                                    left: 26, bottom: 3),
                                child: Text(
                                  '• ${p['code_journal']}  —  ${_moisLabel(p['mois'] as int?)}  ${p['annee']}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700),
                                ),
                              )),
                        ],
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Text(
                            'Cette action est irréversible. L\'exercice clôturé ne pourra plus être modifié.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              if (!loading)
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Clôturer'),
                ),
            ],
          );
        },
      ),
    );

    if (confirm == true) {
      await onCloture(id);
    }
  }

  String _moisLabel(int? mois) {
    const noms = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
      'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
    ];
    if (mois == null || mois < 1 || mois > 12) return '-';
    return noms[mois - 1];
  }

  Future<void> _showEditDialog(
      BuildContext context, Map<String, dynamic> ex) async {
    final codeCtrl =
        TextEditingController(text: ex['code']?.toString() ?? '');

    DateTime? parseIso(String? iso) {
      if (iso == null) return null;
      try {
        return DateTime.parse(iso.substring(0, 10));
      } catch (_) {
        return null;
      }
    }

    final dDebut = parseIso(ex['date_debut']?.toString()) ?? DateTime.now();
    final dFin = parseIso(ex['date_fin']?.toString()) ?? DateTime.now();

    int dDay = dDebut.day,
        dMonth = dDebut.month,
        dYear = dDebut.year;
    int fDay = dFin.day, fMonth = dFin.month, fYear = dFin.year;

    const monthNames = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];

    int daysInMonth(int y, int m) => DateTime(y, m + 1, 0).day;
    final years = List.generate(51, (i) => 2000 + i);

    InputDecoration dropDec(String label) => InputDecoration(
          labelText: label,
          isDense: true,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          Widget dateRow({
            required String label,
            required int day,
            required int month,
            required int year,
            required void Function(int d, int m, int y) onChange,
          }) {
            final maxDay = daysInMonth(year, month);
            final effDay = day > maxDay ? maxDay : day;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: DropdownButtonFormField<int>(
                        value: effDay,
                        decoration: dropDec('Jour'),
                        isExpanded: true,
                        items: List.generate(maxDay, (i) => i + 1)
                            .map((d) => DropdownMenuItem(
                                value: d,
                                child: Text(d.toString().padLeft(2, '0'))))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => onChange(v ?? effDay, month, year)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: month,
                        decoration: dropDec('Mois'),
                        isExpanded: true,
                        items: List.generate(12, (i) => i + 1)
                            .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(monthNames[m - 1])))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          final nd = daysInMonth(year, v);
                          setState(
                              () => onChange(day > nd ? nd : day, v, year));
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: DropdownButtonFormField<int>(
                        value: year,
                        decoration: dropDec('Année'),
                        isExpanded: true,
                        items: years
                            .map((y) => DropdownMenuItem(
                                value: y, child: Text('$y')))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          final nd = daysInMonth(v, month);
                          setState(
                              () => onChange(day > nd ? nd : day, month, v));
                        },
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('Modifier l\'exercice'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: codeCtrl,
                      decoration: InputDecoration(
                        labelText: 'Code de l\'exercice',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    dateRow(
                      label: 'Date de début',
                      day: dDay,
                      month: dMonth,
                      year: dYear,
                      onChange: (d, m, y) {
                        dDay = d;
                        dMonth = m;
                        dYear = y;
                      },
                    ),
                    const SizedBox(height: 16),
                    dateRow(
                      label: 'Date de fin',
                      day: fDay,
                      month: fMonth,
                      year: fYear,
                      onChange: (d, m, y) {
                        fDay = d;
                        fMonth = m;
                        fYear = y;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true) {
      final dd =
          '$dYear-${dMonth.toString().padLeft(2, '0')}-${dDay.toString().padLeft(2, '0')}';
      final df =
          '$fYear-${fMonth.toString().padLeft(2, '0')}-${fDay.toString().padLeft(2, '0')}';
      await onEdit(ex['id'] as int, codeCtrl.text.trim(), dd, df);
    }
    codeCtrl.dispose();
  }
}

class _ExerciceCard extends StatelessWidget {
  final Map<String, dynamic> ex;
  final bool isActive;
  final String dateLabel;
  final int dureeMois;
  final int moisEcoules;
  final VoidCallback onSwitch;
  final VoidCallback onEdit;
  final VoidCallback onCloture;

  const _ExerciceCard({
    required this.ex,
    required this.isActive,
    required this.dateLabel,
    required this.dureeMois,
    required this.moisEcoules,
    required this.onSwitch,
    required this.onEdit,
    required this.onCloture,
  });

  bool get _isCloture =>
      (ex['is_cloture'] as int? ?? 0) == 1 ||
      (ex['statut']?.toString().toUpperCase() == 'CLOTURE');

  String get _badgeLabel {
    if (isActive) return 'ACTIF';
    if (_isCloture) return 'CLÔTURÉ';
    return 'OUVERT';
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        dureeMois > 0 ? (moisEcoules / dureeMois).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? Colors.blue.shade400 : Colors.grey.shade200,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.blue : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      ex['code']?.toString() ?? '-',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    _Badge(label: _badgeLabel, active: isActive),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$dateLabel  ·  $dureeMois mois',
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                if (isActive) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$moisEcoules mois · en cours',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (!isActive && !_isCloture)
            OutlinedButton(
              onPressed: onSwitch,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child:
                  const Text('Activer', style: TextStyle(fontSize: 13)),
            ),
          if (!_isCloture) ...[
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onCloture,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade700,
                side: BorderSide(color: Colors.orange.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child:
                  const Text('Clôturer', style: TextStyle(fontSize: 13)),
            ),
          ],
          const SizedBox(width: 8),
          if (!_isCloture)
            InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.edit_outlined,
                    size: 15, color: Colors.grey.shade500),
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final bool active;

  const _Badge({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    Color bg, text, border;
    if (active) {
      bg = Colors.blue.shade50;
      text = Colors.blue.shade700;
      border = Colors.blue.shade200;
    } else if (label == 'CLÔTURÉ') {
      bg = Colors.grey.shade100;
      text = Colors.grey.shade600;
      border = Colors.grey.shade300;
    } else {
      bg = Colors.orange.shade50;
      text = Colors.orange.shade700;
      border = Colors.orange.shade200;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: text,
            letterSpacing: 0.3),
      ),
    );
  }
}
