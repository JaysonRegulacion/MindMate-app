import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppVersionService {
  static Future<Map<String, dynamic>?> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersionCode = int.parse(packageInfo.buildNumber);
    
    print('Installed versionName: ${packageInfo.version}');
    print('Installed versionCode: ${packageInfo.buildNumber}');

    final response = await Supabase.instance.client
        .from('app_versions')
        .select('version_code, latest_version, force_update, apk_url')
        .eq('platform', 'android')
        .single();

    final latestVersionCode = response['version_code'] as int;
    print ('Current version: $currentVersionCode, Latest version: $latestVersionCode');

    if (currentVersionCode < latestVersionCode) {
      return response;
    }

    return null; // No update needed
  }
}
