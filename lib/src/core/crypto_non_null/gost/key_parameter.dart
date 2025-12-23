import '../gost/cipher_parameters.dart';

class KeyParameter extends CipherParameters {
  KeyParameter(this.key);

  final List<int> key;
}
