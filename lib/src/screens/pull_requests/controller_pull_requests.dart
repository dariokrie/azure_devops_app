part of pull_requests;

class _PullRequestsController with FilterMixin {
  factory _PullRequestsController({
    required AzureApiService apiService,
    required StorageService storageService,
    Project? project,
  }) {
    // handle page already in memory with a different project filter
    if (_instances[project.hashCode] != null) {
      return _instances[project.hashCode]!;
    }

    if (instance != null && project?.id != instance!.project?.id) {
      instance = _PullRequestsController._(apiService, storageService, project);
    }

    instance ??= _PullRequestsController._(apiService, storageService, project);
    return _instances.putIfAbsent(project.hashCode, () => instance!);
  }

  _PullRequestsController._(this.apiService, this.storageService, this.project) {
    projectFilter = project ?? projectAll;
  }

  static _PullRequestsController? instance;
  static final Map<int, _PullRequestsController> _instances = {};

  final AzureApiService apiService;
  final StorageService storageService;
  final Project? project;

  final pullRequests = ValueNotifier<ApiResponse<List<PullRequest>?>?>(null);
  List<PullRequest> allPullRequests = [];

  PullRequestState statusFilter = PullRequestState.all;

  late GraphUser reviewerFilter = userAll;

  final isSearching = ValueNotifier<bool>(false);
  String? _currentSearchQuery;

  void dispose() {
    instance = null;
    _instances.remove(project.hashCode);
  }

  Future<void> init() async {
    await _getData();
  }

  Future<void> goToPullRequestDetail(PullRequest pr) async {
    await AppRouter.goToPullRequestDetail(
      project: pr.repository.project.name,
      repository: pr.repository.id,
      id: pr.pullRequestId,
    );
    await init();
  }

  void filterByStatus(PullRequestState state) {
    if (state == statusFilter) return;

    pullRequests.value = null;
    statusFilter = state;
    _getData();
  }

  void filterByUser(GraphUser u) {
    if (u.mailAddress == userFilter.mailAddress) return;

    pullRequests.value = null;
    userFilter = u;
    _getData();
  }

  void filterByReviewer(GraphUser u) {
    if (u.mailAddress == reviewerFilter.mailAddress) return;

    pullRequests.value = null;
    reviewerFilter = u;
    _getData();
  }

  void filterByProject(Project proj) {
    if (proj.id == projectFilter.id) return;

    pullRequests.value = null;
    projectFilter = proj.name! == projectAll.name ? projectAll : proj;
    _getData();
  }

  Future<void> _getData() async {
    final res = await apiService.getPullRequests(
      filter: statusFilter,
      creator: userFilter.displayName == userAll.displayName ? null : userFilter,
      project: projectFilter.name == projectAll.name ? null : projectFilter,
      reviewer: reviewerFilter.displayName == userAll.displayName ? null : reviewerFilter,
    );

    pullRequests.value = res..data?.sort((a, b) => (b.creationDate).compareTo(a.creationDate));
    allPullRequests = pullRequests.value?.data ?? [];

    if (_currentSearchQuery != null) {
      searchPullRequests(_currentSearchQuery!);
    }
  }

  void resetFilters() {
    pullRequests.value = null;
    projectFilter = projectAll;
    statusFilter = PullRequestState.all;
    userFilter = userAll;
    reviewerFilter = userAll;

    init();
  }

  void searchPullRequests(String query) {
    _currentSearchQuery = query.trim().toLowerCase();

    final matchedItems = allPullRequests
        .where(
          (i) =>
              i.pullRequestId.toString().contains(_currentSearchQuery!) ||
              i.title.toLowerCase().contains(_currentSearchQuery!),
        )
        .toList();

    pullRequests.value = pullRequests.value?.copyWith(data: matchedItems);
  }

  void resetSearch() {
    searchPullRequests('');
    isSearching.value = false;
  }
}
