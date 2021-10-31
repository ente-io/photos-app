import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:photos/models/billing_plan.dart';
import 'package:photos/models/subscription.dart';
import 'package:photos/services/billing_service.dart';
import 'package:photos/ui/common/dialogs.dart';
import 'package:photos/ui/loading_widget.dart';
import 'package:photos/ui/payment/payment_web_page.dart';
import 'package:photos/ui/payment/skip_subscription_widget.dart';
import 'package:photos/ui/payment/subscription_common_widgets.dart';
import 'package:photos/ui/payment/subscription_plan_widget.dart';
import 'package:photos/ui/progress_dialog.dart';
import 'package:photos/ui/web_page.dart';
import 'package:photos/utils/dialog_util.dart';
import 'package:photos/utils/toast_util.dart';
import 'package:url_launcher/url_launcher.dart';

class StripeSubscriptionPage extends StatefulWidget {
  final bool isOnboarding;

  const StripeSubscriptionPage({
    this.isOnboarding = false,
    Key? key,
  }) : super(key: key);

  @override
  _StripeSubscriptionPageState createState() => _StripeSubscriptionPageState();
}

class _StripeSubscriptionPageState extends State<StripeSubscriptionPage> {
  final _logger = Logger("StripeSubscriptionPage");
  final _billingService = BillingService.instance;
  Subscription? _currentSubscription;
  late ProgressDialog _dialog;
  Future<int?>? _usageFuture;

  // indicates if user's subscription plan is still active
  late bool _hasActiveSubscription;
  FreePlan? _freePlan;
  List<BillingPlan> _plans = [];
  bool _hasLoadedData = false;
  bool _isStripeSubscriber = false;
  bool _showYearlyPlan = false;

  @override
  void initState() {
    _fetchSub();
    _dialog = createProgressDialog(context, "please wait...");
    super.initState();
  }

  Future<void> _fetchSub() async {
    return _billingService.fetchSubscription().then((subscription) async {
      _currentSubscription = subscription;
      _showYearlyPlan = _currentSubscription!.isYearlyPlan();
      _hasActiveSubscription = _currentSubscription!.isValid();
      _isStripeSubscriber = _currentSubscription!.paymentProvider == kStripe;
      _usageFuture = _billingService.fetchUsage();
      return _filterStripeForUI().then((value) {
        _hasLoadedData = true;
        setState(() {});
      });
    });
  }

  // _filterPlansForUI is used for initializing initState & plan toggle states
  Future<void> _filterStripeForUI() async {
    final billingPlans = await _billingService.getBillingPlans()!;
    _freePlan = billingPlans.freePlan;
    _plans = billingPlans.plans!.where((plan) {
      if (plan.stripeID == null || plan.stripeID!.isEmpty) {
        return false;
      }
      final isYearlyPlan = plan.period == 'year';
      return isYearlyPlan == _showYearlyPlan;
    }).toList();
    setState(() {});
  }

  FutureOr onWebPaymentGoBack(dynamic value) async {
    // refresh subscription
    await _dialog.show();
    try {
      await _fetchSub();
    } catch (e) {
      showToast("failed to refresh subscription");
    }
    await _dialog.hide();

    // verify user has subscribed before redirecting to main page
    if (widget.isOnboarding &&
        _currentSubscription != null &&
        _currentSubscription!.isValid() &&
        _currentSubscription!.productID != kFreeProductID) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: Text("subscription"),
    );
    return Scaffold(
      appBar: appBar,
      body: _getBody(),
    );
  }

  Widget _getBody() {
    if (_hasLoadedData) {
      return _buildPlans();
    }
    return loadWidget;
  }

  Widget _buildPlans() {
    final widgets = <Widget>[];

    widgets.add(SubscriptionHeaderWidget(
      isOnboarding: widget.isOnboarding,
      usageFuture: _usageFuture,
    ));

    widgets.addAll([
      Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _getStripePlanWidgets()),
      Padding(padding: EdgeInsets.all(4)),
    ]);

    widgets.add(_showSubscriptionToggle());

    if (_hasActiveSubscription) {
      widgets.add(ValidityWidget(currentSubscription: _currentSubscription));
    }

    if (_currentSubscription!.productID == kFreeProductID) {
      if (widget.isOnboarding) {
        widgets.add(SkipSubscriptionWidget(freePlan: _freePlan));
      }
      widgets.add(SubFaqWidget());
    }

    // only active subscription can be renewed/canceled
    if (_hasActiveSubscription && _isStripeSubscriber) {
      widgets.add(_stripeRenewOrCancelButton());
    }

    if (_currentSubscription!.productID != kFreeProductID) {
      widgets.addAll([
        Align(
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () async {
              switch (_currentSubscription!.paymentProvider) {
                case kStripe:
                  await _launchStripePortal();
                  break;
                case kPlayStore:
                  launch(
                      "https://play.google.com/store/account/subscriptions?sku=" +
                          _currentSubscription!.productID! +
                          "&package=io.ente.photos");
                  break;
                case kAppStore:
                  launch("https://apps.apple.com/account/billing");
                  break;
                default:
                  _logger.severe(
                      "unexpected payment provider ", _currentSubscription);
              }
            },
            child: Container(
              padding: EdgeInsets.fromLTRB(40, 80, 40, 80),
              child: Column(
                children: [
                  RichText(
                    text: TextSpan(
                      text: !_isStripeSubscriber
                          ? "visit ${_currentSubscription!.paymentProvider} to manage your subscription"
                          : "payment details",
                      style: TextStyle(
                        color: _isStripeSubscriber ? Colors.blue : Colors.white,
                        fontFamily: 'Ubuntu',
                        fontSize: 15,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ]);
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: widgets,
      ),
    );
  }

  Future<void> _launchStripePortal() async {
    await _dialog.show();
    try {
      String? url = await _billingService.getStripeCustomerPortalUrl();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (BuildContext context) {
            return WebPage("payment details", url);
          },
        ),
      ).then((value) => onWebPaymentGoBack);
    } catch (e) {
      await _dialog.hide();
      showGenericErrorDialog(context);
    }
    await _dialog.hide();
  }

  Widget _stripeRenewOrCancelButton() {
    bool isRenewCancelled =
        _currentSubscription!.attributes?.isCancelled ?? false;
    String title =
        isRenewCancelled ? "renew subscription" : "cancel subscription";
    return TextButton(
      child: Text(
        title,
        style: TextStyle(
          color: (isRenewCancelled ? Colors.greenAccent : Colors.white)
              .withOpacity(isRenewCancelled ? 1.0 : 0.4),
        ),
      ),
      onPressed: () async {
        bool confirmAction = false;
        if (isRenewCancelled) {
          var choice = await showChoiceDialog(
              context, title, "are you sure you want to renew?",
              firstAction: "no", secondAction: "yes");
          confirmAction = choice == DialogUserChoice.secondChoice;
        } else {
          var choice = await showChoiceDialog(
              context, title, 'are you sure you want to cancel?',
              firstAction: 'yes, cancel',
              secondAction: 'no',
              actionType: ActionType.critical);
          confirmAction = choice == DialogUserChoice.firstChoice;
        }
        if (confirmAction) {
          toggleStripeSubscription(isRenewCancelled);
        }
      },
    );
  }

  Future<void> toggleStripeSubscription(bool isRenewCancelled) async {
    await _dialog.show();
    try {
      isRenewCancelled
          ? await _billingService.activateStripeSubscription()
          : await _billingService.cancelStripeSubscription();
      await _fetchSub();
    } catch (e) {
      showToast(isRenewCancelled ? 'failed to renew' : 'failed to cancel');
    }
    await _dialog.hide();
  }

  List<Widget> _getStripePlanWidgets() {
    final List<Widget> planWidgets = [];
    bool foundActivePlan = false;
    for (final plan in _plans) {
      final productID = plan.stripeID;
      if (productID == null || productID.isEmpty) {
        continue;
      }
      final isActive =
          _hasActiveSubscription && _currentSubscription!.productID == productID;
      if (isActive) {
        foundActivePlan = true;
      }
      planWidgets.add(
        Material(
          child: InkWell(
            onTap: () async {
              if (isActive) {
                return;
              }
              // prompt user to cancel their active subscription form other
              // payment providers
              if (!_isStripeSubscriber &&
                  _hasActiveSubscription &&
                  _currentSubscription!.productID != kFreeProductID) {
                showErrorDialog(context, "sorry",
                    "please cancel your existing subscription from ${_currentSubscription!.paymentProvider} first");
                return;
              }
              await _dialog.show();
              if (_usageFuture != null) {
                final usage = await (_usageFuture as FutureOr<int>);
                await _dialog.hide();
                if (usage > plan.storage!) {
                  showErrorDialog(
                      context, "sorry", "you cannot downgrade to this plan");
                  return;
                }
              }
              String stripPurChaseAction = 'buy';
              if (_isStripeSubscriber && _hasActiveSubscription) {
                // confirm if user wants to change plan or not
                var result = await showChoiceDialog(
                    context,
                    "confirm plan change",
                    "are you sure you want to change your plan?",
                    firstAction: "no",
                    secondAction: 'yes');
                if (result != DialogUserChoice.secondChoice) {
                  return;
                }
                stripPurChaseAction = 'update';
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (BuildContext context) {
                    return PaymentWebPage(
                      planId: plan.stripeID,
                      actionType: stripPurChaseAction,
                    );
                  },
                ),
              ).then((value) => onWebPaymentGoBack(value));
            },
            child: SubscriptionPlanWidget(
              storage: plan.storage,
              price: plan.price,
              period: plan.period,
              isActive: isActive,
            ),
          ),
        ),
      );
    }
    if (!foundActivePlan && _hasActiveSubscription) {
      _addCurrentPlanWidget(planWidgets);
    }
    return planWidgets;
  }

  Widget _showSubscriptionToggle() {
    Widget _planText(String title, bool reduceOpacity) {
      return Padding(
        padding: const EdgeInsets.only(left: 4, right: 4),
        child: Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(reduceOpacity ? 0.5 : 1.0),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 4),
      margin: EdgeInsets.only(bottom: 12),
      // color: Color.fromRGBO(10, 40, 40, 0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _planText("monthly", _showYearlyPlan),
          Switch(
            value: _showYearlyPlan,
            activeColor: Colors.white,
            inactiveThumbColor: Colors.white,
            onChanged: (value) async {
              _showYearlyPlan = value;
              await _filterStripeForUI();
            },
          ),
          _planText("yearly", !_showYearlyPlan)
        ],
      ),
    );
  }

  void _addCurrentPlanWidget(List<Widget> planWidgets) {
    // don't add current plan if it's monthly plan but UI is showing yearly plans
    // and vice versa.
    if (_showYearlyPlan != _currentSubscription!.isYearlyPlan() &&
        _currentSubscription!.productID != kFreeProductID) {
      return;
    }
    int activePlanIndex = 0;
    for (; activePlanIndex < _plans.length; activePlanIndex++) {
      if (_plans[activePlanIndex].storage! > _currentSubscription!.storage!) {
        break;
      }
    }
    planWidgets.insert(
      activePlanIndex,
      Material(
        child: InkWell(
          onTap: () {},
          child: SubscriptionPlanWidget(
            storage: _currentSubscription!.storage,
            price: _currentSubscription!.price,
            period: _currentSubscription!.period,
            isActive: true,
          ),
        ),
      ),
    );
  }
}
