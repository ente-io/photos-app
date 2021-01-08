import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:photos/models/billing_plan.dart';
import 'package:photos/services/billing_service.dart';
import 'package:photos/ui/loading_widget.dart';
import 'package:photos/utils/dialog_util.dart';

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({Key key}) : super(key: key);

  // TODO: Bus.instance.fire(UserAuthenticatedEvent());
  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: Text("choose plan"),
    );
    return Scaffold(
      appBar: appBar,
      body: _getBody(appBar.preferredSize.height),
    );
  }

  Widget _getBody(final appBarSize) {
    return FutureBuilder<List<BillingPlan>>(
      future: BillingService.instance.getBillingPlans(),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.hasData) {
          return _buildPlans(context, snapshot.data, appBarSize);
        } else if (snapshot.hasError) {
          return Text("Oops, something went wrong.");
        } else {
          return loadWidget;
        }
      },
    );
  }

  Widget _buildPlans(
      BuildContext context, List<BillingPlan> plans, final appBarSize) {
    final planWidgets = List<Widget>();
    for (final plan in plans) {
      planWidgets.add(
        Material(
          child: InkWell(
            onTap: () async {
              final dialog = createProgressDialog(context, "Please wait...");
              await dialog.show();
              // ignore: sdk_version_set_literal
              Set<String> _kIds = {
                Platform.isAndroid ? plan.androidID : plan.iosID
              };
              final ProductDetailsResponse response =
                  await InAppPurchaseConnection.instance
                      .queryProductDetails(_kIds);
              await dialog.hide();
              if (response.notFoundIDs.isNotEmpty) {
                showGenericErrorDialog(context);
                return;
              }
              List<ProductDetails> productDetails = response.productDetails;
              final PurchaseParam purchaseParam =
                  PurchaseParam(productDetails: productDetails[0]);
              await InAppPurchaseConnection.instance
                  .buyConsumable(purchaseParam: purchaseParam);
            },
            child: SubscriptionPlanWidget(plan: plan),
          ),
        ),
      );
    }
    final pageSize = MediaQuery.of(context).size.height;
    final notifySize = MediaQuery.of(context).padding.top;
    return SingleChildScrollView(
      child: Container(
        height: pageSize - (appBarSize + notifySize),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
              child: Text(
                "ente preserves your photos and videos, so they're always available, even if you lose your device",
                style: TextStyle(
                  color: Colors.white54,
                  height: 1.2,
                ),
              ),
            ),
            Padding(padding: EdgeInsets.all(12)),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: planWidgets,
            ),
            Padding(padding: EdgeInsets.all(8)),
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  "we offer a 14 day free trial, you can cancel anytime",
                  style: TextStyle(
                    color: Colors.white54,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            Expanded(child: Container()),
            Align(
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (builder) {
                      return LearnMoreWidget();
                    },
                  );
                },
                child: Container(
                  padding: EdgeInsets.all(40),
                  child: RichText(
                    text: TextSpan(
                      text: "learn more",
                      style: TextStyle(
                        color: Colors.blue,
                        fontFamily: 'Ubuntu',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LearnMoreWidget extends StatefulWidget {
  const LearnMoreWidget({
    Key key,
  }) : super(key: key);

  @override
  _LearnMoreWidgetState createState() => _LearnMoreWidgetState();
}

class _LearnMoreWidgetState extends State<LearnMoreWidget> {
  int _progress = 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 40, 0, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: Column(
          children: [
            Expanded(
              child: InAppWebView(
                initialUrl: 'https://ente.io/faq',
                onProgressChanged: (c, progress) {
                  setState(() {
                    _progress = progress;
                  });
                },
              ),
            ),
            Column(
              children: [
                _progress < 100
                    ? LinearProgressIndicator(
                        value: _progress / 100,
                        minHeight: 2,
                      )
                    : Container(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: FlatButton(
                    child: Text("close"),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    color: Colors.grey[850],
                    minWidth: double.infinity,
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SubscriptionPlanWidget extends StatelessWidget {
  const SubscriptionPlanWidget({
    Key key,
    @required this.plan,
  }) : super(key: key);

  final BillingPlan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  color: Color(0xDFFFFFFF),
                  child: Container(
                    width: 100,
                    padding: EdgeInsets.fromLTRB(0, 20, 0, 20),
                    child: Column(
                      children: [
                        Text(
                          (plan.storageInMBs / 1024).round().toString() + " GB",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).cardColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Text(plan.price + " per " + plan.period),
            ],
          ),
          Divider(
            height: 1,
          ),
        ],
      ),
    );
  }
}
