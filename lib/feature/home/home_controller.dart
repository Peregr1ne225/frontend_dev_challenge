import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../model/deal_model.dart';
import '../../repository/deal_repo.dart';
import '../../util/log_service.dart';

class HomeController extends GetxController {
  final DealRepo dealRepo;

  HomeController({required this.dealRepo});

  final deals = <DealModel>[].obs;
  final flashDeals = <DealModel>[].obs;
  final isLoading = true.obs;
  final todayOnly = false.obs;
  final isScrolled = false.obs;
  final showScrollToTop = false.obs;

  final scrollController = ScrollController();
  final refreshController = RefreshController();

  int _page = 1;
  int _totalPages = 1;
  bool _isFetchingMore = false;
  int _feedVersion = 0;

  bool get hasMore => _page < _totalPages;

  List<DealModel> get visibleDeals => todayOnly.value
      ? deals.where((d) => d.pickupWindow.isToday).toList()
      : deals.toList();

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    _initialLoad();
  }

  void _onScroll() {
    final offset = scrollController.offset;
    final scrolled = offset > 4;
    final shouldShowScrollToTop = offset > 800;

    if (isScrolled.value != scrolled) isScrolled.value = scrolled;
    if (showScrollToTop.value != shouldShowScrollToTop) {
      showScrollToTop.value = shouldShowScrollToTop;
    }
  }

  Future<void> _initialLoad() async {
    isLoading.value = true;
    try {
      await Future.wait([refreshDeals(), _loadFlashDeals()]);
    } catch (e) {
      LogService.error('initial load failed', e);
    }
    isLoading.value = false;
  }

  Future<void> _loadFlashDeals() async {
    flashDeals.assignAll(await dealRepo.fetchFlashDeals());
  }

  Future<void> refreshDeals() async {
    final version = ++_feedVersion;
    _page = 1;
    _isFetchingMore = false;
    try {
      final res = await dealRepo.fetchDeals(page: 1);
      if (version != _feedVersion) return;
      _totalPages = res.totalPages;
      deals.assignAll(res.items);
      refreshController.refreshCompleted();
    } catch (e) {
      if (version == _feedVersion) {
        LogService.error('refresh deals failed', e);
        refreshController.refreshFailed();
      }
    }
  }

  Future<void> loadMore() async {
    if (_isFetchingMore) return;
    if (!hasMore) {
      refreshController.loadNoData();
      return;
    }
    _isFetchingMore = true;
    final version = _feedVersion;
    final requestedPage = _page + 1;
    try {
      final res = await dealRepo.fetchDeals(page: requestedPage);
      if (version != _feedVersion) return;
      _totalPages = res.totalPages;
      _page = requestedPage;
      final existingIds = deals.map((deal) => deal.id).toSet();
      deals.addAll(res.items.where((deal) => existingIds.add(deal.id)));
    } catch (e) {
      LogService.error('loadMore failed', e);
    } finally {
      if (version == _feedVersion) {
        _isFetchingMore = false;
        refreshController.loadComplete();
      }
    }
  }

  void scrollToTop() {
    scrollController.animateTo(0,
        duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
  }

  @override
  void onClose() {
    scrollController.dispose();
    refreshController.dispose();
    super.onClose();
  }
}
