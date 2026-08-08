import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/money.dart';
import '../../core/result.dart';
import '../../services/errors.dart';

class ShiftRow {
  ShiftRow({
    required this.id,
    required this.stallId,
    required this.staffId,
    required this.openingFloat,
    required this.openedAt,
    this.closedAt,
    this.declaredCash,
    this.expectedCash,
    this.variance,
    this.varianceReason,
  });

  final String id;
  final String stallId;
  final String staffId;
  final Money openingFloat;
  final DateTime openedAt;
  final DateTime? closedAt;
  final Money? declaredCash;
  final Money? expectedCash;
  final Money? variance;
  final String? varianceReason;

  bool get isOpen => closedAt == null;

  factory ShiftRow.fromJson(Map<String, dynamic> j) => ShiftRow(
        id: j['id'] as String,
        stallId: j['stall_id'] as String,
        staffId: j['staff_id'] as String,
        openingFloat: Money.fromRupees((j['opening_float'] as num?) ?? 0),
        openedAt: DateTime.parse(j['opened_at'] as String),
        closedAt: j['closed_at'] != null
            ? DateTime.parse(j['closed_at'] as String)
            : null,
        declaredCash: j['declared_cash'] != null
            ? Money.fromRupees(j['declared_cash'] as num)
            : null,
        expectedCash: j['expected_cash'] != null
            ? Money.fromRupees(j['expected_cash'] as num)
            : null,
        variance: j['variance'] != null
            ? Money.fromRupees(j['variance'] as num)
            : null,
        varianceReason: j['variance_reason'] as String?,
      );
}

class ShiftRepository {
  ShiftRepository([SupabaseClient? client])
      : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  Future<Result<ShiftRow?>> currentOpen(String stallId) async {
    try {
      final row = await _db
          .from('shifts')
          .select()
          .eq('stall_id', stallId)
          .eq('staff_id', _db.auth.currentUser!.id)
          .filter('closed_at', 'is', null)
          .maybeSingle();
      if (row == null) return const Ok(null);
      return Ok(ShiftRow.fromJson(Map<String, dynamic>.from(row)));
    } catch (e) {
      return Err(mapError(e));
    }
  }

  Future<Result<String>> open({
    required String stallId,
    required Money openingFloat,
    String deviceId = 'mobile',
  }) async {
    try {
      final id = await _db.rpc('open_shift', params: {
        'p_stall_id': stallId,
        'p_opening_float': openingFloat.rupees,
        'p_device_id': deviceId,
      });
      return Ok(id as String);
    } catch (e) {
      return Err(mapError(e));
    }
  }

  Future<Result<Money>> expectedCash(String shiftId) async {
    try {
      final v = await _db.rpc('shift_expected_cash', params: {
        'p_shift_id': shiftId,
      });
      return Ok(Money.fromRupees(v as num));
    } catch (e) {
      return Err(mapError(e));
    }
  }

  Future<Result<void>> addMovement({
    required String shiftId,
    required String kind,
    required Money amount,
    required String reason,
  }) async {
    try {
      await _db.rpc('add_cash_movement', params: {
        'p_shift_id': shiftId,
        'p_kind': kind,
        'p_amount': amount.rupees,
        'p_reason': reason,
      });
      return const Ok(null);
    } catch (e) {
      return Err(mapError(e));
    }
  }

  Future<Result<void>> close({
    required String shiftId,
    required Money declaredCash,
    String? varianceReason,
    String? notes,
  }) async {
    try {
      await _db.rpc('close_shift', params: {
        'p_shift_id': shiftId,
        'p_declared_cash': declaredCash.rupees,
        'p_variance_reason': varianceReason,
        'p_notes': notes,
      });
      return const Ok(null);
    } catch (e) {
      return Err(mapError(e));
    }
  }
}
