/// Hub ekranındaki paket listesi için hafif bilgi modeli.
class PackageInfo {
  final String name;
  final String templateName;
  final int entityCount;

  const PackageInfo({
    required this.name,
    required this.templateName,
    this.entityCount = 0,
  });
}
