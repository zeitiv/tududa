/// Maps an incoming `tududa://` deep link to an in-app location, or null when
/// [uri] is not one of ours.
///
/// `tududa://today` -> `/today`, `tududa://task/abc?x=1` -> `/tasks/abc?x=1`,
/// `tududa://quick-add?text=hi` -> `/today?quickAdd=hi`.
String? deepLinkLocation(Uri uri) {
  if (uri.scheme != 'tududa') return null;
  final host = uri.host;
  final rest = uri.path.isEmpty || uri.path == '/' ? '' : uri.path;
  switch (host) {
    case '':
    case 'today':
      return '/today';
    case 'inbox':
    case 'upcoming':
    case 'projects':
    case 'notes':
    case 'overdue':
    case 'someday':
    case 'completed':
      return Uri(
        path: '/$host$rest',
        query: uri.query.isEmpty ? null : uri.query,
      ).toString();
    case 'task':
      return rest.isEmpty ? '/today' : '/tasks$rest';
    case 'project':
      return rest.isEmpty ? '/projects' : '/projects$rest';
    case 'note':
      return rest.isEmpty ? '/notes' : '/notes$rest';
    case 'quick-add':
      final text = uri.queryParameters['text'];
      return Uri(
        path: '/today',
        queryParameters: {'quickAdd': text ?? ''},
      ).toString();
    default:
      return '/today';
  }
}
