import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/models/trial_model.dart';
import 'package:fastcorr_shared/services/trial_service.dart';
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

  // Statistics
  int get totalCount => _trials.length;

  int get urgentCount => _trials.where(_isUrgent).length;

  int get upcomingCount => _trials
      .where(
        (trial) =>
            !_isUrgent(trial) &&
            !_isCompleted(trial) &&
            !_isPast(trial) &&
            _daysUntil(trial) <= 30,
      )
      .length;

  int get completedCount => _trials.where(_isCompleted).length;

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
    final sorted = List<TrialModel>.from(_trials);

    int compareByDate(TrialModel a, TrialModel b) {
      final dateCompare =
          _trialDate(a).compareTo(_trialDate(b)) * (_sortAscending ? 1 : -1);
      return dateCompare;
    }

    switch (_sortColumn) {
      case 'type':
        sorted.sort((a, b) => _sortAscending
            ? a.type.name.compareTo(b.type.name)
            : b.type.name.compareTo(a.type.name));
        break;
      case 'status':
        sorted.sort((a, b) => _sortAscending
            ? a.status.name.compareTo(b.status.name)
            : b.status.name.compareTo(a.status.name));
        break;
      case 'correspondent':
        sorted.sort((a, b) => _sortAscending
            ? a.correspondentName.compareTo(b.correspondentName)
            : b.correspondentName.compareTo(a.correspondentName));
        break;
      case 'court':
        sorted.sort((a, b) => _sortAscending
            ? a.courtName.compareTo(b.courtName)
            : b.courtName.compareTo(a.courtName));
        break;
      case 'trialDate':
      default:
        sorted.sort(compareByDate);
        break;
    }

    return sorted;
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
