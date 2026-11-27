import '../../core/security/human_check.dart';

/// No Turnstile outside the web (yet): no check.
HumanCheck createHumanCheck(String siteKey) => const NoHumanCheck();
