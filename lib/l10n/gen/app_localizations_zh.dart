// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'Tududa';

  @override
  String get areaAddTooltip => '新建区域';

  @override
  String get areaCancel => '取消';

  @override
  String get areaCreate => '创建';

  @override
  String get areaDeleteAction => '删除';

  @override
  String get areaDeleteMessage => '该区域内的项目将被取消关联。';

  @override
  String get areaDeleteTitle => '删除区域';

  @override
  String get areaDescription => '描述';

  @override
  String get areaDescriptionOptional => '描述（可选）';

  @override
  String get areaEdit => '编辑区域';

  @override
  String get areaEditAction => '编辑';

  @override
  String areaLoadError(String error) {
    return '错误：$error';
  }

  @override
  String get areaName => '名称';

  @override
  String get areaNameHint => '例如：工作、个人、健康';

  @override
  String get areaNew => '新建区域';

  @override
  String get areaSave => '保存';

  @override
  String get areasEmpty => '暂无区域';

  @override
  String get areasEmptyHint => '区域可帮助你整理项目';

  @override
  String get areasTitle => '区域管理';

  @override
  String get authCancel => '取消';

  @override
  String get authChangeServer => '更换服务器';

  @override
  String get authConnect => '连接';

  @override
  String get authConnectPrompt => '连接到您自托管的 Tududa 服务器';

  @override
  String get authConnecting => '连接中...';

  @override
  String get authEmail => '邮箱';

  @override
  String get authEmailRequired => '邮箱不能为空';

  @override
  String get authErrorEmailNotVerified => '您的邮箱尚未验证。请查看收件箱中的验证链接。';

  @override
  String get authErrorEnterServerUrl => '请输入服务器地址';

  @override
  String get authErrorGeneric => '出了点问题。';

  @override
  String get authErrorInsecure => '纯 HTTP 连接未加密。';

  @override
  String get authErrorInvalidCredentials => '邮箱或密码不正确。';

  @override
  String get authErrorInvalidServerUrl => '地址无效';

  @override
  String get authErrorNetwork => '无法连接到服务器。请检查网络连接和服务器地址。';

  @override
  String get authErrorPasswordLoginDisabled =>
      '此账户已禁用密码登录。它使用单点登录 (SSO)，本应用暂不支持。';

  @override
  String get authErrorRateLimited => '尝试次数过多，请稍后再试。';

  @override
  String authErrorRateLimitedMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes 分钟',
    );
    return '尝试次数过多，请在 $_temp0后重试。';
  }

  @override
  String authErrorServer(String code) {
    return '服务器出现问题（$code）。请稍后重试。';
  }

  @override
  String get authHidePassword => '隐藏密码';

  @override
  String get authInsecureBody =>
      '此地址未使用 HTTPS。您的密码和任务将以明文传输，可能在网络上被读取。请仅在可信网络中继续。';

  @override
  String get authInsecureConfirm => '使用不安全的 HTTP';

  @override
  String get authInsecureTitle => '使用不安全的 HTTP？';

  @override
  String get authInvalidEmail => '无效的邮箱';

  @override
  String get authPassword => '密码';

  @override
  String get authPasswordRequired => '密码不能为空';

  @override
  String get authServerUrl => '服务器地址';

  @override
  String get authServerUrlHelper => '请输入您的 Tududa 服务器地址';

  @override
  String get authServerUrlRequired => '请输入服务器地址';

  @override
  String get authShowPassword => '显示密码';

  @override
  String get authSignIn => '登录';

  @override
  String get authWelcome => '欢迎使用 Tududa';

  @override
  String get commonAdd => '添加';

  @override
  String get commonCancel => '取消';

  @override
  String get commonClose => '关闭';

  @override
  String get commonConfirm => '确认';

  @override
  String get commonDelete => '删除';

  @override
  String get commonEdit => '编辑';

  @override
  String get commonError => '出错了';

  @override
  String get commonLoading => '加载中…';

  @override
  String get commonNone => '无';

  @override
  String get commonRetry => '重试';

  @override
  String get commonSave => '保存';

  @override
  String get commonSearch => '搜索';

  @override
  String coreDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count天前',
    );
    return '$_temp0';
  }

  @override
  String coreInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count天后',
    );
    return '$_temp0';
  }

  @override
  String get coreToday => '今天';

  @override
  String get coreTomorrow => '明天';

  @override
  String get coreYesterday => '昨天';

  @override
  String get inboxEmpty => '收件箱为空';

  @override
  String get inboxIgnore => '忽略';

  @override
  String get inboxMarkProcessed => '标记为已处理';

  @override
  String get inboxTelegramHint => '来自 Telegram 的项目将显示在这里';

  @override
  String get kanbanNoTasks => '暂无任务\n点击 + 新建';

  @override
  String get kanbanStatusArchived => '已归档';

  @override
  String get kanbanStatusCancelled => '已取消';

  @override
  String get kanbanStatusDone => '已完成';

  @override
  String get kanbanStatusInProgress => '进行中';

  @override
  String get kanbanStatusOther => '其他';

  @override
  String get kanbanStatusPlanned => '已计划';

  @override
  String get kanbanStatusToDo => '待办';

  @override
  String get kanbanStatusWaiting => '等待中';

  @override
  String get navInbox => '收件箱';

  @override
  String get navMore => '更多';

  @override
  String get navNotes => '笔记';

  @override
  String get navProjects => '项目';

  @override
  String get navTasks => '任务';

  @override
  String get noteColor => '颜色';

  @override
  String get noteContentHint => '记下你的想法 (支持 Markdown)';

  @override
  String get noteDeleteConfirm => '确定要删除吗？';

  @override
  String get noteDeleteTitle => '删除笔记';

  @override
  String get noteEdit => '编辑笔记';

  @override
  String get noteEmpty => '暂无笔记\n点击 + 新建';

  @override
  String get noteNew => '新建笔记';

  @override
  String get noteProject => '项目';

  @override
  String get noteSaveFailed => '保存笔记失败';

  @override
  String get noteTitleHint => '笔记标题';

  @override
  String get projectAddTask => '添加任务';

  @override
  String get projectArea => '区域';

  @override
  String projectAreaLabel(String name) {
    return '区域：$name';
  }

  @override
  String get projectCancel => '取消';

  @override
  String get projectDelete => '删除';

  @override
  String get projectDeleteMessage => '这将删除该项目及其所有任务。';

  @override
  String get projectDeleteTitle => '删除项目';

  @override
  String get projectDescription => '描述';

  @override
  String get projectEdit => '编辑项目';

  @override
  String projectLoadError(String error) {
    return '错误：$error';
  }

  @override
  String get projectName => '项目名称';

  @override
  String get projectNameHint => '最多6个词';

  @override
  String get projectNameRequired => '名称不能为空';

  @override
  String get projectNew => '新建项目';

  @override
  String get projectNoArea => '无区域';

  @override
  String get projectNotFound => '未找到项目';

  @override
  String get projectPinSidebar => '固定到侧边栏';

  @override
  String get projectPinSidebarHint => '方便从导航快速访问';

  @override
  String get projectPriority => '优先级';

  @override
  String get projectPriorityHigh => '高';

  @override
  String get projectPriorityLow => '低';

  @override
  String get projectPriorityMedium => '中';

  @override
  String get projectPriorityNone => '无';

  @override
  String get projectRetry => '重试';

  @override
  String get projectSave => '保存';

  @override
  String projectSaveFailed(String error) {
    return '保存项目失败：$error';
  }

  @override
  String get projectStatus => '状态';

  @override
  String get projectStatusCancelled => '已取消';

  @override
  String get projectStatusDone => '已完成';

  @override
  String get projectStatusInProgress => '进行中';

  @override
  String get projectStatusNotStarted => '未开始';

  @override
  String get projectStatusPlanned => '已计划';

  @override
  String get projectStatusWaiting => '等待中';

  @override
  String projectTaskProgress(int done, int total) {
    return '$done/$total 个任务';
  }

  @override
  String get projectTasksHeading => '项目任务';

  @override
  String get projectViewBoard => '看板';

  @override
  String get projectViewList => '列表';

  @override
  String get projectsEmpty => '暂无项目\n点击 + 新建';

  @override
  String get projectsTitle => '项目';

  @override
  String get settingsAbout => '关于 Tududa';

  @override
  String get settingsAboutSubtitle => 'v1.0.1 • 开源';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsAreas => '区域管理';

  @override
  String get settingsAreasDesc => '将项目组织到不同区域';

  @override
  String get settingsCancel => '取消';

  @override
  String get settingsContrast => '对比度';

  @override
  String get settingsContrastHigh => '高';

  @override
  String get settingsContrastMedium => '中等';

  @override
  String get settingsContrastStandard => '标准';

  @override
  String get settingsDensity => '密度';

  @override
  String get settingsDensityComfortable => '舒适';

  @override
  String get settingsDensityCompact => '紧凑';

  @override
  String get settingsDynamicColor => '动态取色';

  @override
  String get settingsDynamicColorHint => '可用时使用壁纸配色';

  @override
  String get settingsIntegrations => '集成';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsLanguageSystem => '跟随系统';

  @override
  String get settingsMore => '更多';

  @override
  String get settingsNavigation => '导航';

  @override
  String get settingsPreferences => '首选项';

  @override
  String get settingsReduceMotion => '减少动效';

  @override
  String get settingsReduceMotionHint => '关闭过渡和动画';

  @override
  String get settingsServer => '服务器';

  @override
  String get settingsServerNotConfigured => '未配置';

  @override
  String get settingsServerUrl => '服务器地址';

  @override
  String get settingsSignOut => '退出登录';

  @override
  String get settingsSignOutConfirm => '确定要退出登录吗？';

  @override
  String settingsSignOutUnsynced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项更改',
    );
    return '$_temp0尚未同步，将会丢失。';
  }

  @override
  String get settingsTelegramConnected => '已连接';

  @override
  String get settingsTelegramNotConfigured => '未配置';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeSystem => '跟随系统';

  @override
  String get settingsTimezone => '时区';

  @override
  String get syncCancel => '取消';

  @override
  String get syncDiscard => '放弃';

  @override
  String get syncDiscardBody => '此更改将在本设备上撤销，且不会发送到服务器。';

  @override
  String get syncDiscardTitle => '放弃此更改？';

  @override
  String get syncDismiss => '忽略';

  @override
  String get syncEntryFailed => '失败，将重试';

  @override
  String syncEntryLine(String state, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次尝试',
    );
    return '$state - $_temp0';
  }

  @override
  String get syncEntryPending => '等待中';

  @override
  String get syncEntrySending => '发送中';

  @override
  String get syncEntryStuck => '已卡住';

  @override
  String syncLastSynced(String when) {
    return '上次同步：$when';
  }

  @override
  String syncLoadError(String error) {
    return '无法加载待同步的更改：$error';
  }

  @override
  String get syncNoConflicts => '没有需要查看的冲突。';

  @override
  String get syncNothingQueued => '没有待处理项。所有更改均已同步。';

  @override
  String syncNoticeLine(String entity, String what, String kept) {
    return '$entity：$what - $kept';
  }

  @override
  String get syncNoticeLocalKept => '保留您的版本';

  @override
  String get syncNoticeServerKept => '保留服务器版本';

  @override
  String get syncNoticeWholeChange => '更改';

  @override
  String get syncNow => '立即同步';

  @override
  String get syncPhaseError => '同步出现问题';

  @override
  String get syncPhaseIdle => '已是最新';

  @override
  String get syncPhaseOffline => '离线';

  @override
  String get syncPhaseSignedOut => '已退出登录';

  @override
  String get syncPhaseSyncing => '同步中';

  @override
  String get syncQueuedChanges => '待同步的更改';

  @override
  String get syncRecentConflicts => '最近的冲突';

  @override
  String get syncRetry => '重试';

  @override
  String get syncRetryAll => '全部重试';

  @override
  String get syncStatusAllSynced => '所有更改均已同步';

  @override
  String get syncStatusOfflineIdle => '离线，没有等待同步的内容';

  @override
  String syncStatusOfflineWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项更改',
    );
    return '离线，$_temp0等待同步';
  }

  @override
  String syncStatusProblem(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项更改',
    );
    return '同步出现问题，$_temp0失败';
  }

  @override
  String get syncStatusSignedOut => '已退出登录';

  @override
  String syncStatusSignedOutWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项更改',
    );
    return '已退出登录，$_temp0等待同步';
  }

  @override
  String get syncStatusSyncing => '同步中';

  @override
  String syncStatusWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项更改',
    );
    return '$_temp0等待同步';
  }

  @override
  String syncTimeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天',
    );
    return '$_temp0前';
  }

  @override
  String syncTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小时',
    );
    return '$_temp0前';
  }

  @override
  String get syncTimeJustNow => '刚刚';

  @override
  String syncTimeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分钟',
    );
    return '$_temp0前';
  }

  @override
  String get syncTimeNever => '从未';

  @override
  String get syncTitle => '同步';

  @override
  String get taskCancel => '取消';

  @override
  String get taskDelete => '删除';

  @override
  String get taskDetailCompleted => '已完成';

  @override
  String get taskDetailDeferUntil => '推迟至';

  @override
  String get taskDetailDeleteMessage => '确定要删除此任务吗？';

  @override
  String get taskDetailDeleteTitle => '删除任务';

  @override
  String get taskDetailDue => '截止';

  @override
  String get taskDetailEditTooltip => '编辑';

  @override
  String get taskDetailMarkComplete => '标记为已完成';

  @override
  String get taskDetailMarkIncomplete => '标记为未完成';

  @override
  String get taskDetailMenuTooltip => '更多操作';

  @override
  String taskDetailMetaLabel(String label) {
    return '$label：';
  }

  @override
  String get taskDetailProject => '项目';

  @override
  String get taskDetailSubtasks => '子任务';

  @override
  String get taskEmptyAll => '暂无任务\n点击 + 新建';

  @override
  String get taskEmptyCompleted => '还没有已完成的任务。';

  @override
  String get taskEmptyToday => '今天没有任务啦。\n好好享受空闲时光！🎉';

  @override
  String get taskErrorCancelled => '已取消';

  @override
  String get taskErrorCsrf => '安全校验失败，请重试。';

  @override
  String get taskErrorDecoding => '服务器返回了意外的响应';

  @override
  String get taskErrorEmailNotVerified => '邮箱地址未验证';

  @override
  String get taskErrorForbidden => '你没有执行此操作的权限';

  @override
  String get taskErrorGeneric => '出错了';

  @override
  String get taskErrorInvalidCredentials => '邮箱或密码无效';

  @override
  String get taskErrorNetwork => '无法连接到服务器';

  @override
  String get taskErrorNotFound => '未找到任务';

  @override
  String get taskErrorPasswordLoginDisabled => '密码登录已禁用';

  @override
  String get taskErrorRateLimited => '请求过于频繁，请稍后再试。';

  @override
  String taskErrorServer(int statusCode) {
    return '服务器错误（$statusCode）';
  }

  @override
  String get taskErrorTimeout => '服务器响应超时';

  @override
  String get taskErrorUnauthorized => '登录已过期，请重新登录。';

  @override
  String get taskFilterAll => '全部';

  @override
  String get taskFilterCompleted => '已完成';

  @override
  String get taskFilterSomeday => '某天';

  @override
  String get taskFilterToday => '今天';

  @override
  String get taskFilterUpcoming => '即将到来';

  @override
  String get taskFormClearTooltip => '清除';

  @override
  String get taskFormCompletionBased => '基于完成状态';

  @override
  String get taskFormCompletionBasedHint => '从上次完成时间开始循环';

  @override
  String get taskFormDeferUntil => '推迟至';

  @override
  String get taskFormDueDate => '截止日期';

  @override
  String get taskFormEvery => '每';

  @override
  String get taskFormNameHint => '有哪些需要做的事？';

  @override
  String get taskFormNameLabel => '任务名称';

  @override
  String get taskFormNameRequired => '名称不能为空';

  @override
  String get taskFormNone => '无';

  @override
  String get taskFormNotSet => '未设置';

  @override
  String get taskFormNoteHint => '添加详情 (支持 Markdown)';

  @override
  String get taskFormNoteLabel => '备注';

  @override
  String get taskFormPriority => '优先级';

  @override
  String get taskFormProject => '项目';

  @override
  String get taskFormProjectSelected => '已选择';

  @override
  String get taskFormRecurrence => '重复';

  @override
  String get taskFormSave => '保存';

  @override
  String get taskFormStatus => '状态';

  @override
  String get taskFormTitleEdit => '编辑任务';

  @override
  String get taskFormTitleNew => '新建任务';

  @override
  String taskFormUnitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '天',
    );
    return '$_temp0';
  }

  @override
  String taskFormUnitMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '个月',
    );
    return '$_temp0';
  }

  @override
  String taskFormUnitWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '周',
    );
    return '$_temp0';
  }

  @override
  String get taskListTitle => '任务';

  @override
  String get taskNewButton => '新建任务';

  @override
  String get taskPriorityHigh => '高';

  @override
  String get taskPriorityLow => '低';

  @override
  String get taskPriorityMedium => '中';

  @override
  String get taskRecurDaily => '每天';

  @override
  String taskRecurEveryDays(int count) {
    return '每 $count 天';
  }

  @override
  String taskRecurEveryMonths(int count) {
    return '每 $count 个月';
  }

  @override
  String taskRecurEveryWeeks(int count) {
    return '每 $count 周';
  }

  @override
  String get taskRecurMonthly => '每月';

  @override
  String get taskRecurMonthlyLastDay => '每月（最后一天）';

  @override
  String get taskRecurMonthlyWeekday => '每月（按星期）';

  @override
  String get taskRecurWeekly => '每周';

  @override
  String get taskRetry => '重试';

  @override
  String get taskSortCreated => '创建日期';

  @override
  String get taskSortDueDate => '截止日期';

  @override
  String get taskSortName => '名称';

  @override
  String get taskSortPriority => '优先级';

  @override
  String get taskSortTooltip => '排序';

  @override
  String get taskStatusArchived => '已归档';

  @override
  String get taskStatusCancelled => '已取消';

  @override
  String get taskStatusDone => '已完成';

  @override
  String get taskStatusInProgress => '进行中';

  @override
  String get taskStatusNotStarted => '未开始';

  @override
  String get taskStatusPlanned => '已计划';

  @override
  String get taskStatusUnknown => '未知';

  @override
  String get taskStatusWaiting => '等待中';

  @override
  String get taskViewBoard => '看板';

  @override
  String get taskViewList => '列表';
}
