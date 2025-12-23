import 'dart:convert';
import 'gost/gost_28147_engine.dart';
import 'hex.dart';
import 'ozdst/ozdst_1106_digest.dart';

class GostHash {
  static List<int> hash(List<int> data, {String sBoxName = "D_A"}) {
    final sbox = GOST28147Engine.getSBox(sBoxName);
    final digest = OzDSt1106Digest(sbox);
    digest.reset();
    digest.updateBuffer(data, 0, data.length);
    final h = List<int>.filled(digest.digestSize, 0);
    digest.doFinal(h, 0);
    return h;
  }

  static String hashGost(String text) {
    var ba = hash(utf8.encode(text));
    return Hex.fromBytes(ba);
  }

  static String hashGost2Hex(List<int> raw) {
    var ba = hash(raw);
    return Hex.fromBytes(ba);
  }
}
