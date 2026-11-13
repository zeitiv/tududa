import '../areas/models/area_model.dart';
import '../inbox/models/inbox_item_model.dart';
import '../notes/models/note_model.dart';
import '../projects/models/project_model.dart';
import '../tasks/models/task_model.dart';
import 'links.dart';

/// Sample data for the demo: a believable week, held on the device only.

DateTime _in(int days) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + days, 12);
}

List<Task> demoTasks() => [
      Task(uid: 'd1', id: 1, name: 'Send the Q4 invoice to Lena', priority: 2, dueDate: _in(0), projectId: 2, projectName: 'Freelance'),
      Task(uid: 'd2', id: 2, name: 'Review the pull request for the stats page', status: 1, priority: 1, dueDate: _in(0), projectId: 1, projectName: 'Portfolio',
          note: 'Check the **contrast** of the new chart and the empty state.',
          subtasks: const [Task(uid: 'd2a', name: 'Read the diff', status: 2), Task(uid: 'd2b', name: 'Try it on a phone')]),
      Task(uid: 'd3', id: 3, name: 'Book the dentist', dueDate: _in(-1)),
      Task(uid: 'd4', id: 4, name: 'Water the plants', dueDate: _in(0), recurrenceType: 'weekly'),
      Task(uid: 'd5', id: 5, name: 'Plan the trip to Lisbon', priority: 1, dueDate: _in(2), projectId: 3, projectName: 'Travel'),
      Task(uid: 'd6', id: 6, name: 'Renew the domain', dueDate: _in(5), projectId: 1, projectName: 'Portfolio'),
      Task(uid: 'd7', id: 7, name: 'Write the talk outline', status: 6, dueDate: _in(9), projectId: 2, projectName: 'Freelance'),
      Task(uid: 'd8', id: 8, name: 'Read "A Philosophy of Software Design"'),
      Task(uid: 'd9', id: 9, name: 'Ask the landlord about the bike room', status: 4),
    ];

List<Task> demoDone() => [
      Task(uid: 'x1', id: 20, name: 'Back up the Mac mini', status: 2, completedAt: DateTime.now().subtract(const Duration(hours: 2))),
      Task(uid: 'x2', id: 21, name: 'Reply to Jonas', status: 2, completedAt: DateTime.now().subtract(const Duration(hours: 5))),
      Task(uid: 'x3', id: 22, name: 'Order printer paper', status: 2, completedAt: _in(-2)),
    ];

List<Area> demoAreas() => const [Area(id: 1, name: 'Work'), Area(id: 2, name: 'Life')];

List<Project> demoProjects() => const [
      Project(id: 1, uid: 'p1', name: 'Portfolio', description: 'The site, its background and its game.', status: 'in_progress', areaId: 1, areaName: 'Work', taskCount: 14, completedTaskCount: 9),
      Project(id: 2, uid: 'p2', name: 'Freelance', description: 'Client work and invoices.', status: 'in_progress', areaId: 1, areaName: 'Work', taskCount: 8, completedTaskCount: 3),
      Project(id: 3, uid: 'p3', name: 'Travel', description: 'Lisbon in spring.', status: 'planned', areaId: 2, areaName: 'Life', taskCount: 5, completedTaskCount: 1),
    ];

List<Note> demoNotes() => [
      Note(id: 1, uid: 'n1', title: 'Talk outline', content: '## Opening\n\nStart with the demo, not the slides.\n\n- One idea per slide\n- Show the failure first\n- End on the question', projectId: 2, projectName: 'Freelance', updatedAt: DateTime.now().subtract(const Duration(hours: 3))),
      Note(id: 2, uid: 'n2', title: 'Lisbon', content: 'Alfama in the morning, LX Factory after lunch.\n\n**Book:** the tram museum.', projectId: 3, projectName: 'Travel', updatedAt: _in(-1)),
      Note(id: 3, uid: 'n3', title: 'Homelab', content: 'Move Karakeep behind the tailnet. Check the Meilisearch volume.', updatedAt: _in(-4)),
    ];

List<InboxItem> demoInbox() => [
      InboxItem(uid: 'i1', id: 1, content: 'Idea: a weekly review that writes itself', createdAt: DateTime.now().subtract(const Duration(minutes: 40))),
      InboxItem(uid: 'i2', id: 2, content: 'Call the insurance about the new address', createdAt: DateTime.now().subtract(const Duration(hours: 6))),
      InboxItem(uid: 'i3', id: 3, content: 'Gift for Mara', createdAt: _in(-1)),
    ];

List<Bookmark> demoBookmarks() => [
      Bookmark(id: 'b1', title: 'Spring physics for interfaces', url: 'https://example.com/spring-physics', text: 'Why a spring feels right where a curve does not: it keeps its velocity.', tags: const ['motion', 'design'], fav: true, created: DateTime.now().subtract(const Duration(hours: 1))),
      Bookmark(id: 'b2', title: 'Designing for spatial computing', url: 'https://example.com/spatial', text: 'Windows, volumes and ornaments, and how depth replaces borders.', tags: const ['design'], created: DateTime.now().subtract(const Duration(hours: 9))),
      Bookmark(id: 'b3', title: 'Self-hosting on a Mac mini', url: 'https://example.com/mac-mini-homelab', text: 'Docker, a tailnet and a UPS.', tags: const ['homelab'], created: _in(-1)),
      Bookmark(id: 'b4', title: 'Dot-matrix type through the decades', url: 'https://example.com/dot-matrix', tags: const ['type'], created: _in(-2)),
      Bookmark(id: 'b5', title: 'Riverpod: optimistic updates', url: 'https://example.com/optimistic', tags: const ['flutter'], archived: true, created: _in(-6)),
    ];

List<Memo> demoMemos() => [
      Memo(name: 'memos/1', content: 'The best interface for a list is the one where finishing a thing feels like putting it down.', pinned: true, time: _in(-3), tags: const ['design']),
      Memo(name: 'memos/2', content: 'Bakery on Zentralstrasse closes at **18:30** on Saturdays.', time: DateTime.now().subtract(const Duration(hours: 2))),
      Memo(name: 'memos/3', content: 'Try: capture everything in one field, sort it later.\n\n- link → Karakeep\n- thought → Memos\n- to do → Tududi', time: DateTime.now().subtract(const Duration(hours: 20)), tags: const ['workflow']),
      Memo(name: 'memos/4', content: 'Wi-Fi printer needs the 2.4 GHz network.', time: _in(-2)),
    ];

FlatState demoFlat() => FlatState(
      status: Link.live,
      synced: DateTime.now(),
      name: 'Zentralstrasse 12',
      me: 1,
      mates: const [
        Mate(id: 1, name: 'Alex', points: 42),
        Mate(id: 2, name: 'Mara', points: 47),
        Mate(id: 3, name: 'Jonas', points: 31),
      ],
      chores: const [
        Chore(id: 1, title: 'Take out the recycling', userId: 1, dueIn: -7200, points: 2),
        Chore(id: 2, title: 'Clean the bathroom', userId: 2, dueIn: 86400, points: 5),
        Chore(id: 3, title: 'Vacuum the hallway', userId: 1, dueIn: 3 * 86400, points: 3),
        Chore(id: 4, title: 'Water the balcony', userId: 3, dueIn: 5 * 86400, points: 1),
      ],
      shopping: const [
        ShopItem(id: 1, name: 'Oat milk'),
        ShopItem(id: 2, name: 'Dish soap'),
        ShopItem(id: 3, name: 'Coffee beans'),
        ShopItem(id: 4, name: 'Bin bags', bought: true),
      ],
    );
