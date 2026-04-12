/// Uygulama lokalizasyonundan bağımsız, kullanıcının game listing veya
/// marketplace item'ı oluştururken seçebileceği dünya dilleri. Kendisiyle
/// [LocalizedLanguage.native] ile görüntülenir (İngilizce "Turkish" yerine
/// "Türkçe"). Kodlar BCP-47 iki-harfli formdadır.
class WorldLanguage {
  final String code;
  final String native;
  final String english;
  const WorldLanguage(this.code, this.native, this.english);
}

const List<WorldLanguage> worldLanguages = [
  WorldLanguage('en', 'English', 'English'),
  WorldLanguage('tr', 'Türkçe', 'Turkish'),
  WorldLanguage('de', 'Deutsch', 'German'),
  WorldLanguage('fr', 'Français', 'French'),
  WorldLanguage('es', 'Español', 'Spanish'),
  WorldLanguage('it', 'Italiano', 'Italian'),
  WorldLanguage('pt', 'Português', 'Portuguese'),
  WorldLanguage('nl', 'Nederlands', 'Dutch'),
  WorldLanguage('pl', 'Polski', 'Polish'),
  WorldLanguage('ru', 'Русский', 'Russian'),
  WorldLanguage('uk', 'Українська', 'Ukrainian'),
  WorldLanguage('cs', 'Čeština', 'Czech'),
  WorldLanguage('sk', 'Slovenčina', 'Slovak'),
  WorldLanguage('hu', 'Magyar', 'Hungarian'),
  WorldLanguage('ro', 'Română', 'Romanian'),
  WorldLanguage('bg', 'Български', 'Bulgarian'),
  WorldLanguage('el', 'Ελληνικά', 'Greek'),
  WorldLanguage('sv', 'Svenska', 'Swedish'),
  WorldLanguage('no', 'Norsk', 'Norwegian'),
  WorldLanguage('da', 'Dansk', 'Danish'),
  WorldLanguage('fi', 'Suomi', 'Finnish'),
  WorldLanguage('is', 'Íslenska', 'Icelandic'),
  WorldLanguage('et', 'Eesti', 'Estonian'),
  WorldLanguage('lv', 'Latviešu', 'Latvian'),
  WorldLanguage('lt', 'Lietuvių', 'Lithuanian'),
  WorldLanguage('sr', 'Српски', 'Serbian'),
  WorldLanguage('hr', 'Hrvatski', 'Croatian'),
  WorldLanguage('sl', 'Slovenščina', 'Slovenian'),
  WorldLanguage('mk', 'Македонски', 'Macedonian'),
  WorldLanguage('sq', 'Shqip', 'Albanian'),
  WorldLanguage('ar', 'العربية', 'Arabic'),
  WorldLanguage('he', 'עברית', 'Hebrew'),
  WorldLanguage('fa', 'فارسی', 'Persian'),
  WorldLanguage('ur', 'اردو', 'Urdu'),
  WorldLanguage('hi', 'हिन्दी', 'Hindi'),
  WorldLanguage('bn', 'বাংলা', 'Bengali'),
  WorldLanguage('ta', 'தமிழ்', 'Tamil'),
  WorldLanguage('th', 'ไทย', 'Thai'),
  WorldLanguage('vi', 'Tiếng Việt', 'Vietnamese'),
  WorldLanguage('id', 'Bahasa Indonesia', 'Indonesian'),
  WorldLanguage('ms', 'Bahasa Melayu', 'Malay'),
  WorldLanguage('tl', 'Filipino', 'Filipino'),
  WorldLanguage('ja', '日本語', 'Japanese'),
  WorldLanguage('ko', '한국어', 'Korean'),
  WorldLanguage('zh', '中文', 'Chinese'),
  WorldLanguage('sw', 'Kiswahili', 'Swahili'),
  WorldLanguage('af', 'Afrikaans', 'Afrikaans'),
];

/// Verilen ISO kodunu native isme çevirir; eşleşme yoksa kodu aynen döner.
String worldLanguageNative(String code) {
  for (final l in worldLanguages) {
    if (l.code == code) return l.native;
  }
  return code;
}
