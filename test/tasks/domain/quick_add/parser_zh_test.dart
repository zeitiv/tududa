import 'package:flutter_test/flutter_test.dart';
import 'package:tududa/core/time/calendar_date.dart';
import 'package:tududa/tasks/domain/quick_add/quick_add_parser.dart';
import 'package:tududa/tasks/domain/quick_add/grammar_zh.dart' show zhNum;

import 'parse_check.dart';

QuickAddParser mon() => QuickAddParser(today: today, language: 'zh');
QuickAddParser sun() =>
    QuickAddParser(today: today, language: 'zh', weekStart: 7);

CalendarDate d(String s) => CalendarDate.parse(s);

void main() {
  test('zhNum', () {
    expect(zhNum('三'), 3);
    expect(zhNum('两'), 2);
    expect(zhNum('十'), 10);
    expect(zhNum('十五'), 15);
    expect(zhNum('二十三'), 23);
    expect(zhNum('二十'), 20);
    expect(zhNum('12'), 12);
    expect(zhNum('十十'), isNull);
    expect(zhNum('三三'), isNull);
    expect(zhNum(''), isNull);
  });

  runRows('zh dates (week starts Monday)', mon, [
    PC(
      '今天交报告',
      title: '交报告',
      due: '2026-10-14',
      spans: [(TokenKind.date, 0, 2)],
    ),
    PC('交报告今天', title: '交报告', due: '2026-10-14'),
    PC(
      '提醒我明天开会',
      title: '提醒我开会',
      due: '2026-10-15',
      spans: [(TokenKind.date, 3, 5)],
    ),
    PC('今晚吃饭', title: '吃饭', due: '2026-10-14', time: '19:00'),
    PC('明晚聚餐', title: '聚餐', due: '2026-10-15', time: '19:00'),
    PC('明早跑步', title: '跑步', due: '2026-10-15', time: '09:00'),
    PC('后天开会', title: '开会', due: '2026-10-16'),
    PC('大后天开会', title: '开会', due: '2026-10-17'),
    PC('昨天开会', title: '开会', due: '2026-10-13'),
    PC('前天开会', title: '开会', due: '2026-10-12'),
    PC('周一开会', title: '开会', due: '2026-10-19'),
    PC('星期一开会', title: '开会', due: '2026-10-19'),
    PC('礼拜一开会', title: '开会', due: '2026-10-19'),
    PC('周三开会', title: '开会', due: '2026-10-21'),
    PC('周五开会', title: '开会', due: '2026-10-16'),
    PC('周六开会', title: '开会', due: '2026-10-17'),
    PC('周日开会', title: '开会', due: '2026-10-18'),
    PC('星期天开会', title: '开会', due: '2026-10-18'),
    PC('下周一开会', title: '开会', due: '2026-10-19'),
    PC('下星期一开会', title: '开会', due: '2026-10-19'),
    PC('下个周五开会', title: '开会', due: '2026-10-23'),
    PC('下周日开会', title: '开会', due: '2026-10-25'),
    PC('这周五开会', title: '开会', due: '2026-10-16'),
    PC('本周五开会', title: '开会', due: '2026-10-16'),
    PC('这周一开会', title: '开会', due: '2026-10-19'),
    PC('上周五开会', title: '开会', due: '2026-10-09'),
    PC('下周开会', title: '开会', due: '2026-10-19'),
    PC('周末爬山', title: '爬山', due: '2026-10-17'),
    PC('这周末爬山', title: '爬山', due: '2026-10-17'),
    PC('下周末爬山', title: '爬山', due: '2026-10-24'),
    PC('下个月开会', title: '开会', due: '2026-11-14'),
    PC('下月开会', title: '开会', due: '2026-11-14'),
    PC('下个月5号开会', title: '开会', due: '2026-11-05'),
    PC('3天后开会', title: '开会', due: '2026-10-17'),
    PC('三天后开会', title: '开会', due: '2026-10-17'),
    PC('2周后开会', title: '开会', due: '2026-10-28'),
    PC('两周后开会', title: '开会', due: '2026-10-28'),
    PC('2个星期后开会', title: '开会', due: '2026-10-28'),
    PC('1个月后开会', title: '开会', due: '2026-11-14'),
    PC('一个月后开会', title: '开会', due: '2026-11-14'),
    PC('1月5日开会', title: '开会', due: '2027-01-05'),
    PC('1月5号开会', title: '开会', due: '2027-01-05'),
    PC('十一月五日开会', title: '开会', due: '2026-11-05'),
    PC('12月25日开会', title: '开会', due: '2026-12-25'),
    PC('2026年11月3日开会', title: '开会', due: '2026-11-03'),
    PC('2月30日开会', title: '2月30日开会'),
    PC('5号交租', title: '交租', due: '2026-11-05'),
    PC('15号交租', title: '交租', due: '2026-10-15'),
    PC('14号交租', title: '交租', due: '2026-10-14'),
    PC('13号交租', title: '交租', due: '2026-11-13'),
    PC('二十三号交租', title: '交租', due: '2026-10-23'),
    PC('交租 2026-11-03', title: '交租', due: '2026-11-03'),
    PC('明天 开会', title: '开会', due: '2026-10-15'),
    PC('周一次数', title: '周一次数'),
    PC('每周一次吃药', title: '每周一次吃药'),
  ]);

  runRows('zh dates (week starts Sunday)', sun, [
    PC('下周一开会', title: '开会', due: '2026-10-19'),
    PC('下周日开会', title: '开会', due: '2026-10-18'),
    PC('下周开会', title: '开会', due: '2026-10-18'),
    PC('这周日开会', title: '开会', due: '2026-10-18'),
    PC('这周五开会', title: '开会', due: '2026-10-16'),
  ]);

  runRows('zh times', mon, [
    PC('下午3点开会', title: '开会', time: '15:00', spans: [(TokenKind.time, 0, 4)]),
    PC('下午3点半开会', title: '开会', time: '15:30'),
    PC('晚上8点开会', title: '开会', time: '20:00'),
    PC('早上9点开会', title: '开会', time: '09:00'),
    PC('中午12点吃饭', title: '吃饭', time: '12:00'),
    PC('中午1点吃饭', title: '吃饭', time: '13:00'),
    PC('3点开会', title: '开会', time: '03:00'),
    PC('十点开会', title: '开会', time: '10:00'),
    PC('下午三点开会', title: '开会', time: '15:00'),
    PC('15:00开会', title: '开会', time: '15:00'),
    PC('下午3:30开会', title: '开会', time: '15:30'),
    PC('下午3点15分开会', title: '开会', time: '15:15'),
    PC('下午3点一刻开会', title: '开会', time: '15:15'),
    PC('凌晨1点起床', title: '起床', time: '01:00'),
    PC('晚上12点睡觉', title: '睡觉', time: '00:00'),
    PC('上午10点开会', title: '开会', time: '10:00'),
    PC('25点开会', title: '25点开会'),
    PC(
      '明天下午3点开会',
      title: '开会',
      due: '2026-10-15',
      time: '15:00',
      spans: [(TokenKind.date, 0, 2), (TokenKind.time, 2, 6)],
    ),
    PC('明天早上开会', title: '开会', due: '2026-10-15', time: '09:00'),
    PC('明天晚上开会', title: '开会', due: '2026-10-15', time: '19:00'),
    PC('明天中午吃饭', title: '吃饭', due: '2026-10-15', time: '12:00'),
    PC('今天下午吃饭', title: '吃饭', due: '2026-10-14', time: '14:00'),
    PC('周一下午3点开会', title: '开会', due: '2026-10-19', time: '15:00'),
    PC('明天 下午3点 开会', title: '开会', due: '2026-10-15', time: '15:00'),
    PC('开会下午', title: '开会下午'),
    PC('开会 早上', title: '开会 早上'),
    PC('call tomorrow 3pm', title: 'call', due: '2026-10-15', time: '15:00'),
    PC('下午3点, 开会。', title: '开会。', time: '15:00'),
  ]);

  runRows(
    'zh syntax tokens',
    () => QuickAddParser(
      today: today,
      language: 'zh',
      knownProjects: ['家庭装修', '家庭'],
      knownAreas: ['工作'],
    ),
    [
      PC('买牛奶 #购物', title: '买牛奶', tags: ['购物']),
      PC('买牛奶#购物', title: '买牛奶#购物'),
      PC('买牛奶 +家庭装修 明天', title: '买牛奶', project: '家庭装修', due: '2026-10-15'),
      PC('买牛奶 +家庭', title: '买牛奶', project: '家庭'),
      PC('买牛奶 +"家庭 项目"', title: '买牛奶', project: '家庭 项目'),
      PC('买牛奶 ~工作', title: '买牛奶', area: '工作'),
      PC('买牛奶 !!', title: '买牛奶', priority: QuickPriority.medium),
      PC('买牛奶 !high', title: '买牛奶', priority: QuickPriority.high),
      PC('提醒 @小王 明天', title: '提醒 @小王', due: '2026-10-15'),
      PC('', title: ''),
      PC('明天', title: '明天'),
    ],
  );

  runRows('zh recurrence grammar', mon, [
    PC(
      '每天吃药',
      title: '吃药',
      rec: daily(),
      due: '2026-10-14',
      impliedDue: true,
      spans: [(TokenKind.recurrence, 0, 2)],
    ),
    PC('吃药每天', title: '吃药', rec: daily(), due: '2026-10-14', impliedDue: true),
    PC('每日打卡', title: '打卡', rec: daily(), due: '2026-10-14', impliedDue: true),
    PC(
      '每3天浇花',
      title: '浇花',
      rec: daily(3),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      '每两天浇花',
      title: '浇花',
      rec: daily(2),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      '每隔一天浇花',
      title: '浇花',
      rec: daily(2),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      '每个工作日打卡',
      title: '打卡',
      rec: weekly({1, 2, 3, 4, 5}),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      '工作日打卡',
      title: '打卡',
      rec: weekly({1, 2, 3, 4, 5}),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      '每周一开会',
      title: '开会',
      rec: weekly({1}),
      due: '2026-10-19',
      impliedDue: true,
    ),
    PC(
      '每周一三五健身',
      title: '健身',
      rec: weekly({1, 3, 5}),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      '每星期三健身',
      title: '健身',
      rec: weekly({3}),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      '每礼拜五健身',
      title: '健身',
      rec: weekly({5}),
      due: '2026-10-16',
      impliedDue: true,
    ),
    PC(
      '每周日健身',
      title: '健身',
      rec: weekly({7}),
      due: '2026-10-18',
      impliedDue: true,
    ),
    PC(
      '每周末爬山',
      title: '爬山',
      rec: weekly({6, 7}),
      due: '2026-10-17',
      impliedDue: true,
    ),
    PC(
      '每2周复盘',
      title: '复盘',
      rec: weekly({}, 2),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      '每两周复盘',
      title: '复盘',
      rec: weekly({}, 2),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      '每周复盘',
      title: '复盘',
      rec: weekly({}),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      '每隔一周复盘',
      title: '复盘',
      rec: weekly({}, 2),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      '每月付款',
      title: '付款',
      rec: monthly(),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      '每个月付款',
      title: '付款',
      rec: monthly(),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      '每3个月付款',
      title: '付款',
      rec: monthly(interval: 3),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      '每月15号付款',
      title: '付款',
      rec: monthly(day: 15),
      due: '2026-10-15',
      impliedDue: true,
    ),
    PC(
      '每月15日付款',
      title: '付款',
      rec: monthly(day: 15),
      due: '2026-10-15',
      impliedDue: true,
    ),
    PC(
      '每月最后一天结算',
      title: '结算',
      rec: lastDay(),
      due: '2026-10-31',
      impliedDue: true,
    ),
    PC(
      '每月底结算',
      title: '结算',
      rec: lastDay(),
      due: '2026-10-31',
      impliedDue: true,
    ),
    PC(
      '每月第一个周一站会',
      title: '站会',
      rec: nthWeekday(1, 1),
      due: '2026-11-02',
      impliedDue: true,
    ),
    PC(
      '每月第二个星期三站会',
      title: '站会',
      rec: nthWeekday(2, 3),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      '每月最后一个周五站会',
      title: '站会',
      rec: nthWeekday(5, 5),
      due: '2026-10-30',
      impliedDue: true,
    ),
    PC(
      '每天吃药 直到2026-12-31',
      title: '吃药',
      rec: daily().copyWith(endDate: d('2026-12-31')),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      '每周一开会 截止2026-12-31',
      title: '开会',
      rec: weekly({1}).copyWith(endDate: d('2026-12-31')),
      due: '2026-10-19',
      impliedDue: true,
    ),
    PC(
      '每天吃药 直到12月31日',
      title: '吃药',
      rec: daily().copyWith(endDate: d('2026-12-31')),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      '每天吃药 完成后重复',
      title: '吃药',
      rec: daily().copyWith(completionBased: true),
      due: '2026-10-14',
      impliedDue: true,
    ),
    PC(
      '每周一下午3点开会',
      title: '开会',
      rec: weekly({1}),
      due: '2026-10-19',
      time: '15:00',
      impliedDue: true,
    ),
    PC('明天开始每天吃药', title: '开始吃药', rec: daily(), due: '2026-10-15'),
    PC('每年交税', title: '每年交税', hint: 'recurrence.yearly_unsupported'),
    PC('每3年体检', title: '每3年体检', hint: 'recurrence.yearly_unsupported'),
    PC('每天', title: '每天'),
  ]);

  group('zh extras', () {
    test('disabled token start keeps text', () {
      final r = mon().parse('提醒我明天开会', disabledTokenStarts: {3});
      expect(r.title, '提醒我明天开会');
      expect(r.dueDate, isNull);
    });
    test('disabled recurrence keeps the phrase and does not leak a date', () {
      final r = mon().parse('每周一开会', disabled: {TokenKind.recurrence});
      expect(r.title, '每周一开会');
      expect(r.dueDate, isNull);
    });
    test('English recurrence also works in Chinese mode', () {
      final r = mon().parse('gym every friday');
      expect(r.recurrence, weekly({5}));
    });
  });
}
