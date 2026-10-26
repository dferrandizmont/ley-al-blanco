/// The question-bank edition bundled with this build. Bumping it means a new
/// `assets/content/armas/<edition>/` folder (and the pubspec asset entry).
const String kContentEdition = 'GC-2020-11';

/// Asset folder of an edition, without a trailing slash.
String contentAssetDir(String edition) => 'assets/content/armas/$edition';

/// `assets/content/armas/<edition>/manifest.json`.
String contentManifestAsset(String edition) =>
    '${contentAssetDir(edition)}/manifest.json';

/// `assets/content/armas/<edition>/questions.json`.
String contentQuestionsAsset(String edition) =>
    '${contentAssetDir(edition)}/questions.json';

/// `assets/content/armas/<edition>/teoria.json` (may not exist yet).
String contentTheoryAsset(String edition) =>
    '${contentAssetDir(edition)}/teoria.json';

/// Keys of the `settings` table written by the importer.
abstract final class ContentSettingKeys {
  static const edition = 'content.edition';
  static const sha256 = 'content.sha256';
  static const retrieved = 'content.retrieved';
  static const importedAt = 'content.imported_at';
}
