import 'dart:convert';
import 'dart:typed_data';

import 'aliases.dart';
import 'big5.dart';
import 'big5hkscs.dart';
import 'cp932.dart';
import 'cp950.dart';
import 'eucjp.dart';
import 'euckr.dart';
import 'gb18030.dart';
import 'gb2312.dart';
import 'gbk.dart';
import 'sbcs.dart';
import 'shiftjis.dart';
import 'shiftjis2004.dart';

///
const Map<String, List> mbcs = {
  'big5': [big5],
  'big5hkscs': [big5hkscs, big5],
  'cp932': [cp932, shiftjis],
  'cp950': [cp950, big5],
  'eucjp': [eucjp],
  'euckr': [euckr],
  'gb18030': [gb18030, gbk],
  'gb2312': [gb2312, gbk],
  'gbk': [gbk],
  'shiftjis': [shiftjis],
  'shiftjis2004': [shiftjis2004, shiftjis],
};

///
typedef DecodeFunc = int Function(Iterator bytes, dynamic param);

///
class Charset {
  ///
  static bool check(String charset) {
    var cs = charset.replaceAll(RegExp(r'[^0-9a-z]'), '');
    cs = aliases[cs] ?? cs;
    if (cs == 'utf8') {
      return true;
    }
    return mbcs.containsKey(cs) || sbcs.containsKey(cs);
  }

  ///
  static String decode(List<int> bytes, String charset) {
    var cs = charset.replaceAll(RegExp(r'[^0-9a-z]'), '');
    cs = aliases[cs] ?? cs;
    if (cs == 'utf8') {
      return utf8.decode(bytes, allowMalformed: true);
    } else if (mbcs.containsKey(cs)) {
      return _decode(bytes, _decodeMbsc, mbcs[cs]!);
    } else {
      return _decode(bytes, _decodeSbsc, sbcs[cs] ?? 'ascii');
    }
  }

  static String _decode(List<int> bytes, DecodeFunc decoder, dynamic param) {
    final codeUnits = Uint16List(bytes.length);
    final it = bytes.iterator;
    var count = 0;
    while (it.moveNext()) {
      final code = decoder(it, param);
      if (code < 0x10000) {
        codeUnits[count++] = code;
      } else {
        codeUnits[count++] = 0xd800 + ((code - 0x10000) >> 10);
        codeUnits[count++] = 0xdc00 + ((code - 0x10000) & 0x3ff);
      }
    }
    return String.fromCharCodes(codeUnits.sublist(0, count));
  }

  static int _decodeSbsc(Iterator bytes, dynamic characters) {
    final byte = bytes.current;
    var character = 0xFFFD;
    if (byte < (characters as String).length) {
      character = byte < 0x80 ? byte : characters.codeUnitAt(byte);
    }
    return character;
  }

  static int _decodeMbsc(Iterator bytes, dynamic charmaps) {
    final byte = bytes.current;
    int character;
    if (byte < 0x80) {
      character = byte;
    } else if (byte <= 0xff && bytes.moveNext()) {
      final byte2 = bytes.current;
      character = 0xFFFD;
      for (final charmap in charmaps) {
        final map = charmap[byte] ?? {};
        for (final trail in map.entries) {
          if (byte2 >= trail.key &&
              byte2 < trail.key + trail.value.runes.length) {
            return character = trail.value.runes.elementAt(byte2 - trail.key);
          }
        }
      }
    } else {
      character = 0xFFFD;
    }
    return character;
  }
}
