import "dart:async";

import 'package:flutter/material.dart';
import 'package:photos/core/event_bus.dart';
import 'package:photos/events/subscription_purchased_event.dart';
import "package:photos/generated/l10n.dart";
import 'package:photos/models/billing_plan.dart';
import 'package:photos/models/subscription.dart';
import 'package:photos/services/billing_service.dart';
import "package:photos/ui/tabs/home_widget.dart";

class SkipSubscriptionWidget extends StatelessWidget {
  const SkipSubscriptionWidget({
    Key? key,
    required this.freePlan,
  }) : super(key: key);

  final FreePlan freePlan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 64,
      margin: const EdgeInsets.fromLTRB(0, 30, 0, 0),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: OutlinedButton(
        style: Theme.of(context).outlinedButtonTheme.style?.copyWith(
          textStyle: MaterialStateProperty.resolveWith<TextStyle>(
            (Set<MaterialState> states) {
              return Theme.of(context).textTheme.titleMedium!;
            },
          ),
        ),
        onPressed: () async {
          Bus.instance.fire(SubscriptionPurchasedEvent());
          // ignore: unawaited_futures
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (BuildContext context) {
                return const HomeWidget();
              },
            ),
            (route) => false,
          );
          unawaited(
            BillingService.instance
                .verifySubscription(freeProductID, "", paymentProvider: "ente"),
          );
        },
        child: Text(S.of(context).continueOnFreeTrial),
      ),
    );
  }
}
