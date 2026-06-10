import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/config/app_identifiers.dart';

void main() {
  test('公開 URL 使用 quill-diary repo 名稱', () {
    expect(
      AppIdentifiers.privacyPolicyUrl,
      'https://zack20136.github.io/quill-diary/privacy-policy',
    );
    expect(
      AppIdentifiers.sourceRepositoryUrl,
      'https://github.com/zack20136/quill-diary',
    );
    expect(
      AppIdentifiers.thirdPartyNoticesUrl,
      'https://zack20136.github.io/quill-diary/third-party-notices',
    );
    expect(
      AppIdentifiers.issuesUrl,
      'https://github.com/zack20136/quill-diary/issues',
    );

    expect(AppIdentifiers.privacyPolicyUrl, isNot(contains('quill-lock-diary')));
    expect(AppIdentifiers.sourceRepositoryUrl, isNot(contains('quill-lock-diary')));
  });

  test('公開 URL 為合法 HTTPS', () {
    for (final String url in <String>[
      AppIdentifiers.privacyPolicyUrl,
      AppIdentifiers.sourceRepositoryUrl,
      AppIdentifiers.thirdPartyNoticesUrl,
      AppIdentifiers.issuesUrl,
    ]) {
      final Uri uri = Uri.parse(url);
      expect(uri.scheme, 'https');
      expect(uri.host, isNotEmpty);
    }
  });
}
