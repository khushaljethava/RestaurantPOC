import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/shift_repository.dart';
import 'stall.dart';

final shiftRepositoryProvider = Provider((ref) => ShiftRepository());

final openShiftProvider = FutureProvider.autoDispose<ShiftRow?>((ref) async {
  final stallId = ref.watch(activeStallIdProvider);
  if (stallId == null) return null;
  final r = await ref.watch(shiftRepositoryProvider).currentOpen(stallId);
  return r.valueOrNull;
});
