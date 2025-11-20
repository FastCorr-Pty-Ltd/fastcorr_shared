import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/models/trial_model.dart';
import 'package:fastcorr_shared/services/trial_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:stacked/stacked.dart';

/// ViewModel for managing trial data within the shared case tab.
class CourtDatesViewModel extends ReactiveViewModel {
  final TrialService _trialService = TrialService();

  String? _litNumber;
  String? _orgId;
  String? _caseTitle;

  List<TrialModel> _trials = [];
  String? _errorMessage;
  bool _isLoading = false;
  StreamSubscription<List<TrialModel>>? _trialSubscription;

  TrialType? _typeFilter;
  TrialStatus? _statusFilter;

  // Sorting
  String _sortColumn = 'trialDate';
  bool _sortAscending = true;

  // Getters
  String? get litNumber => _litNumber;
  String? get orgId => _orgId;
  String? get caseTitle => _caseTitle;
  List<TrialModel> get trials => _getSortedTrials();
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  String get sortColumn => _sortColumn;
  bool get sortAscending => _sortAscending;
  bool get hasTrials => _trials.isNotEmpty;
  TrialType? get typeFilter => _typeFilter;
  TrialStatus? get statusFilter => _statusFilter;
  bool get hasActiveFilters => _typeFilter != null || _statusFilter != null;

  // Statistics
  int get totalCount => _getFilteredTrials().length;

  int get urgentCount => _getFilteredTrials().where(_isUrgent).length;

  int get upcomingCount => _getFilteredTrials()
      .where(
        (trial) =>
            !_isUrgent(trial) &&
            !_isCompleted(trial) &&
            !_isPast(trial) &&
            _daysUntil(trial) <= 30,
      )
      .length;

  int get completedCount => _getFilteredTrials().where(_isCompleted).length;

  /// Initialize the viewmodel with case metadata.
  Future<void> initialize({
    required String litNumber,
    String? orgId,
    String? caseTitle,
  }) async {
    _litNumber = litNumber;
    _orgId = orgId;
    _caseTitle = caseTitle;

    _setLoading(true);
    try {
      await _setupTrialStream();
    } catch (e) {
      _errorMessage = 'Failed to initialize trials: $e';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<TrialModel?> createTrial({
    required TrialModel trial,
    PlatformFile? counselBrief,
    String? counselNotes,
  }) async {
    try {
      setBusy(true);
      final created = await _trialService.createTrial(trial);
      if (created != null && counselBrief != null) {
        await _trialService.uploadCounselBrief(
          trialId: created.trialId,
          file: counselBrief,
          notes: counselNotes,
        );
      }
      return created;
    } catch (e) {
      _errorMessage = 'Failed to create trial: $e';
      notifyListeners();
      return null;
    } finally {
      setBusy(false);
    }
  }

  Future<bool> updateTrial({
    required TrialModel trial,
    PlatformFile? counselBrief,
    String? counselNotes,
  }) async {
    try {
      setBusy(true);
      final success = await _trialService.updateTrial(trial);
      if (success && counselBrief != null) {
        await _trialService.uploadCounselBrief(
          trialId: trial.trialId,
          file: counselBrief,
          notes: counselNotes,
        );
      }
      return success;
    } catch (e) {
      _errorMessage = 'Failed to update trial: $e';
      notifyListeners();
      return false;
    } finally {
      setBusy(false);
    }
  }

  Future<bool> deleteTrial(String trialId) async {
    try {
      setBusy(true);
      return await _trialService.deleteTrial(trialId);
    } catch (e) {
      _errorMessage = 'Failed to delete trial: $e';
      notifyListeners();
      return false;
    } finally {
      setBusy(false);
    }
  }

  Future<bool> removeCounselBrief(String trialId) async {
    try {
      setBusy(true);
      return await _trialService.clearCounselBrief(trialId);
    } catch (e) {
      _errorMessage = 'Failed to remove counsel brief: $e';
      notifyListeners();
      return false;
    } finally {
      setBusy(false);
    }
  }

  /// Check if a trial needs confirmation
  bool needsConfirmation(TrialModel trial) {
    return trial.status == TrialStatus.pendingConfirmation;
  }

  /// Confirm trial - handle ourselves (resolved by client)
  Future<bool> confirmTrialHandleOurselves(String trialId) async {
    try {
      setBusy(true);
      final success = await _trialService.patchTrial(
        trialId,
        status: TrialStatus.resolvedByClient,
      );
      return success;
    } catch (e) {
      _errorMessage = 'Failed to confirm trial: $e';
      notifyListeners();
      return false;
    } finally {
      setBusy(false);
    }
  }

  /// Update sorting column/direction.
  void updateSorting(String column) {
    if (_sortColumn == column) {
      _sortAscending = !_sortAscending;
    } else {
      _sortColumn = column;
      _sortAscending = true;
    }
    notifyListeners();
  }

  /// Clear error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void setTypeFilter(TrialType? type) {
    _typeFilter = type;
    notifyListeners();
  }

  void setStatusFilter(TrialStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void resetFilters() {
    _typeFilter = null;
    _statusFilter = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _trialSubscription?.cancel();
    super.dispose();
  }

  @override
  List<ReactiveServiceMixin> get reactiveServices => [];

  // Internal helpers --------------------------------------------------------

  Future<void> _setupTrialStream() async {
    if (_litNumber == null || _litNumber!.isEmpty) return;

    _trialSubscription?.cancel();
    _trialSubscription = _trialService
        .watchTrialsByLitNumber(_litNumber!)
        .listen(_onTrialsUpdated, onError: _onStreamError);
  }

  void _onTrialsUpdated(List<TrialModel> trials) {
    if (_orgId != null && _orgId!.isNotEmpty) {
      _trials = trials.where((trial) => trial.orgId == _orgId).toList();
    } else {
      _trials = trials;
    }
    notifyListeners();
  }

  void _onStreamError(Object error) {
    _errorMessage = 'Error loading trials: $error';
    notifyListeners();
  }

  List<TrialModel> _getSortedTrials() {
    final sorted = _getFilteredTrials();

    int compareByDate(TrialModel a, TrialModel b) {
      final dateCompare =
          _trialDate(a).compareTo(_trialDate(b)) * (_sortAscending ? 1 : -1);
      return dateCompare;
    }

    switch (_sortColumn) {
      case 'type':
        sorted.sort(
          (a, b) => _sortAscending
              ? a.type.name.compareTo(b.type.name)
              : b.type.name.compareTo(a.type.name),
        );
        break;
      case 'status':
        sorted.sort(
          (a, b) => _sortAscending
              ? a.status.name.compareTo(b.status.name)
              : b.status.name.compareTo(a.status.name),
        );
        break;
      case 'correspondent':
        sorted.sort(
          (a, b) => _sortAscending
              ? a.correspondentName.compareTo(b.correspondentName)
              : b.correspondentName.compareTo(a.correspondentName),
        );
        break;
      case 'court':
        sorted.sort(
          (a, b) => _sortAscending
              ? a.courtName.compareTo(b.courtName)
              : b.courtName.compareTo(a.courtName),
        );
        break;
      case 'trialDate':
      default:
        sorted.sort(compareByDate);
        break;
    }

    return sorted;
  }

  List<TrialModel> _getFilteredTrials() {
    return _trials.where((trial) {
      final matchesType = _typeFilter == null || trial.type == _typeFilter;
      final matchesStatus =
          _statusFilter == null || trial.status == _statusFilter;
      return matchesType && matchesStatus;
    }).toList();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  bool _isCompleted(TrialModel trial) =>
      trial.status == TrialStatus.settled ||
      trial.status == TrialStatus.proceeding;

  bool _isPast(TrialModel trial) => _trialDate(trial).isBefore(DateTime.now());

  bool _isUrgent(TrialModel trial) {
    final days = _daysUntil(trial);
    return !_isCompleted(trial) && days >= 0 && days <= 7;
  }

  int _daysUntil(TrialModel trial) =>
      _trialDate(trial).difference(DateTime.now()).inDays;

  DateTime _trialDate(TrialModel trial) {
    final dynamic raw = trial.trialDate;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.now();
  }
}
