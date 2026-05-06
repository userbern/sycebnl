import 'package:flutter_test/flutter_test.dart';
import 'package:sycebnl_accounting/models/compte.dart';

void main() {
  group('Compte model helpers', () {
    test('converts type and nature strings to enums', () {
      expect(stringToTypeCompte('detail'), TypeCompte.detail);
      expect(stringToTypeCompte('total'), TypeCompte.total);
      expect(stringToTypeCompte('unknown'), TypeCompte.detail);

      expect(
        stringToNatureCompte('bilan_fournisseurs'),
        NatureCompte.bilanFournisseurs,
      );
      expect(stringToNatureCompte('charges_ao'), NatureCompte.chargesAO);
    });

    test('calculates nature from account number prefix', () {
      expect(
        calculateNatureFromNumeroCompte('1010000'),
        NatureCompte.bilanRessourcesDurables,
      );
      expect(
        calculateNatureFromNumeroCompte('4012000'),
        NatureCompte.bilanFournisseurs,
      );
      expect(
        calculateNatureFromNumeroCompte('5200000'),
        NatureCompte.bilanBanque,
      );
      expect(
        calculateNatureFromNumeroCompte('7000000'),
        NatureCompte.produitsAO,
      );
    });

    test('builds from map and serializes back to json', () {
      final compte = Compte.fromMap({
        'id': 7,
        'numero_compte': '4010001',
        'intitule': 'Fournisseur principal',
        'type': 'detail',
        'nature': 'bilan_fournisseurs',
        'liaison_tiers': 1,
        'description': 'Compte test',
        'is_active': 1,
        'created_at': '2026-04-29T10:00:00.000Z',
        'updated_at': '2026-04-29T10:30:00.000Z',
      });

      expect(compte.id, '7');
      expect(compte.numeroCompte, '4010001');
      expect(compte.intitule, 'Fournisseur principal');
      expect(compte.type, TypeCompte.detail);
      expect(compte.nature, NatureCompte.bilanFournisseurs);
      expect(compte.liaisonTiers, isTrue);
      expect(compte.description, 'Compte test');
      expect(compte.isActive, isTrue);
      expect(compte.toJson()['numero_compte'], '4010001');
      expect(compte.toJson()['type'], 'detail');
      expect(compte.toJson()['nature'], 'bilan_fournisseurs');
    });
  });
}
