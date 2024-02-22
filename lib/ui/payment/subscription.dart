import 'package:flutter/cupertino.dart';
import 'package:photos/services/feature_flag_service.dart';
import 'package:photos/services/update_service.dart';
import 'package:photos/ui/payment/stripe_subscription_page.dart';
// import 'package:photos/ui/payment/subscription_page.dart'; #f-droid

StatefulWidget getSubscriptionPage({bool isOnBoarding = false}) {
  if (UpdateService.instance.isIndependentFlavor()) {
    return StripeSubscriptionPage(isOnboarding: isOnBoarding);
  }
  if (FeatureFlagService.instance.enableStripe()) {
    return StripeSubscriptionPage(isOnboarding: isOnBoarding);
  } else {
    return StripeSubscriptionPage(isOnboarding: isOnBoarding);
    // return SubscriptionPage(isOnboarding: isOnBoarding); #f-droid
  }
}
