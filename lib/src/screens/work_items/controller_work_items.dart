part of work_items;

class _WorkItemsController with FilterMixin {
  factory _WorkItemsController({
    required AzureApiService apiService,
    required StorageService storageService,
    Project? project,
  }) {
    // handle page already in memory with a different project filter
    if (_instances[project.hashCode] != null) {
      return _instances[project.hashCode]!;
    }

    if (instance != null && project?.id != instance!.project?.id) {
      instance = _WorkItemsController._(apiService, storageService, project);
    }

    instance ??= _WorkItemsController._(apiService, storageService, project);
    return _instances.putIfAbsent(project.hashCode, () => instance!);
  }

  _WorkItemsController._(this.apiService, this.storageService, this.project) {
    projectFilter = project ?? projectAll;
  }

  static _WorkItemsController? instance;
  static final Map<int, _WorkItemsController> _instances = {};

  final AzureApiService apiService;
  final StorageService storageService;
  final Project? project;

  final workItems = ValueNotifier<ApiResponse<List<WorkItem>?>?>(null);

  late WorkItemState statusFilter = WorkItemState.all;
  WorkItemType typeFilter = WorkItemType.all;

  Map<String, List<WorkItemType>> allProjectsWorkItemTypes = {};
  late List<WorkItemType> allWorkItemTypes = [typeFilter];

  late List<WorkItemState> allWorkItemState = [statusFilter];

  void dispose() {
    instance = null;
    _instances.remove(project.hashCode);
  }

  Future<void> init() async {
    allWorkItemTypes = [typeFilter];
    allWorkItemState = [statusFilter];

    final types = await apiService.getWorkItemTypes();
    if (!types.isError) {
      allWorkItemTypes.addAll(types.data!.values.expand((ts) => ts).toSet());
      allProjectsWorkItemTypes = types.data!;

      final allStatesToAdd = <WorkItemState>{};

      for (final entry in apiService.workItemStates.values) {
        final states = entry.values.expand((v) => v);
        allStatesToAdd.addAll(states);
      }

      final sortedStates = allStatesToAdd.sorted((a, b) => a.name.compareTo(b.name));

      allWorkItemState.addAll(sortedStates);
    }

    await _getData();
  }

  Future<void> goToWorkItemDetail(WorkItem item) async {
    await AppRouter.goToWorkItemDetail(project: item.fields.systemTeamProject, id: item.id);
    await _getData();
  }

  void filterByProject(Project proj) {
    if (proj.id == projectFilter.id) return;

    workItems.value = null;
    projectFilter = proj.name == projectAll.name ? projectAll : proj;
    _getData();
  }

  void filterByStatus(WorkItemState state) {
    if (state == statusFilter) return;

    workItems.value = null;
    statusFilter = state;
    _getData();
  }

  void filterByType(WorkItemType type) {
    if (type.name == typeFilter.name) return;

    workItems.value = null;
    typeFilter = type;
    _getData();
  }

  void filterByUser(GraphUser user) {
    if (user.mailAddress == userFilter.mailAddress) return;

    workItems.value = null;
    userFilter = user;
    _getData();
  }

  Future<void> _getData() async {
    final res = await apiService.getWorkItems(
      project: projectFilter == projectAll ? null : projectFilter,
      type: typeFilter == WorkItemType.all ? null : typeFilter,
      status: statusFilter == WorkItemState.all ? null : statusFilter,
      assignedTo: userFilter == userAll ? null : userFilter,
    );
    workItems.value = res;
  }

  void resetFilters() {
    workItems.value = null;
    statusFilter = WorkItemState.all;
    typeFilter = WorkItemType.all;
    projectFilter = projectAll;
    userFilter = userAll;

    init();
  }

  // ignore: long-method
  Future<void> createWorkItem() async {
    var newWorkItemProject = getProjects(storageService).firstWhereOrNull((p) => p.id != '-1') ?? projectAll;

    var newWorkItemType = allWorkItemTypes.first;

    var newWorkItemAssignedTo = userAll;
    var newWorkItemTitle = '';
    var newWorkItemDescription = '';

    var projectWorkItemTypes = allWorkItemTypes;

    final titleFieldKey = GlobalKey<FormFieldState<dynamic>>();

    await OverlayService.bottomsheet(
      isScrollControlled: true,
      title: 'Create a new work item',
      builder: (context) => Container(
        height: context.height * .9,
        decoration: BoxDecoration(
          color: context.colorScheme.background,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
          child: Scaffold(
            body: Column(
              children: [
                Text(
                  'Create a new work item',
                  style: context.textTheme.titleLarge,
                ),
                Expanded(
                  child: ListView(
                    children: [
                      const SizedBox(
                        height: 20,
                      ),
                      StatefulBuilder(
                        builder: (_, setState) {
                          if (newWorkItemProject != projectAll) {
                            projectWorkItemTypes = allProjectsWorkItemTypes[newWorkItemProject.name]
                                    ?.where((t) => t != WorkItemType.all)
                                    .toList() ??
                                [];

                            if (!projectWorkItemTypes.contains(newWorkItemType)) {
                              newWorkItemType = projectWorkItemTypes.first;
                            }
                          }

                          final style = context.textTheme.bodySmall!.copyWith(height: 1, fontWeight: FontWeight.bold);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Project:',
                                    style: style,
                                  ),
                                  const SizedBox(
                                    width: 10,
                                  ),
                                  FilterMenu<Project>(
                                    title: 'Project',
                                    values: getProjects(storageService).where((p) => p != projectAll).toList(),
                                    currentFilter: newWorkItemProject,
                                    onSelected: (p) {
                                      setState(() => newWorkItemProject = p);
                                    },
                                    formatLabel: (p) => p.name!,
                                    isDefaultFilter: newWorkItemProject == projectAll,
                                    widgetBuilder: (p) => ProjectFilterWidget(project: p),
                                  ),
                                ],
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              Row(
                                children: [
                                  Text(
                                    'Type:',
                                    style: style,
                                  ),
                                  const SizedBox(
                                    width: 10,
                                  ),
                                  FilterMenu<WorkItemType>(
                                    title: 'Type',
                                    values: projectWorkItemTypes,
                                    currentFilter: newWorkItemType,
                                    formatLabel: (t) => t.name,
                                    onSelected: (f) {
                                      setState(() => newWorkItemType = f);
                                    },
                                    isDefaultFilter: newWorkItemType == WorkItemType.all,
                                    widgetBuilder: (t) => WorkItemTypeFilter(type: t),
                                  ),
                                ],
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              Row(
                                children: [
                                  Text(
                                    'Assigned to:',
                                    style: style,
                                  ),
                                  const SizedBox(
                                    width: 10,
                                  ),
                                  FilterMenu<GraphUser>(
                                    title: 'Assigned to',
                                    values: getSortedUsers(apiService)
                                        .whereNot((u) => u.displayName == userAll.displayName)
                                        .toList(),
                                    currentFilter: newWorkItemAssignedTo,
                                    onSelected: (u) {
                                      setState(() => newWorkItemAssignedTo = u);
                                    },
                                    formatLabel: (u) => u.displayName!,
                                    isDefaultFilter: newWorkItemAssignedTo.displayName == userAll.displayName,
                                    widgetBuilder: (u) => UserFilterWidget(user: u),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      DevOpsFormField(
                        onChanged: (value) => newWorkItemTitle = value,
                        label: 'Title',
                        formFieldKey: titleFieldKey,
                        textCapitalization: TextCapitalization.sentences,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      DevOpsFormField(
                        onChanged: (value) => newWorkItemDescription = value,
                        label: 'Description',
                        maxLines: 3,
                        onFieldSubmitted: AppRouter.popRoute,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(
                        height: 60,
                      ),
                      LoadingButton(
                        onPressed: () {
                          if (titleFieldKey.currentState!.validate()) {
                            AppRouter.popRoute();
                          }
                        },
                        text: 'Confirm',
                      ),
                      const SizedBox(
                        height: 40,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (newWorkItemProject == projectAll || newWorkItemType == WorkItemType.all || newWorkItemTitle.isEmpty) {
      return;
    }

    final res = await apiService.createWorkItem(
      projectName: newWorkItemProject.name!,
      type: newWorkItemType,
      title: newWorkItemTitle,
      assignedTo: newWorkItemAssignedTo.displayName == userAll.displayName ? null : newWorkItemAssignedTo,
      description: newWorkItemDescription,
    );

    if (res.isError) {
      return OverlayService.error('Error', description: 'Work item not created');
    }

    await init();
  }
}
