import 'package:collection/collection.dart';
import 'package:lxd/lxd.dart';
import 'package:stdlibc/stdlibc.dart';

import 'provider.dart';

class LxdUserFeature extends LxdFeatureProvider {
  const LxdUserFeature();

  @override
  List<String> getDirectories(LxdImage image) => const ['/etc/sudoers.d'];

  @override
  Map<String, String> getFiles(LxdImage image) {
    final username = image.properties['user.name']!;

    return {
      '/etc/sudoers.d/90-workshops': '''
  # Created by Workshops on ${DateTime.now().toIso8601String()}
  
  $username ALL=(ALL) NOPASSWD:ALL
  Defaults:$username env_keep += \"LXD_DIR\"
  '''
    };
  }

  @override
  Map<String, String> getConfig(LxdImage image) {
    final username = image.properties['user.name']!;
    final uid = image.properties['user.uid']!;
    final gid = image.properties['user.gid']!;

    return {
      'user.name': username,
      'raw.idmap': '''
uid ${getuid()} $uid
gid ${getgid()} $gid
''',
    };
  }

  @override
  Future<LxdOperation?> init(
      LxdClient client, LxdInstance instance, LxdImage image) async {
    final username = image.properties['user.name']!;
    final shell = image.properties['user.shell'];

    // sudo vs. wheel
    final group =
        await client.pullFile(instance.name, path: '/etc/group').then((data) {
      return data
          .split('\n')
          .firstWhereOrNull(
              (line) => line.startsWith('sudo:') || line.startsWith('wheel:'))
          ?.split(':')
          .firstOrNull;
    });

    // useradd
    return client.execInstance(
      instance.name,
      command: [
        'useradd',
        '--create-home',
        if (group != null) '--groups=$group',
        if (shell != null) '--shell=$shell',
        username,
      ],
    );
  }
}
