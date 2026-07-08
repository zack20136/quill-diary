import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'front_matter_codec.dart';

final frontMatterCodecProvider = Provider<FrontMatterCodec>((Ref ref) {
  return const FrontMatterCodec();
});
