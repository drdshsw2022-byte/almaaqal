import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';

import '../../app_state.dart';
import '../../data/repo.dart';
import '../../models.dart';
import '../../services/nfc_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// ربط بطاقات NFC بالطلبة بالتتابع: يظهر اسم الطالب، تُقرَّب بطاقته، ثم ينتقل للتالي.
class NfcBulkLinkScreen extends StatefulWidget {
  final List<Student> students;
  final String title;
  const NfcBulkLinkScreen(
      {super.key, required this.students, this.title = 'ربط بطاقات الطلبة'});

  @override
  State<NfcBulkLinkScreen> createState() => _NfcBulkLinkScreenState();
}

class _NfcBulkLinkScreenState extends State<NfcBulkLinkScreen> {
  late List<Student> _queue;
  int _i = 0;
  bool _onlyUnlinked = true;
  bool _write = false;
  bool _running = false;
  bool _busy = false;
  String? _msg;
  bool _msgOk = true;
  int _done = 0;

  @override
  void initState() {
    super.initState();
    _build();
  }

  @override
  void dispose() {
    NfcService.stopReading();
    super.dispose();
  }

  void _build() {
    _queue = widget.students
        .where((s) => !_onlyUnlinked || s.nfcUid == null)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    _i = 0;
  }

  Student? get _cur => _i < _queue.length ? _queue[_i] : null;

  Future<void> _start() async {
    if (!await NfcService.isAvailable()) {
      if (mounted) {
        showSnack(context, 'NFC غير متاح أو مطفأ على هذا الهاتف', error: true);
      }
      return;
    }
    setState(() => _running = true);
    await NfcService.startTagSession(_onTag, (e) {
      if (mounted) {
        setState(() {
          _msg = e;
          _msgOk = false;
          _busy = false;
        });
      }
    });
  }

  Future<void> _stop() async {
    await NfcService.stopReading();
    if (mounted) setState(() => _running = false);
  }

  Future<void> _onTag(NfcTag tag, NfcRead r) async {
    final s = _cur;
    if (s == null || _busy) return;
    if (r.phoneWithoutId || (r.payload != null && r.uid == null)) {
      _say('هذا هاتف وليس بطاقة؛ قرّب البطاقة الجامعية', false);
      return;
    }
    final uid = r.uid;
    if (uid == null) {
      _say('تعذّرت قراءة البطاقة، أعد تقريبها', false);
      return;
    }
    setState(() => _busy = true);
    try {
      await repo.setStudentNfc(s.id, uid);
      var extra = '';
      if (_write) {
        try {
          await NfcService.writeCode(tag, StudentCode.encode(s));
          extra = ' وكُتبت الهوية عليها';
        } catch (e) {
          extra = ' (لم تُكتب الهوية على البطاقة: ${'$e'.replaceFirst('Exception: ', '')})';
        }
      }
      _done++;
      _i++;
      _say('✔ ربطت بطاقة $uid بـ ${s.name}$extra', true);
    } catch (e) {
      _say(friendlyError(e), false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String m, bool ok) {
    if (!mounted) return;
    setState(() {
      _msg = m;
      _msgOk = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _cur;
    return Scaffold(
      appBar: gradientAppBar(widget.title),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_running) ...[
            SwitchListTile(
              value: _onlyUnlinked,
              onChanged: (v) => setState(() {
                _onlyUnlinked = v;
                _build();
              }),
              title: const Text('الطلبة غير المرتبطة بطاقاتهم فقط'),
              subtitle: Text('${_queue.length} طالباً في القائمة'),
            ),
            SwitchListTile(
              value: _write,
              onChanged: (v) => setState(() => _write = v),
              title: const Text('كتابة هوية الطالب على البطاقة أيضاً'),
              subtitle: const Text(
                  'تجعل البطاقة تُقرأ على أي هاتف حتى دون اتصال بالخادم. لا تفعّلها إن كانت البطاقة تُستخدم لأنظمة أخرى (أبواب، مكتبة).'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _queue.isEmpty ? null : _start,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('بدء الربط'),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                  gradient: AppColors.mainGradient,
                  borderRadius: BorderRadius.circular(24)),
              child: Column(
                children: [
                  const Icon(Icons.nfc, color: Colors.white, size: 64),
                  const SizedBox(height: 10),
                  if (s == null)
                    const Text('اكتمل ربط جميع الطلبة في القائمة 🎉',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800))
                  else ...[
                    Text('قرّب بطاقة:',
                        style:
                            TextStyle(color: Colors.white.withOpacity(0.8))),
                    Text(s.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900)),
                    Text('الرقم المعرفي: ${s.id} • ${stageName(s.stage)}',
                        style: const TextStyle(color: AppColors.gold)),
                    const SizedBox(height: 6),
                    Text('${_i + 1} من ${_queue.length}',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ],
              ),
            ),
            if (_msg != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_msg!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _msgOk ? AppColors.emerald : AppColors.rose)),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: s == null
                        ? null
                        : () => setState(() {
                              _i++;
                              _msg = 'تخطّيت ${s.name}';
                              _msgOk = true;
                            }),
                    icon: const Icon(Icons.skip_next),
                    label: const Text('تخطٍّ (بلا بطاقة)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _i == 0
                        ? null
                        : () => setState(() {
                              _i--;
                              _msg = null;
                            }),
                    icon: const Icon(Icons.undo),
                    label: const Text('السابق'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
                onPressed: _stop,
                child: Text('إيقاف (رُبطت $_done بطاقة)')),
          ],
          const SizedBox(height: 14),
          Text(
            repo.isDemo
                ? 'ملاحظة: التطبيق غير متصل بالخادم بعد، فيُحفظ الربط على هذا الهاتف فقط. لاستخدامه على هاتف آخر: فعّل «كتابة الهوية على البطاقة»، أو ارفع ملف الطلاب هناك مع عمود «رقم البطاقة».'
                : 'يُحفظ الربط على خادم الجامعة ويعمل فوراً على هواتف جميع التدريسيين.',
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.6),
          ),
        ],
      ),
    );
  }
}
