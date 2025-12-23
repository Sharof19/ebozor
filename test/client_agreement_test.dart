import 'dart:convert';

import 'package:ebozor/src/data/services/client_agreements_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClientAgreement.fromJson', () {
    test('returns defaults when source is not a map', () {
      final agreement = ClientAgreement.fromJson('invalid');

      expect(agreement.id, 0);
      expect(agreement.signatories, isEmpty);
      expect(agreement.readyContractHtml, isNull);
      expect(agreement.readyContractUrl, isNull);
    });

    test('parses fields, signatories and base64/html content', () {
      final html = '<p>Hello</p>';
      final base64Html = base64.encode(utf8.encode(html));

      final agreement = ClientAgreement.fromJson({
        'id': 12,
        'number': 'N-1',
        'client': 'Acme',
        'contract_type_name': 'Lease',
        'start_date': '2024-01-01',
        'end_date': '2024-12-31',
        'status_name': 'pending',
        'is_active': true,
        'signatories': [
          {
            'signatory_name': 'Bob',
            'role': 'client',
            'status': 'pending',
            'signing_order': '2',
            'signed_at': null,
            'is_signed': false,
          }
        ],
        'ready_contract': base64Html,
      });

      expect(agreement.id, 12);
      expect(agreement.number, 'N-1');
      expect(agreement.isActive, isTrue);
      expect(agreement.signatories.single.name, 'Bob');
      expect(agreement.signatories.single.signingOrder, 2);
      expect(agreement.readyContractHtml, contains(html));
      expect(agreement.readyContractUrl, isNull);
    });

    test('prefers URL when content is not HTML', () {
      const url = 'https://example.com/contract.pdf';

      final agreement = ClientAgreement.fromJson({
        'signatories': [],
        'ready_contract': url,
      });

      expect(agreement.readyContractUrl, url);
      expect(agreement.readyContractHtml, isNull);
    });
  });
}
