import 'dart:async';
import 'package:fastcorr_shared/services/services.dart';
import 'package:stacked/stacked.dart';

import '../../models/court_date_model.dart';

/// ViewModel for managing court dates functionality
class CourtDatesViewModel extends ReactiveViewModel {
  final CourtDateService _courtDateService = CourtDateService();
  String? _caseId;
  String? _orgId;
  String? _caseTitle;

  List<CourtDateModel> _courtDates = [];
  String? _errorMessage;
  bool _isLoading = false;
  StreamSubscription<List<CourtDateModel>>? _courtDatesSubscription;

  // Sorting
  String _sortColumn = 'courtDate';
  bool _sortAscending = true;

  // Getters
  String? get caseId => _caseId;
  String? get orgId => _orgId;
  String? get caseTitle => _caseTitle;
  List<CourtDateModel> get courtDates => _getSortedCourtDates();
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  String get sortColumn => _sortColumn;
  bool get sortAscending => _sortAscending;

  // Statistics
  int get totalCount => _courtDates.length;
  int get urgentCount => _courtDates.where((date) => date.isUrgent).length;
  int get upcomingCount =>
      _courtDates.where((date) => date.isUpcoming && !date.isUrgent).length;
  int get completedCount => _courtDates
      .where((date) => date.status == CourtDateStatus.completed)
      .length;

  /// Get sorted court dates based on current sort settings
  List<CourtDateModel> _getSortedCourtDates() {
    final sorted = List<CourtDateModel>.from(_courtDates);

    // Default sorting: urgent first, then by date
    if (_sortColumn == 'courtDate') {
      sorted.sort((a, b) {
        if (a.isUrgent && !b.isUrgent) return -1;
        if (!a.isUrgent && b.isUrgent) return 1;
        return _sortAscending
            ? a.courtDate.compareTo(b.courtDate)
            : b.courtDate.compareTo(a.courtDate);
      });
    } else if (_sortColumn == 'description') {
      sorted.sort(
        (a, b) => _sortAscending
            ? a.description.compareTo(b.description)
            : b.description.compareTo(a.description),
      );
    } else if (_sortColumn == 'dateType') {
      sorted.sort(
        (a, b) => _sortAscending
            ? a.dateType.name.compareTo(b.dateType.name)
            : b.dateType.name.compareTo(a.dateType.name),
      );
    } else if (_sortColumn == 'status') {
      sorted.sort(
        (a, b) => _sortAscending
            ? a.status.name.compareTo(b.status.name)
            : b.status.name.compareTo(a.status.name),
      );
    }

    return sorted;
  }

  /// Update sorting
  void updateSorting(String column) {
    if (_sortColumn == column) {
      _sortAscending = !_sortAscending;
    } else {
      _sortColumn = column;
      _sortAscending = true;
    }
    notifyListeners();
  }

  /// Initialize the viewmodel with a case ID and organization ID
  Future<void> initialize({
    required String caseId,
    required String orgId,
    String? caseTitle,
  }) async {
    _caseId = caseId;
    _orgId = orgId;
    _caseTitle = caseTitle;

    setBusy(true);
    try {
      await _setupCourtDatesStream();
    } catch (e) {
      _errorMessage = 'Failed to initialize court dates: $e';
    } finally {
      setBusy(false);
    }
  }

  /// Set up real-time stream for court dates
  Future<void> _setupCourtDatesStream() async {
    if (_caseId == null || _orgId == null) return;

    _courtDatesSubscription?.cancel();

    _courtDatesSubscription = _courtDateService
        .getCourtDatesStreamForCase(caseId: _caseId!)
        .listen(
          (courtDates) {
            _courtDates = courtDates;
            notifyListeners();
          },
          onError: (error) {
            _errorMessage = 'Error loading court dates: $error';
            notifyListeners();
          },
        );
  }

  /// Add a new court date
  Future<CourtDateModel?> addCourtDate({
    required String description,
    required DateTime courtDate,
    required CourtDateType dateType,
    String? notes,
    String? createdBy,
  }) async {
    if (_caseId == null || _orgId == null) return null;

    try {
      setBusy(true);

      // Check for conflicts
      final conflicts = await _courtDateService.checkCourtDateConflicts(
        caseId: _caseId!,
        courtDate: courtDate,
      );

      if (conflicts.isNotEmpty) {
        _errorMessage =
            'Court date conflicts with existing dates. Please choose a different time.';
        setBusy(false);
        notifyListeners();
        return null;
      }

      final courtDateModel = await _courtDateService.addCourtDate(
        orgId: _orgId!,
        caseId: _caseId!,
        caseTitle: _caseTitle ?? 'Unknown Case',
        description: description,
        courtDate: courtDate,
        dateType: dateType,
        notes: notes,
        createdBy: createdBy ?? 'Unknown',
      );

      // Stream will automatically update the UI
      return courtDateModel;
    } catch (e) {
      _errorMessage = 'Failed to add court date: $e';
      setBusy(false);
      notifyListeners();
      return null;
    }
  }

  /// Update an existing court date
  Future<CourtDateModel?> updateCourtDate({
    required String dateId,
    required String description,
    required DateTime courtDate,
    required CourtDateType dateType,
    String? notes,
    String? updatedBy,
  }) async {
    if (_orgId == null) return null;

    try {
      setBusy(true);

      // Check for conflicts (excluding current date)
      final conflicts = await _courtDateService.checkCourtDateConflicts(
        caseId: _caseId!,
        courtDate: courtDate,
        excludeDateId: dateId,
      );

      if (conflicts.isNotEmpty) {
        _errorMessage =
            'Court date conflicts with existing dates. Please choose a different time.';
        setBusy(false);
        notifyListeners();
        return null;
      }

      final courtDateModel = await _courtDateService.updateCourtDate(
        caseId: _caseId!,
        dateId: dateId,
        description: description,
        courtDate: courtDate,
        dateType: dateType,
        notes: notes,
        updatedBy: updatedBy ?? 'Unknown',
      );

      // Stream will automatically update the UI
      return courtDateModel;
    } catch (e) {
      _errorMessage = 'Failed to update court date: $e';
      setBusy(false);
      notifyListeners();
      return null;
    }
  }

  /// Delete a court date
  Future<bool> deleteCourtDate(String dateId) async {
    if (_orgId == null) return false;

    try {
      setBusy(true);

      final success = await _courtDateService.deleteCourtDate(
        caseId: _caseId!,
        dateId: dateId,
      );

      // Stream will automatically update the UI
      return success;
    } catch (e) {
      _errorMessage = 'Failed to delete court date: $e';
      setBusy(false);
      notifyListeners();
      return false;
    }
  }

  /// Update court date status
  Future<CourtDateModel?> updateCourtDateStatus(
    String dateId,
    CourtDateStatus status,
  ) async {
    if (_orgId == null) return null;

    try {
      setBusy(true);

      final courtDateModel = await _courtDateService.updateCourtDate(
        caseId: _caseId!,
        dateId: dateId,
        status: status,
        updatedBy: 'System',
      );

      // Stream will automatically update the UI
      return courtDateModel;
    } catch (e) {
      _errorMessage = 'Failed to update court date status: $e';
      setBusy(false);
      notifyListeners();
      return null;
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _courtDatesSubscription?.cancel();
    super.dispose();
  }

  @override
  List<ReactiveServiceMixin> get reactiveServices => [];
}
