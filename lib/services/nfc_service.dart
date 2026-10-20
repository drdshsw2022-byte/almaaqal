import 'dart:async';
import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// نتيجة قراءة NFC: إما رمز هوية من هاتف طالب، أو معرّف شريحة بطاقة.
class NfcRead {
  final String? payload; // من هاتف الطالب (HCE)
  final String? uid; // معرّف الشريحة (HEX)
  NfcRead({this.payload, this.uid});
}

class NfcService {
  NfcService._();

  static const _hceKey = 'hce_payload';

  static Future<bool> isAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// على هاتف الطالب: يحفظ رمز الهوية ليقدّمه الهاتف عند تقريبه من قارئ الدكتور.
  /// تقرؤه خدمة Android الأصلية (StudentHceService) من SharedPreferences.
  static Future<void> setStudentPayload(String? payload) async {
    final p = await SharedPreferences.getInstance();
    if (payload == null) {
      await p.remove(_hceKey);
    } else {
      await p.setString(_hceKey, payload);
    }
  }

  static Uint8List _hex(String h) => Uint8List.fromList([
        for (var i = 0; i < h.length; i += 2)
          int.parse(h.substring(i, i + 2), radix: 16)
      ]);

  static String _toHex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join().toUpperCase();

  static String? _identifier(NfcTag tag) {
    final id = NfcA.from(tag)?.identifier ??
        IsoDep.from(tag)?.identifier ??
        MifareClassic.from(tag)?.identifier ??
        MifareUltralight.from(tag)?.identifier ??
        NfcB.from(tag)?.identifier ??
        NfcF.from(tag)?.identifier ??
        NfcV.from(tag)?.identifier;
    if (id == null || id.isEmpty) return null;
    return _toHex(id);
  }

  /// يبدأ القراءة المستمرة على هاتف الدكتور. كل بطاقة/هاتف يُقرَّب يُستدعى له [onRead].
  static Future<void> startReading(
      void Function(NfcRead r) onRead, void Function(String e) onError) async {
    await NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          // 1) هاتف طالب يقدّم الهوية عبر HCE
          final iso = IsoDep.from(tag);
          if (iso != null) {
            final aid = _hex(AppConfig.nfcAid);
            final apdu = Uint8List.fromList(
                [0x00, 0xA4, 0x04, 0x00, aid.length, ...aid, 0x00]);
            try {
              final res = await iso.transceive(data: apdu);
              if (res.length > 2 &&
                  res[res.length - 2] == 0x90 &&
                  res[res.length - 1] == 0x00) {
                final text = String.fromCharCodes(res.sublist(0, res.length - 2));
                onRead(NfcRead(payload: text));
                return;
              }
            } catch (_) {
              // ليست هاتفاً بهوية المعقل: نكمل بمعرّف الشريحة
            }
          }
          // 2) بطاقة هوية: نستخدم معرّف الشريحة
          final uid = _identifier(tag);
          if (uid != null) {
            onRead(NfcRead(uid: uid));
          } else {
            onError('تعذّرت قراءة البطاقة، أعد تقريبها');
          }
        } catch (e) {
          onError('خطأ في قراءة NFC: $e');
        }
      },
    );
  }

  static Future<void> stopReading() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }

  /// قراءة بطاقة واحدة (لربطها بطالب). تعيد معرّف الشريحة أو null عند الإلغاء.
  static Completer<String?>? _pending;

  static Future<String?> readOneUid(
      {Duration timeout = const Duration(seconds: 30)}) async {
    final c = Completer<String?>();
    _pending = c;
    await NfcManager.instance.startSession(onDiscovered: (tag) async {
      final uid = _identifier(tag);
      if (!c.isCompleted) c.complete(uid);
    });
    final r = await c.future.timeout(timeout, onTimeout: () => null);
    _pending = null;
    await stopReading();
    return r;
  }

  /// إلغاء انتظار [readOneUid].
  static void cancelOne() {
    final c = _pending;
    if (c != null && !c.isCompleted) c.complete(null);
  }
}
