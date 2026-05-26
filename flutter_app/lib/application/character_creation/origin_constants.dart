/// SRD 5.2.1 character-origin constants.
///
/// The 2024 SRD §1.4 ("Choose Languages") gives every character Common plus
/// two languages picked from the Standard Languages table at origin. The
/// cap lives on the origin step, **not** the background — backgrounds may
/// still grant extras via their own fields, but the baseline 2-pick is a
/// fixed origin constant per SRD literal text.
class OriginConstants {
  OriginConstants._();

  /// Number of Standard-list languages every character picks at origin.
  static const int standardLanguageChoiceCount = 2;
}
