import '../gost/gost_28147_engine.dart';
import '../gost/key_parameter.dart';
import '../gost/parameters_with_sbox.dart';

class OzDSt1106Digest {
  static const int _digestLength = 32;

  final List<int> _h = List.filled(32, 0);
  final List<int> _l = List.filled(32, 0);
  final List<int> _m = List.filled(32, 0);
  final List<int> _sum = List.filled(32, 0);
  final List<List<int>?> _c = List<List<int>?>.filled(4, null, growable: false);

  final List<int> _xBuf = List.filled(32, 0);
  int _xBufOff = 0;
  int _byteCount = 0;

  final GOST28147Engine _cipher = GOST28147Engine();
  late final List<int> _sBox;

  static _arraycopy(
      List<int> inp, int inOff, List<int> out, int outOff, int length) {
    for (int i = 0; i < length; i++) {
      if (i + inOff >= inp.length) break;
      out[i + outOff] = inp[i + inOff];
    }
  }

  OzDSt1106Digest(List<int> sBoxParam) {
    _sBox = List.filled(sBoxParam.length, 0);
    _arraycopy(sBoxParam, 0, _sBox, 0, sBoxParam.length);
    _cipher.init(true, ParametersWithSBox(null, _sBox));
    reset();
  }

  String get algorithmName => "OzDSt1106";

  int get digestSize => _digestLength;

  void updateByte(int inp) {
    _xBuf[_xBufOff++] = inp;
    if (_xBufOff == _xBuf.length) {
      _sumByteArray(_xBuf); // calc sum M
      _processBlock(_xBuf, 0);
      _xBufOff = 0;
    }
    _byteCount++;
  }

  void updateBuffer(List<int> inp, int inOff, int len) {
    while ((_xBufOff != 0) && (len > 0)) {
      updateByte(inp[inOff]);
      inOff++;
      len--;
    }

    while (len > _xBuf.length) {
      _arraycopy(inp, inOff, _xBuf, 0, _xBuf.length);
      _sumByteArray(_xBuf); // calc sum M
      _processBlock(_xBuf, 0);
      inOff += _xBuf.length;
      len -= _xBuf.length;
      _byteCount += _xBuf.length;
    }

    // load in the remainder.
    while (len > 0) {
      updateByte(inp[inOff]);
      inOff++;
      len--;
    }
  }

  // (i + 1 + 4(k - 1)) = 8i + k      i = 0-3, k = 1-8
  final List<int> _k = List.filled(32, 0);
  List<int> _permute(List<int> inp) {
    for (int k = 0; k < 8; k++) {
      _k[4 * k] = inp[k];
      _k[1 + 4 * k] = inp[8 + k];
      _k[2 + 4 * k] = inp[16 + k];
      _k[3 + 4 * k] = inp[24 + k];
    }
    return _k;
  }

//A (x) = (x0 ^ x1) || x3 || x2 || x1
  final List<int> _a = List.filled(8, 0);
  List<int> _transformA(List<int> inp) {
    for (int j = 0; j < 8; j++) {
      _a[j] = (inp[j] ^ inp[j + 8]) & 0xFF;
    }
    _arraycopy(inp, 8, inp, 0, 24);
    _arraycopy(_a, 0, inp, 24, 8);
    return inp;
  }

  //Encrypt function, ECB mode
  void _encryptBlock(
      List<int> key, List<int> s, int sOff, List<int> inp, int inOff) {
    _cipher.init(true, KeyParameter(key));
    _cipher.processBlock(inp, inOff, s, sOff);
  }

// (in:) n16||..||n1 ==> (out:) n1^n2^n3^n4^n13^n16||n16||..||n2
  final List<int> _wShorts = List.filled(16, 0);
  final List<int> _wTemp = List.filled(16, 0);
  void _fw(List<int> inp) {
    _cpyBytesToShort(inp, _wShorts);
    _wTemp[15] = (_wShorts[0] ^
            _wShorts[1] ^
            _wShorts[2] ^
            _wShorts[3] ^
            _wShorts[12] ^
            _wShorts[15]) &
        0xFFFF;
    _arraycopy(_wShorts, 1, _wTemp, 0, 15);
    _cpyShortToBytes(_wTemp, inp);
  }

  final List<int> _state = List.filled(32, 0);
  final List<int> _u = List.filled(32, 0);
  final List<int> _v = List.filled(32, 0);
  final List<int> _w = List.filled(32, 0);
  // block processing
  void _processBlock(List<int> inp, int inOff) {
    _arraycopy(inp, inOff, _m, 0, 32);

    //key step 1

    // H = h3 || h2 || h1 || h0
    // S = s3 || s2 || s1 || s0
    _arraycopy(_h, 0, _u, 0, 32);
    _arraycopy(_m, 0, _v, 0, 32);

    for (int j = 0; j < 32; j++) {
      _w[j] = (_u[j] ^ _v[j]) & 0xFF;
    }

    // Encrypt gost28147-ECB
    _encryptBlock(_permute(_w), _state, 0, _h, 0); // s0 = EK0 [h0]

    //keys step 2,3,4
    for (int i = 1; i < 4; i++) {
      List<int> tmpA = _transformA(_u);
      for (int j = 0; j < 32; j++) {
        _u[j] = (tmpA[j] ^ _c[i]![j]) & 0xFF;
      }
      _transformA(_v);
      _transformA(_v);
      for (int j = 0; j < 32; j++) {
        _w[j] = (_u[j] ^ _v[j]) & 0xFF;
      }
      // Encrypt gost28147-ECB
      _encryptBlock(_permute(_w), _state, i * 8, _h, i * 8); // si = EKi [hi]
    }

    // x(M, H) = y61(H^y(M^y12(S)))
    for (int n = 0; n < 12; n++) {
      _fw(_state);
    }
    for (int n = 0; n < 32; n++) {
      _state[n] = (_state[n] ^ _m[n]) & 0xFF;
    }

    _fw(_state);

    for (int n = 0; n < 32; n++) {
      _state[n] = (_h[n] ^ _state[n]) & 0xFF;
    }
    for (int n = 0; n < 61; n++) {
      _fw(_state);
    }
    _arraycopy(_state, 0, _h, 0, _h.length);
  }

  static void _intToLittleEndian(int n, List<int> bs, int off) {
    bs[off] = (n) & 0xFF;
    bs[++off] = ((n & 0xFFFFFFFF) >> 8) & 0xFF;
    bs[++off] = ((n & 0xFFFFFFFF) >> 16) & 0xFF;
    bs[++off] = ((n & 0xFFFFFFFF) >> 24) & 0xFF;
  }

  static void _longToLittleEndian(int n, List<int> bs, int off) {
    _intToLittleEndian((n) & 0xffffffff, bs, off);
    // JAVASCIPT CANNOT MAKE (n >>> 32)
    //intToLittleEndian((n >>> 32) & 0xffffffff, bs, off + 4);
  }

  void finish() {
    _longToLittleEndian(
        _byteCount * 8, _l, 0); // get length into L (byteCount * 8 = bitCount)

    while (_xBufOff != 0) {
      updateByte(0 & 0xFF);
    }

    _processBlock(_l, 0);
    _processBlock(_sum, 0);
  }

  int doFinal(List<int> out, int outOff) {
    finish();
    _arraycopy(_h, 0, out, outOff, _h.length);
    reset();
    return _digestLength;
  }

  /// Reset the chaining variables to the IV values.
  final List<int> _c2 = [
    0x00,
    0xFF,
    0x00,
    0xFF,
    0x00,
    0xFF,
    0x00,
    0xFF,
    0xFF,
    0x00,
    0xFF,
    0x00,
    0xFF,
    0x00,
    0xFF,
    0x00,
    0x00,
    0xFF,
    0xFF,
    0x00,
    0xFF,
    0x00,
    0x00,
    0xFF,
    0xFF,
    0x00,
    0x00,
    0x00,
    0xFF,
    0xFF,
    0x00,
    0xFF
  ];

  void reset() {
    for (int i = 0; i < _c.length; i++) {
      _c[i] = List.filled(32, 0);
    }
    _byteCount = 0;
    _xBufOff = 0;

    _h.fillRange(0, _h.length, 0);
    _l.fillRange(0, _l.length, 0);
    _m.fillRange(0, _m.length, 0);
    _c[1]!.fillRange(0, _c[1]!.length, 0);
    _c[3]!.fillRange(0, _c[3]!.length, 0);
    _sum.fillRange(0, _sum.length, 0);
    _xBuf.fillRange(0, _xBuf.length, 0);

    // for (let i = 0; i < H.length; i++) {
    //     H[i] = 0;  // start vector H
    // }
    // for (let i = 0; i < L.length; i++) {
    //     L[i] = 0;
    // }
    // for (let i = 0; i < M.length; i++) {
    //     M[i] = 0;
    // }
    // for (let i = 0; i < C[1].length; i++) {
    //     C[1][i] = 0;  // real index C = +1 because index array with 0.
    // }
    // for (let i = 0; i < C[3].length; i++) {
    //     C[3][i] = 0;
    // }
    // for (let i = 0; i < Sum.length; i++) {
    //     Sum[i] = 0;
    // }
    // for (let i = 0; i < xBuf.length; i++) {
    //     xBuf[i] = 0;
    // }

    _arraycopy(_c2, 0, _c[2]!, 0, _c2.length);
  }

  //  256 bitsblock modul -> (Sum + a mod (2^256))
  void _sumByteArray(List<int> inp) {
    int carry = 0;
    for (int i = 0; i != _sum.length; i++) {
      int sum = (_sum[i] & 0xff) + (inp[i] & 0xff) + carry;
      _sum[i] = sum & 0xFF;
      carry = (sum & 0xFFFFFFFF) >> 8;
    }
  }

  void _cpyBytesToShort(List<int> S, List<int> wS) {
    for (int i = 0; i < S.length / 2; i++) {
      wS[i] = (((S[i * 2 + 1] << 8) & 0xFF00) | (S[i * 2] & 0xFF)) & 0xFFFF;
    }
  }

  void _cpyShortToBytes(List<int> wS, List<int> S) {
    for (int i = 0; i < S.length / 2; i++) {
      S[i * 2 + 1] = (wS[i] >> 8) & 0xFF;
      S[i * 2] = wS[i] & 0xFF;
    }
  }

  int get byteLength => 32;
}
