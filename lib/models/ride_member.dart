class RideMember {
  const RideMember({
    required this.userId,
    required this.name,
    required this.bike,
    required this.avatarUrl,
    required this.isHost,
  });

  final String userId;
  final String name;
  final String bike;
  final String avatarUrl;
  final bool isHost;
}
