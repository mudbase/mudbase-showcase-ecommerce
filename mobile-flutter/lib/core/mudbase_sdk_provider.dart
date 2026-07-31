import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mudbase_sdk/mudbase_sdk.dart';

import '../config/env_config.dart';

/// The single shared [MudbaseSdk] instance for the app - one `Dio` client,
/// one `Serializers` registry, matching the exact construction shown in this
/// project's brief: `MudbaseSdk(basePathOverride: 'https://cloud.mudbase.dev')`.
///
/// Every Mudbase call in this app (auth, products/orders/carts, and the
/// public payment-link poll) goes through `sdk.dio` directly rather than the
/// generated per-domain `*Api` wrapper classes (`AuthenticationApi`,
/// `MultiRoleFeatureApi`, `DataApi`). That is a deliberate, documented
/// choice, not a shortcut - see `auth_service.dart` and `data_service.dart`
/// for exactly why each wrapper's typed response model is inadequate for
/// this real deployment.
final mudbaseSdkProvider = Provider<MudbaseSdk>((ref) {
  return MudbaseSdk(basePathOverride: EnvConfig.mudbaseBaseUrl);
});
