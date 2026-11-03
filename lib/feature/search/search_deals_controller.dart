import 'dart:async';

import 'package:get/get.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class SearchDealsController extends GetxController {
  final DealRepo dealRepo;

  SearchDealsController({required this.dealRepo});

  final results = <DealModel>[].obs;
  final isLoading = false.obs;
  final hasSearched = false.obs;

  Timer? _debounceTimer;
  int _searchVersion = 0;

  void onQueryChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      _searchVersion++;
      results.clear();
      hasSearched.value = false;
      isLoading.value = false;
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _search(trimmed);
    });
  }

  Future<void> _search(String query) async {
    final version = ++_searchVersion;
    isLoading.value = true;
    hasSearched.value = true;

    try {
      final found = await dealRepo.search(query);
      if (version == _searchVersion) {
        results.assignAll(found);
      }
    } catch (e) {
      if (version == _searchVersion) {
        LogService.error('search failed', e);
      }
    } finally {
      if (version == _searchVersion) {
        isLoading.value = false;
      }
    }
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    super.onClose();
  }
}
