import 'package:flutter/foundation.dart';

@immutable
class SubscriptionGroup {
  const SubscriptionGroup({
    required this.id,
    required this.name,
    required this.url,
    this.updatedAt,
  });

  factory SubscriptionGroup.fromJson(Map<String, Object?> json) {
    final updated = json['updatedAt'];
    return SubscriptionGroup(
      id: json['id']! as String,
      name: json['name']! as String,
      url: json['url']! as String,
      updatedAt: updated is int
          ? DateTime.fromMillisecondsSinceEpoch(updated)
          : null,
    );
  }

  final String id;
  final String name;
  final String url;

  final DateTime? updatedAt;

  SubscriptionGroup copyWith({
    String? name,
    String? url,
    DateTime? updatedAt,
  }) {
    return SubscriptionGroup(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
      };
}
