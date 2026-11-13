import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../auth/providers/auth_provider.dart';
import 'demo.dart';
import 'prefs.dart';

/// The services around Tududi: Karakeep (bookmarks), Memos (quick notes)
/// and Flatastic (the household). Each is a link that is off, connecting,
/// live or in error, with its data beside it.

enum Svc { karakeep, memos, flat }

enum Link { off, busy, live, error }

class LinkCfg {
  final String url;
  final String token;
  final String extra;
  const LinkCfg({required this.url, required this.token, this.extra = ''});

  Map<String, dynamic> toJson() => {'url': url, 'token': token, 'extra': extra};
  factory LinkCfg.fromJson(Map<String, dynamic> j) => LinkCfg(
        url: j['url'] as String? ?? '',
        token: j['token'] as String? ?? '',
        extra: j['extra'] as String? ?? '',
      );
}

String cleanUrl(String url) {
  var u = url.trim();
  while (u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }
  if (u.isNotEmpty && !u.startsWith('http://') && !u.startsWith('https://')) u = 'https://$u';
  return u;
}

/// Tokens go to the platform's keychain; where there is none to be had,
/// they fall back to the app's preferences.
class LinkStore {
  final Ref ref;
  LinkStore(this.ref);
  static const _secure = FlutterSecureStorage();

  String _key(Svc s) => 'link_${s.name}';

  Future<LinkCfg?> read(Svc s) async {
    String? raw;
    try {
      raw = await _secure.read(key: _key(s));
    } catch (_) {}
    raw ??= ref.read(sharedPreferencesProvider).getString(_key(s));
    if (raw == null) return null;
    try {
      return LinkCfg.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(Svc s, LinkCfg? cfg) async {
    final prefs = ref.read(sharedPreferencesProvider);
    try {
      if (cfg == null) {
        await _secure.delete(key: _key(s));
      } else {
        await _secure.write(key: _key(s), value: jsonEncode(cfg.toJson()));
      }
      await prefs.remove(_key(s));
    } catch (_) {
      if (cfg == null) {
        await prefs.remove(_key(s));
      } else {
        await prefs.setString(_key(s), jsonEncode(cfg.toJson()));
      }
    }
  }
}

final linkStoreProvider = Provider((ref) => LinkStore(ref));

bool _ok(Response r) => (r.statusCode ?? 500) < 400;

Dio _client(String base, Map<String, String> headers) => Dio(BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json', ...headers},
      validateStatus: (s) => s != null && s < 500,
    ));

String _why(Object e, [Response? r]) {
  if (r != null) {
    if (r.statusCode == 401 || r.statusCode == 403) return 'The key was not accepted';
    if (r.statusCode == 404) return 'Nothing answered at this address';
    return 'The server answered ${r.statusCode}';
  }
  return 'Could not reach the server';
}

abstract class LinkState {
  Link get status;
  String? get error;
  DateTime? get synced;
}

/// What the three links share: a stored configuration, a client built from
/// it, and connect / refresh / disconnect.
abstract class LinkNotifier<S extends LinkState> extends StateNotifier<S> {
  final Ref ref;
  final Svc svc;
  LinkCfg? cfg;
  Dio? dio;

  LinkNotifier(this.ref, this.svc, S initial) : super(initial);

  bool get demo => ref.read(authProvider).demo;
  Dio build(LinkCfg cfg);
  S withStatus(Link status, [String? error]);
  S seeded();
  Future<void> fetch();

  /// Called once at start: picks the stored link up again.
  Future<void> restore() async {
    if (demo) {
      state = seeded();
      return;
    }
    cfg = await ref.read(linkStoreProvider).read(svc);
    if (cfg == null) return;
    dio = build(cfg!);
    await refresh();
  }

  Future<void> refresh() async {
    if (demo || dio == null) return;
    if (state.status != Link.live) state = withStatus(Link.busy);
    try {
      await fetch();
    } on _Refused catch (e) {
      state = withStatus(Link.error, _why(e, e.response));
    } catch (e) {
      state = withStatus(Link.error, _why(e));
    }
  }

  Future<bool> connect(LinkCfg next) async {
    cfg = next;
    dio = build(next);
    await refresh();
    if (state.status == Link.live) {
      await ref.read(linkStoreProvider).write(svc, cfg);
      return true;
    }
    final failed = state;
    cfg = null;
    dio = null;
    state = failed;
    return false;
  }

  Future<void> disconnect() async {
    cfg = null;
    dio = null;
    await ref.read(linkStoreProvider).write(svc, null);
    state = withStatus(Link.off);
  }

  /// Runs a change the list already shows; on a refusal, fetches the truth.
  Future<bool> send(Future<Response> Function(Dio dio) call, {bool reload = false}) async {
    if (demo) return true;
    if (dio == null) return false;
    try {
      final r = await call(dio!);
      if (_ok(r)) {
        if (reload) await refresh();
        return true;
      }
    } catch (_) {}
    await refresh();
    return false;
  }
}

class _Refused implements Exception {
  final Response response;
  _Refused(this.response);
}

Response _must(Response r) => _ok(r) ? r : throw _Refused(r);

// -------------------------------------------------------------- Karakeep

class Bookmark {
  final String id;
  final String title;
  final String? url;
  final String? text;
  final String? image;
  final List<String> tags;
  final bool fav;
  final bool archived;
  final DateTime? created;

  const Bookmark({
    required this.id,
    required this.title,
    this.url,
    this.text,
    this.image,
    this.tags = const [],
    this.fav = false,
    this.archived = false,
    this.created,
  });

  String get host => url == null ? '' : (Uri.tryParse(url!)?.host ?? '').replaceFirst('www.', '');

  factory Bookmark.fromJson(Map<String, dynamic> j, {String base = ''}) {
    final c = j['content'] is Map ? Map<String, dynamic>.from(j['content']) : <String, dynamic>{};
    final url = c['url'] as String?;
    final text = (c['text'] ?? c['description'] ?? j['summary'] ?? j['note']) as String?;
    final asset = c['imageAssetId'] ?? c['screenshotAssetId'];
    var title = (j['title'] ?? c['title']) as String?;
    title = (title == null || title.trim().isEmpty)
        ? (url != null
            ? (Uri.tryParse(url)?.host ?? url)
            : (text ?? '').trim().split('\n').first)
        : title;
    return Bookmark(
      id: j['id'].toString(),
      title: title,
      url: url,
      text: text,
      image: (c['imageUrl'] as String?) ?? (asset != null ? '$base/api/assets/$asset' : null),
      tags: [
        if (j['tags'] is List)
          for (final t in j['tags']) if (t is Map && t['name'] != null) t['name'].toString(),
      ],
      fav: j['favourited'] == true,
      archived: j['archived'] == true,
      created: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
    );
  }

  Bookmark copyWith({bool? fav, bool? archived}) => Bookmark(
        id: id,
        title: title,
        url: url,
        text: text,
        image: image,
        tags: tags,
        fav: fav ?? this.fav,
        archived: archived ?? this.archived,
        created: created,
      );
}

class KarakeepState implements LinkState {
  @override
  final Link status;
  @override
  final String? error;
  @override
  final DateTime? synced;
  final List<Bookmark> items;
  final List<Bookmark>? found;
  const KarakeepState({
    this.status = Link.off,
    this.error,
    this.synced,
    this.items = const [],
    this.found,
  });

  KarakeepState copyWith({List<Bookmark>? items, List<Bookmark>? found, bool clearFound = false}) =>
      KarakeepState(
        status: status,
        error: error,
        synced: synced,
        items: items ?? this.items,
        found: clearFound ? null : (found ?? this.found),
      );
}

class KarakeepNotifier extends LinkNotifier<KarakeepState> {
  KarakeepNotifier(Ref ref) : super(ref, Svc.karakeep, const KarakeepState());

  @override
  Dio build(LinkCfg cfg) =>
      _client('${cfg.url}/api/v1', {'Authorization': 'Bearer ${cfg.token}'});

  @override
  KarakeepState withStatus(Link status, [String? error]) => KarakeepState(
        status: status,
        error: error,
        synced: state.synced,
        items: status == Link.off ? const [] : state.items,
      );

  @override
  KarakeepState seeded() =>
      KarakeepState(status: Link.live, synced: DateTime.now(), items: demoBookmarks());

  Map<String, String> get imageHeaders =>
      cfg == null ? const {} : {'Authorization': 'Bearer ${cfg!.token}'};

  List<Bookmark> _parse(dynamic data) => [
        if (data is Map && data['bookmarks'] is List)
          for (final b in data['bookmarks'])
            if (b is Map) Bookmark.fromJson(Map<String, dynamic>.from(b), base: cfg?.url ?? ''),
      ];

  @override
  Future<void> fetch() async {
    final r = _must(await dio!.get('/bookmarks', queryParameters: {'limit': 60}));
    state = KarakeepState(status: Link.live, synced: DateTime.now(), items: _parse(r.data));
  }

  Future<void> search(String q) async {
    if (q.trim().length < 2) {
      state = state.copyWith(clearFound: true);
      return;
    }
    final needle = q.toLowerCase();
    final local = [
      for (final b in state.items)
        if ('${b.title} ${b.url} ${b.text} ${b.tags.join(' ')}'.toLowerCase().contains(needle)) b,
    ];
    state = state.copyWith(found: local);
    if (demo || dio == null) return;
    try {
      final r = await dio!.get('/bookmarks/search', queryParameters: {'q': q, 'limit': 30});
      if (_ok(r)) state = state.copyWith(found: _parse(r.data));
    } catch (_) {}
  }

  Future<bool> add(String input) async {
    final text = input.trim();
    final isUrl = looksLikeUrl(text);
    final temp = Bookmark(
      id: 'tmp-${DateTime.now().microsecondsSinceEpoch}',
      title: isUrl ? (Uri.tryParse(cleanUrl(text))?.host ?? text) : text.split('\n').first,
      url: isUrl ? cleanUrl(text) : null,
      text: isUrl ? null : text,
      created: DateTime.now(),
    );
    state = state.copyWith(items: [temp, ...state.items]);
    return send(
      (d) => d.post('/bookmarks',
          data: isUrl ? {'type': 'link', 'url': cleanUrl(text)} : {'type': 'text', 'text': text}),
      reload: true,
    );
  }

  Future<bool> patch(Bookmark b, {bool? fav, bool? archived}) {
    final next = b.copyWith(fav: fav, archived: archived);
    state = state.copyWith(items: [for (final o in state.items) o.id == b.id ? next : o]);
    return send((d) => d.patch('/bookmarks/${b.id}', data: {
          'favourited': ?fav,
          'archived': ?archived,
        }));
  }

  Future<bool> remove(Bookmark b) {
    state = state.copyWith(items: [for (final o in state.items) if (o.id != b.id) o]);
    return send((d) => d.delete('/bookmarks/${b.id}'));
  }
}

bool looksLikeUrl(String s) {
  final t = s.trim();
  if (t.contains(' ') || t.contains('\n')) return false;
  if (t.startsWith('http://') || t.startsWith('https://')) return true;
  return RegExp(r'^[\w-]+(\.[\w-]+)+(/\S*)?$').hasMatch(t) && !t.contains('@');
}

// ----------------------------------------------------------------- Memos

class Memo {
  final String name;
  final String content;
  final bool pinned;
  final DateTime? time;
  final List<String> tags;
  const Memo({
    required this.name,
    required this.content,
    this.pinned = false,
    this.time,
    this.tags = const [],
  });

  factory Memo.fromJson(Map<String, dynamic> j) => Memo(
        name: (j['name'] ?? 'memos/${j['id'] ?? j['uid']}').toString(),
        content: j['content'] as String? ?? '',
        pinned: j['pinned'] == true,
        time: DateTime.tryParse((j['displayTime'] ?? j['createTime'] ?? '').toString()),
        tags: [if (j['tags'] is List) for (final t in j['tags']) t.toString()],
      );

  Memo copyWith({String? content, bool? pinned}) => Memo(
        name: name,
        content: content ?? this.content,
        pinned: pinned ?? this.pinned,
        time: time,
        tags: tags,
      );
}

class MemosState implements LinkState {
  @override
  final Link status;
  @override
  final String? error;
  @override
  final DateTime? synced;
  final List<Memo> items;
  const MemosState({this.status = Link.off, this.error, this.synced, this.items = const []});

  MemosState withItems(List<Memo> items) =>
      MemosState(status: status, error: error, synced: synced, items: items);

  /// Pinned first, then newest.
  List<Memo> get sorted {
    final list = [...items];
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return (b.time ?? DateTime(2000)).compareTo(a.time ?? DateTime(2000));
    });
    return list;
  }
}

class MemosNotifier extends LinkNotifier<MemosState> {
  MemosNotifier(Ref ref) : super(ref, Svc.memos, const MemosState());

  @override
  Dio build(LinkCfg cfg) => _client('${cfg.url}/api/v1', {'Authorization': 'Bearer ${cfg.token}'});

  @override
  MemosState withStatus(Link status, [String? error]) => MemosState(
        status: status,
        error: error,
        synced: state.synced,
        items: status == Link.off ? const [] : state.items,
      );

  @override
  MemosState seeded() => MemosState(status: Link.live, synced: DateTime.now(), items: demoMemos());

  @override
  Future<void> fetch() async {
    final r = _must(await dio!.get('/memos', queryParameters: {'pageSize': 60}));
    final data = r.data;
    state = MemosState(status: Link.live, synced: DateTime.now(), items: [
      if (data is Map && data['memos'] is List)
        for (final m in data['memos'])
          if (m is Map && (m['state'] ?? 'NORMAL') == 'NORMAL')
            Memo.fromJson(Map<String, dynamic>.from(m)),
    ]);
  }

  Future<bool> add(String content) {
    final temp = Memo(
      name: 'tmp/${DateTime.now().microsecondsSinceEpoch}',
      content: content,
      time: DateTime.now(),
    );
    state = state.withItems([temp, ...state.items]);
    return send((d) => d.post('/memos', data: {'content': content, 'visibility': 'PRIVATE'}),
        reload: true);
  }

  Future<bool> save(Memo m) {
    state = state.withItems([for (final o in state.items) o.name == m.name ? m : o]);
    return send((d) => d.patch('/${m.name}',
        queryParameters: {'updateMask': 'content,pinned'},
        data: {'name': m.name, 'content': m.content, 'pinned': m.pinned}));
  }

  Future<bool> remove(Memo m) {
    state = state.withItems([for (final o in state.items) if (o.name != m.name) o]);
    return send((d) => d.delete('/${m.name}'));
  }
}

// ------------------------------------------------------------- Flatastic

class Chore {
  final int id;
  final String title;
  final int? userId;

  /// Seconds until it is due; negative once it is late.
  final int? dueIn;
  final int points;
  const Chore({required this.id, required this.title, this.userId, this.dueIn, this.points = 0});

  bool get late => dueIn != null && dueIn! < 0;

  factory Chore.fromJson(Map<String, dynamic> j) => Chore(
        id: _int(j['id']) ?? 0,
        title: (j['title'] ?? j['name'] ?? '').toString(),
        userId: _int(j['currentUser']),
        dueIn: _int(j['timeLeftNext']),
        points: _int(j['points']) ?? 0,
      );
}

class ShopItem {
  final int id;
  final String name;
  final bool bought;
  const ShopItem({required this.id, required this.name, this.bought = false});

  factory ShopItem.fromJson(Map<String, dynamic> j) => ShopItem(
        id: _int(j['id']) ?? 0,
        name: (j['itemName'] ?? j['name'] ?? '').toString(),
        bought: j['bought'] == true || j['bought'] == 1 || j['bought'] == '1',
      );
}

class Mate {
  final int id;
  final String name;
  final int points;
  const Mate({required this.id, required this.name, this.points = 0});

  factory Mate.fromJson(Map<String, dynamic> j) => Mate(
        id: _int(j['id']) ?? 0,
        name: (j['firstName'] ?? j['name'] ?? '').toString(),
        points: _int(j['chorePoints']) ?? 0,
      );
}

int? _int(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');

class FlatState implements LinkState {
  @override
  final Link status;
  @override
  final String? error;
  @override
  final DateTime? synced;
  final String name;
  final List<Chore> chores;
  final List<ShopItem> shopping;
  final List<Mate> mates;
  final int? me;

  const FlatState({
    this.status = Link.off,
    this.error,
    this.synced,
    this.name = '',
    this.chores = const [],
    this.shopping = const [],
    this.mates = const [],
    this.me,
  });

  FlatState copyWith({List<Chore>? chores, List<ShopItem>? shopping}) => FlatState(
        status: status,
        error: error,
        synced: synced,
        name: name,
        chores: chores ?? this.chores,
        shopping: shopping ?? this.shopping,
        mates: mates,
        me: me,
      );

  String mate(int? id) {
    for (final m in mates) {
      if (m.id == id) return m.name;
    }
    return '';
  }

  /// Soonest due first.
  List<Chore> get sorted {
    final list = [...chores];
    list.sort((a, b) => (a.dueIn ?? 1 << 40).compareTo(b.dueIn ?? 1 << 40));
    return list;
  }

  List<Chore> get mine => [for (final c in sorted) if (c.userId == me) c];
  List<ShopItem> get toBuy => [for (final i in shopping) if (!i.bought) i];
}

/// Flatastic has no published API. This speaks to the one its own apps
/// use (api.flatastic-app.com): reading the flat, chores and shopping list
/// follows a known client; signing in and the writes are best effort.
class FlatNotifier extends LinkNotifier<FlatState> {
  FlatNotifier(Ref ref) : super(ref, Svc.flat, const FlatState());

  static const host = 'https://api.flatastic-app.com/index.php/api';

  @override
  Dio build(LinkCfg cfg) => _client(cfg.url.isEmpty ? host : cfg.url, {
        'x-api-key': cfg.token,
        'x-api-version': '2.0.0',
        'x-client-version': '2.3.20',
      });

  @override
  FlatState withStatus(Link status, [String? error]) => status == Link.off
      ? const FlatState()
      : FlatState(
          status: status,
          error: error,
          synced: state.synced,
          name: state.name,
          chores: state.chores,
          shopping: state.shopping,
          mates: state.mates,
          me: state.me,
        );

  @override
  FlatState seeded() => demoFlat();

  List<Map<String, dynamic>> _list(dynamic d) =>
      [if (d is List) for (final e in d) if (e is Map) Map<String, dynamic>.from(e)];

  @override
  Future<void> fetch() async {
    final res = await Future.wait([dio!.get('/wg'), dio!.get('/chores'), dio!.get('/shoppinglist')]);
    _must(res[0]);
    final wg = res[0].data is Map ? Map<String, dynamic>.from(res[0].data) : <String, dynamic>{};
    state = FlatState(
      status: Link.live,
      synced: DateTime.now(),
      name: (wg['name'] ?? '').toString(),
      mates: _list(wg['flatmates']).map(Mate.fromJson).toList(),
      chores: _ok(res[1]) ? _list(res[1].data).map(Chore.fromJson).toList() : const [],
      shopping: _ok(res[2]) ? _list(res[2].data).map(ShopItem.fromJson).toList() : const [],
      me: int.tryParse(cfg?.extra ?? ''),
    );
  }

  /// Signs in with the Flatastic account and keeps the key it hands back.
  Future<bool> login(String email, String password) async {
    state = withStatus(Link.busy);
    try {
      final r = await _client(host, const {'x-api-version': '2.0.0', 'x-client-version': '2.3.20'})
          .post('/auth/login', data: {'email': email.trim(), 'password': password});
      final data = r.data;
      final key = data is Map ? (data['X-API-KEY'] ?? data['x-api-key'])?.toString() : null;
      if (!_ok(r) || key == null) {
        state = withStatus(Link.error, 'Email or password was not accepted');
        return false;
      }
      final user = data is Map && data['user'] is Map ? data['user']['id']?.toString() : null;
      return await connect(LinkCfg(url: host, token: key, extra: user ?? ''));
    } catch (e) {
      state = withStatus(Link.error, _why(e));
      return false;
    }
  }

  Future<bool> doneChore(Chore c) {
    final others = [for (final m in state.mates) if (m.id != c.userId) m.id];
    state = state.copyWith(chores: [
      for (final o in state.chores)
        if (o.id == c.id)
          Chore(
            id: c.id,
            title: c.title,
            userId: others.isEmpty ? c.userId : others.first,
            dueIn: 7 * 86400,
            points: c.points,
          )
        else
          o,
    ]);
    return send(
      (d) => d.get('/chores/next', queryParameters: {'id': c.id, 'completedBy': state.me ?? c.userId}),
      reload: true,
    );
  }

  Future<bool> toggleItem(ShopItem i) {
    state = state.copyWith(shopping: [
      for (final o in state.shopping)
        o.id == i.id ? ShopItem(id: i.id, name: i.name, bought: !i.bought) : o,
    ]);
    return send((d) => d.get('/shoppinglist/toggle_item', queryParameters: {'id': i.id}));
  }

  Future<bool> addItem(String name) {
    state = state.copyWith(shopping: [
      ShopItem(id: -DateTime.now().millisecondsSinceEpoch, name: name),
      ...state.shopping,
    ]);
    return send((d) => d.post('/shoppinglist', data: {'name': name}), reload: true);
  }

  Future<bool> removeItem(ShopItem i) {
    state = state.copyWith(shopping: [for (final o in state.shopping) if (o.id != i.id) o]);
    return send((d) => d.delete('/shoppinglist/item/${i.id}'));
  }
}

final karakeepProvider =
    StateNotifierProvider<KarakeepNotifier, KarakeepState>((ref) => KarakeepNotifier(ref));
final memosProvider =
    StateNotifierProvider<MemosNotifier, MemosState>((ref) => MemosNotifier(ref));
final flatProvider = StateNotifierProvider<FlatNotifier, FlatState>((ref) => FlatNotifier(ref));
