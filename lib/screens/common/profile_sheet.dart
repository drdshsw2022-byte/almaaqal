import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// نافذة الملف الشخصي وتغيير كلمة المرور.
Future<void> showProfileSheet(BuildContext context) {
  final u = AppState.user.value!;
  final roleName = switch (u.role) {
    Role.admin => 'مدير النظام',
    Role.doctor => 'عضو هيئة تدريسية',
    Role.student => 'طالب',
  };
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: AppColors.mainGradient,
                  borderRadius: BorderRadius.circular(26),
                ),
                alignment: Alignment.center,
                child: Text(
                  u.name.isEmpty ? '?' : u.name.characters.first,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(u.name,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Center(child: Pill(roleName)),
            const SizedBox(height: 16),
            _row(Icons.badge_outlined, 'الرقم', u.id),
            _row(Icons.alternate_email, 'Google', u.email ?? 'غير مرتبط'),
            if (u.student != null) ...[
              _row(Icons.stairs_outlined, 'المرحلة',
                  stageName(u.student!.stage)),
              _row(Icons.wb_sunny_outlined, 'الدوام',
                  shiftName(u.student!.shift)),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(c);
                _changePassword(context);
              },
              icon: const Icon(Icons.password),
              label: const Text('تغيير كلمة المرور'),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _row(IconData i, String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(i, color: AppColors.royal, size: 20),
          const SizedBox(width: 10),
          Text('$k: ', style: const TextStyle(color: AppColors.muted)),
          Expanded(
            child: Text(v,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

Future<void> _changePassword(BuildContext context) async {
  final oldPw = TextEditingController();
  final newPw = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('تغيير كلمة المرور'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: oldPw,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'كلمة المرور الحالية')),
          const SizedBox(height: 10),
          TextField(
              controller: newPw,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'كلمة المرور الجديدة (6 أحرف فأكثر)')),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('إلغاء')),
        FilledButton(
            onPressed: () => Navigator.pop(c, true), child: const Text('حفظ')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  if (newPw.text.length < 6) {
    showSnack(context, 'كلمة المرور قصيرة', error: true);
    return;
  }
  await runBusy(context, () => repo.changePassword(oldPw.text, newPw.text),
      success: 'تم تغيير كلمة المرور');
}
