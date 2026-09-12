import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/models/transfer_history.dart';

final historyProvider = StateNotifierProvider<HistoryNotifier, List<TransferHistory>>((ref) {
  return HistoryNotifier();
});

class HistoryNotifier extends StateNotifier<List<TransferHistory>> {
  HistoryNotifier() : super([]) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    final history = await DatabaseHelper.instance.getAllTransferHistory();
    state = history;
  }
}
