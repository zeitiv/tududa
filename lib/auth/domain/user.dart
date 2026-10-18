import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// A JSON object.
typedef JsonMap = Map<String, Object?>;

/// The signed-in Tududi user (v1.9.4 has no numeric id; [uid] identifies it).
@Freezed(makeCollectionsUnmodifiable: false)
abstract class User with _$User {
  const User._();

  const factory User({
    @JsonKey(defaultValue: '') required String uid,
    required String email,
    String? name,
    String? surname,
    @JsonKey(defaultValue: 'en') @Default('en') String language,
    @JsonKey(defaultValue: 'light') @Default('light') String appearance,
    @JsonKey(defaultValue: 'UTC') @Default('UTC') String timezone,
    @JsonKey(name: 'first_day_of_week', defaultValue: 1)
    @Default(1)
    int firstDayOfWeek,
    @JsonKey(name: 'avatar_image') String? avatarImage,
    @JsonKey(name: 'telegram_chat_id') String? telegramChatId,
    @JsonKey(name: 'today_settings') JsonMap? todaySettings,
    @JsonKey(name: 'sidebar_settings') JsonMap? sidebarSettings,
    @JsonKey(name: 'ui_settings') JsonMap? uiSettings,
  }) = _User;

  factory User.fromJson(Map<String, Object?> json) => _$UserFromJson(json);

  String get displayName {
    final n = name;
    if (n != null && n.isNotEmpty) {
      final s = surname;
      return s != null && s.isNotEmpty ? '$n $s' : n;
    }
    return email;
  }

  String get initials {
    final n = name;
    if (n != null && n.isNotEmpty) {
      final s = surname;
      return s != null && s.isNotEmpty
          ? '${n[0].toUpperCase()}${s[0].toUpperCase()}'
          : n[0].toUpperCase();
    }
    return email.isEmpty ? '?' : email[0].toUpperCase();
  }
}
