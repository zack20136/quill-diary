import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/config/app_identifiers.dart';

void main() {
  test('AppIdentifiers 穩定命名不漂移', () {
    expect(AppIdentifiers.displayName, 'Quill Diary');
    expect(AppIdentifiers.dartPackageName, 'quill_diary');
    expect(AppIdentifiers.androidPackageName, 'zack20136.com.quill_diary');
    expect(AppIdentifiers.appStorageDirectory, 'quill_diary');
    expect(AppIdentifiers.downloadsExportDirectory, 'quill-diary');
    expect(AppIdentifiers.secureStorageNamespace, 'quill_diary_device');
    expect(AppIdentifiers.oauthChannel, 'quill_diary/oauth_config');
    expect(AppIdentifiers.deviceKeyChannel, 'quill_diary/device_key_bridge');
    expect(AppIdentifiers.easyDiaryRealmChannel, 'quill_diary/easy_diary_realm');
    expect(AppIdentifiers.mediaStoreExportChannel, 'quill_diary/media_store_export');
    expect(AppIdentifiers.indexKeyDerivationInfo, 'quill_diary:index:v1');
    expect(AppIdentifiers.sourceRepositoryUrl, endsWith('/quill-diary'));
    expect(AppIdentifiers.issuesUrl, endsWith('/issues'));
    expect(AppIdentifiers.privacyPolicyUrl, endsWith('/privacy-policy'));
    expect(AppIdentifiers.thirdPartyNoticesUrl, endsWith('/third-party-notices'));
  });
}
