import 'package:flutter_test/flutter_test.dart';
import 'package:sycebnl_accounting/models/tiers.dart';

void main() {
  group('Tiers model helpers', () {
    test('converts tier types to labels and db strings', () {
      expect(TypeTiers.client.toDbString(), 'client');
      expect(TypeTiers.salarie.toDbString(), 'salarié');
      expect(stringToTypeTiers('autre'), TypeTiers.autre);
      expect(stringToTypeTiers('unknown'), TypeTiers.client);
    });

    test('builds from map and serializes back to json', () {
      final tiers = Tiers.fromMap({
        'id': 12,
        'numero_compte': '401001',
        'intitule': 'Fournisseur alpha',
        'type': 'fournisseur',
        'compte_collectif': '401',
        'nif': 'NIF123',
        'adresse': 'Dakar',
        'is_active': 1,
        'created_at': '2026-04-29T11:00:00.000Z',
        'updated_at': '2026-04-29T11:15:00.000Z',
      });

      expect(tiers.id, '12');
      expect(tiers.numeroCompte, '401001');
      expect(tiers.intitule, 'Fournisseur alpha');
      expect(tiers.type, TypeTiers.fournisseur);
      expect(tiers.compteCollectif, '401');
      expect(tiers.nif, 'NIF123');
      expect(tiers.adresse, 'Dakar');
      expect(tiers.isActive, isTrue);
      expect(tiers.toJson()['type'], 'fournisseur');
      expect(tiers.toJson()['compte_collectif'], '401');
    });
  });
}
