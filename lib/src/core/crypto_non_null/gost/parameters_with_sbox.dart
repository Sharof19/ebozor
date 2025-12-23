import '../gost/cipher_parameters.dart';

class ParametersWithSBox extends CipherParameters {
  ParametersWithSBox(this.parameters, this.sBox);

  final CipherParameters? parameters;
  final List<int> sBox;
}
